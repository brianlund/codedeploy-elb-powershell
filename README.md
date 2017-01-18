# codedeploy-elb-powershell

For an explanation of what this is, see: http://cze.dk/codedeploy-and-aws-elastic-loadbalancer-windows-edition/

Powershell implementation of the CodeDeploy loadbalancer examples found at https://github.com/awslabs/aws-codedeploy-samples

This implementation currently is missing some functionality compared to the bash variant, most notably:

* ~~no application loadbalancer support~~
* no autoscaling support
* ELB: no support for predefined loadbalancers to deregister/reregister from and to. Instead we detect what loadbalancers the instance is currently registered with and uses those.
* ELB: the temporary file that holds the loadbalancers is currently hardcoded to c:\temp\loadbalancers.lst (the directory is used in the walkthrough for setting up CodeDeploy so it might exist already, else create it, or better yet change the script to create the file in a secure way).

## Requirements

Just as the original bash scripts, the powershell register and deregister scripts have a couple of dependencies in order to properly interact with Elastic Load Balancing.

1. The [AWS Tools for powershell](https://aws.amazon.com/powershell/).  

2. An instance profile with a policy that allows, at minimum, the following actions:

For ELB:
- elasticloadbalancing:Describe
- elasticloadbalancing:DeregisterInstancesFromLoadBalancer
- elasticloadbalancing:RegisterInstancesWithLoadBalancer
For ELB-v2
- elasticloadbalancing:Describe
- elasticloadbalancing:DeregisterTargets
- elasticloadbalancing:RegisterTargets

## Usage

Add the deregister_instances.ps1 script to your ApplicationStop (note this isn't run first time) or BeforeInstall hook and register_instances.ps1 to your ApplicationStart hook. See the included appspec.yml for an example.
