# change this to your region
$region = "eu-west-1"

function get_instance_id {
    $instanceid = invoke-restmethod -uri http://169.254.169.254/latest/meta-data/instance-id 
        return "$instanceid"
}

function get_all_elb($instanceid) {
    (get-ELBLoadBalancer |  Select-Object LoadbalancerName,Instances -ExpandProperty Instances | where {$_.InstanceId -like "*${instanceid}*"}).LoadBalancerName
}

function wait_for_state($instanceid, $loadbalancers, $desired_state) {
    foreach ($myelb in $loadbalancers) {
        $attempt = 0
            $max_attempts = 300
            Write-Host "Checking state of $myelb"
            While ((Get-ELBInstanceHealth -LoadBalancerName $myelb -Instance $instanceid).State -inotmatch $desired_state) {
                if ($attempt -ge $max_attempts) { 
                    Write-Host "State check of $instanceid from $myelb did not complete inside of threshold"
                        exit -1
                } else {
                    $attempt++ 
                        Write-Host "$instanceid is still not in desired state on $myelb, attempt: $attempt out of $max_attempts"
                        Sleep 1
                }
            }        
    }
}

function deregister_instance($instanceid, $loadbalancers) {
    foreach ($elb in $loadbalancers) {
        Remove-ELBInstanceFromLoadBalancer -Confirm:$false -LoadBalancerName "$elb" -Instance $current_instance
    }
}

function register_instance($instanceid, $loadbalancers) {
    foreach ($elb in $loadbalancers) {
        Register-ELBInstanceWithLoadBalancer -Confirm:$false -LoadBalancerName "$elb" -Instance $current_instance
    }
}


