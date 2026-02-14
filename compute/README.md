# Compute Services
## EC2
EC2 provides servers in the cloud. They can be on-demand, dedicated, spot(bidding), or reserved. An EC2 instance is a VM with 
user-defined configuration that runs in the cloud.
How to connect to an instance using an SSH client and a private .pem key
```bash
ssh -i '/path/to/key_file' public_dns_adress_of_instance
```
Network interfaces: A network interface represents a virtual network card in a VPC, and it has both public
and private IP addresses. An EC2 instance can have multiple network interfaces.

## Load balancers
A load balancer distributes traffic across multiple targets, such as EC2 instances in one or more AZs.
AWS supports three types of load balancers, namely: Classic Load balancer (deprecated and not recommended), Network Load balancer, and Application
Loadbalancer
Launch templates: These are scripts that contain config information written either in JSON or YAML formats, to automate
instance launches, simplify permission policies, and enforce best practices across an org.

## Elastic Block Store (EBS)
EBS is a storage solution for EC2 instances and is a physical hard disk that is attached to the EC2 instance to increase its storage.

## Virtual Private Cloud (VPC)
A VPC allows you to create your own private network in the cloud. You can launch EC2 instances inside that private network.
A VPC is a regional resource which spans all the availability zones in the region.
VPCs allow you to control your virtual networking environment, including IP address ranges, subnets, route tables, 
and network gateways.
The default configuration of a VPC is 5 VPCs per region, however you can request for an increase.
If resources within your VPC want to communicate to the internet, then you must attach an internet gateway (IGW) to your VPC.
The IGW enables the communication between resources in your VPC and the internet.

### VPC Configurations in AWS:
a - A VPC with a public subnet: Your instances run in a private isolated section of AWS cloud with direct access to the Internet.
Network ACLs and security groups can be used to provide strict control over inbound and outbound network traffic to your instances.
b - A VPC with public and private subnets: In addition to containing a public subnet, this configuration adds a private subnet
whose instances are not addressable from the internet. Instances in the private subnet can establish outbound connections to the
Internet via the public subnet using Network Address Translation (NAT).
c - A VPC with public and private subnets and hardware VPN Access: This config adds an IPSec VPN connection between your
VPC and your data center, effectively extending your data center to the cloud while also providing direct access to the Internet
for public subnet instances in your VPC.
d- A VPC with a private subnet only and hardware VPN access: Your instances run in a private, isolated section of
AWS cloud with a private subnet whose instances are not addressable from the internet. You can connect this private subnet
to your corporate data center via an IPSec VPN.

### Network Access Control List (ACL): 
A network ACL defines a set of firewall rules for controlling traffic coming in and out of subnets in your VPC. The default network ACL allows all inbound and outbound IPv4 traffic (which can and should be edited).

