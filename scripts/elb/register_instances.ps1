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


# Find the current instance id by looking at AWS metadata
$current_instance = get_instance_id 

# Find all load balancers that the instance used to be registered to
$loadbalancers = Get-Content c:\temp\loadbalancers.lst

if (!$loadbalancers) {
    Write-Host "There are no saved loadbalancers to register with"
        exit -1
}

# Register the instance with all saved loadbalancers
register_instance $current_instance $loadbalancers

# Wait for instance to finish registering
wait_for_state $current_instance $loadbalancers "InService"
exit $LastExitCode
