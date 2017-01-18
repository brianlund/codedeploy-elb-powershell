# $target_list defines which target groups behind Load Balancer this instance should be part of. You need to specify minimum one target group
# Example:
# $target_group_list = "website1", "website2", "website3"
$target_group_list = ""

# $port defines which port the application is running at.
# If $port is not specified, the script will use the default port set in target groups
# Example: $port = 80
#$port = 80

# Under normal circumstances, you shouldn't need to change anything below this line.
# -----------------------------------------------------------------------------

# Interval between state checks
$waiter_interval_alb = 5

$deregister_state = "removed"
$register_state = "healthy"

# if set, will output debug information.
$Debug=1

if ($Debug) { $DebugPreference = 'Continue' }


# Usage: get_target_group_info <instanceid> <target_group>
#
#    Creates a Amazon.ElasticLoadBalancingV2.Model.TargetDescription object containing instance and port. Used to de/register a target from a target group

function get_target_group_info ($instanceid, $target_group) {

    $target_group_info = Get-ELB2TargetGroup -Name $target_group | Select-Object TargetGroupArn,Port
    $target_group_arn = $target_group_info.TargetGroupArn
    if(!$target_group_arn) {
        Write-Error "Could not find the target group $target_group"
        exit -1
    }
    if(!$port) {
        $target_group_port=$target_group_info.Port
    } else {
        $target_group_port=$port
        }

    $hash = @{
        Id = $instanceid
        Port = $target_group_port
    }
    $targetobject = New-Object Amazon.ElasticLoadBalancingV2.Model.TargetDescription -Property $hash
    return $targetobject
}

# Usage: reset_waiter_timeout <target group name> <state name>
#
#    reset timeout based on different instance states
#    When waiting for instance to be registered, use health check threshold * (health_check_timeout + healthy_check_interval) to compute timeout for health check
#    When waiting for instance to be deregistered, use deregistration timeout as timeout for health check

function reset_waiter_timeout ($target_group, $state) {
    
    if ($state -eq $register_state) {
        $health_check_interval = (Get-ELB2TargetGroup -Name $target_group).HealthCheckIntervalSeconds
        $health_check_timeout  = (Get-ELB2TargetGroup -Name $target_group).HealthCheckTimeoutSeconds
        $health_check_threshold = (Get-ELB2TargetGroup -Name $target_group).HealthyThresholdCount
        $timeout=$health_check_threshold * ( $health_check_timeout + $health_check_interval )
        } else {
    if ($state -eq $deregister_state) {
        Write-Debug "Getting timeout for $deregister_state"
        $target_group_arn = (Get-ELB2TargetGroup -Name $target_group).TargetGroupArn
        $timeout = (Get-ELB2TargetGroupAttribute $target_group_arn | Where-Object {$_.key -eq "deregistration_delay.timeout_seconds"}).Value
        }
    }
    $waiter_attempts = [math]::ceiling(($timeout / $waiter_interval_alb))
    return $waiter_attempts    
}

# Usage: reset_waiter_timeout
#
#       Writes the AWS region as known by the local instances

function get_instance_region {

    if(!$aws_region) {
        $aws_region = (Invoke-RestMethod -Uri http://169.254.169.254/latest/dynamic/instance-identity/document).region
        }
    return "$aws_region"
}

# Usage: get_instance_id
#
#       Writes the local instance id

function get_instance_id {

    $instanceid = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
    return "$instanceid"
}


# Usage: get_instance_health_target_group <instanceid> <target group arn>
#
#       Gets the health of an instances as seen from a target group.
#       Get-ELB2TargetHealth will return null if the target is not registered with the target group (has been removed), so then set the health state to "removed" manually.

function get_instance_health_target_group ($instanceid,$target_group_arn) {

    $health = ((Get-ELB2TargetHealth -TargetGroupArn $target_group_arn) | Where-Object {$_.Target.Id -eq $instanceid}).TargetHealth.State
        if (!$health.Value) {
            return "removed"
        } else {
            return $health.Value
        }
}


# Usage: deregister_instance <instanceid> <target group>
#
#       Deregisters the instance from the given target group

function deregister_instance ($instanceid,$target_group) {

    $targetobject = get_target_group_info $instanceid $target_group    
    Write-Debug "Deregistering $instanceid from $target_group"
    $target_group_arn = Get-ELB2TargetGroup -Name $target_group | Select-Object TargetGroupArn -ExpandProperty TargetGroupArn
    Unregister-ELB2Target -Confirm:$false -TargetGroupArn "$target_group_arn" -Target $targetobject
}

# Usage: register_instance <instanceid> <target group>
#
#       Registers the instance with the selected target group

function register_instance ($instanceid,$target_group) {

    $targetobject = get_target_group_info $instanceid $target_group
    Write-Debug "Registering $instanceid with $target_group"
    $target_group_arn = Get-ELB2TargetGroup -Name $target_group | Select-Object TargetGroupArn -ExpandProperty TargetGroupArn
    Register-ELB2Target -Confirm:$false -TargetGroupArn "$target_group_arn" -Target $targetobject
}

# Usage: wait_for_state <instanceid> <target group> <state>
#
#       Waits for the desired state to be archived for the given instance and target group
#   If a target group is not in use by a load balancer, the state returned from get_instance_health_target_group is "unused" and we also accept that as having reached a desired state.

function wait_for_state ($instanceid, $target_group, $state) {

    $waiter_attempts = reset_waiter_timeout $target_group $state
    Write-Debug "Checking $waiter_attempts times, every $waiter_interval_alb seconds, for $instanceid to be in state $state"
    $target_group_arn = Get-ELB2TargetGroup -Name $target_group | Select-Object TargetGroupArn -ExpandProperty TargetGroupArn
    $counter = 0
    $instance_state = get_instance_health_target_group $instanceid $target_group_arn

    Write-Debug "Instance is currently in state: $instance_state - attempt $counter"
    # If a target group isn't used by a loadbalancer, it returns unused as state, so handle that.
    while (($instance_state -ne $state) -And ($instance_state -ne "unused")) {
        if ($counter -ge $waiter_attempts) {
            Write-Debug "State of $state not acquired inside threshold"
            exit -1
        } else {
            $counter = $counter + 1
            sleep $waiter_interval_alb
            $instance_state = get_instance_health_target_group $instanceid $target_group_arn
            Write-Debug "Instance is currently in state: $instance_state - attempt $counter"
        }
    }
    Write-Debug "State of $state / unused acquired"
}

