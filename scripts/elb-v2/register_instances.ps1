# Are you running in 32-bit mode?
#   (\SysWOW64\ = 32-bit mode)

if ($PSHOME -like "*SysWOW64*")
{
    Write-Warning "Restarting this script under 64-bit Windows PowerShell."

# Restart this script under 64-bit Windows PowerShell.
#   (\SysNative\ redirects to \System32\ for 64-bit mode)

        & (Join-Path ($PSHOME -replace "SysWOW64", "SysNative") powershell.exe) -File `
        (Join-Path $PSScriptRoot $MyInvocation.MyCommand) @args

# Exit 32-bit script.

        Exit $LastExitCode
}

# Was restart successful?
Write-Warning "Hello from $PSHOME"
Write-Warning "  (\SysWOW64\ = 32-bit mode, \System32\ = 64-bit mode)"
Write-Warning "Original arguments (if any): $args"

# Your 64-bit script code follows here...
# ...
#

# Get script path and include common functions
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path
. $scriptRoot\common_func.ps1

$region = get_instance_region 
Write-Debug "Running against region: $region"

Write-Debug "Find the current instance id by looking at AWS metadata"
$instanceid = get_instance_id

Write-Debug "Checking that the user set at least one valid target group"
if(!$target_Group_list) {
    Write-Error "Must have at least one target group to register with"
    exit -1
}

Write-Debug "Checking whether the port number has been set"
if ($port) {
    Write-Debug "Found port ${Port}, it will be used for instance health check against target groups"
} else {
    Write-Debug "Port variable is not set, will use the default port number set in target groups"
}

# Loop through all target groups the user set, and attempt to register this instance with them.
foreach ($target_group in $target_group_list) {
    Write-Debug "Registering $instanceid with $target_group starts"
    register_instance $instanceid $target_group
}


# Wait for all Registrations to finish
Write-Debug "Waiting for instance to de-register from it's target groups"
foreach ($target_group in $target_group_list) {
    wait_for_state $instanceid $target_group $register_state
}


exit $LastExitCode
