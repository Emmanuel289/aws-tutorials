# AWS Virtual Servers (EC2 instances)
## 1 - Objective
- To launch a virtual server in AWS within a secure network.
- To also manage additional storage options for your server.

## 2 - Knowledge gained:
- Be able to launch a secure EC2 instance within a VPC.
- Be able to manage an EBS volume.

## 3 - Preliminaries:
- Install the AWS CLI and configure the settings including 
Access Key ID, Secret Access Key, Region, Output format, profiles, etc, using
the AWS configure command.
```bash
aws configure list
```
- Configure the AWS environment variables for your user session.
```bash
export AWS_ACCESS_KEY_ID=<value>
export AWS_SECRET_ACCESS_KEY=<value>
export AWS_DEFAULT_REGION=<value>
```

## 4 - Create a VPC
- Create a VPC with a single public subnet using the following field values
and leaving the rest as defaults.
VPC name: <vpc-name>
Availability zone: <availability-zone>
IPv4 CIDR block for VPC: <vpc-cidr-block> (e.g., 10.0.0.0/16 comprising 65,531 available IP addresses and 5 reserved for AWS)
IPv4 CIDR block for subnet: <subnet-cidr-block> (e.g., 10.0.0.0/24 comprising 251 available IP addresses and 5 reserved for AWS)
Subnet name: <subnet-name>

```bash
echo "Creating Maximus's VPC in US East 1"
aws ec2 create-vpc \
# E.g., us-east-1
--region <region> \ 
--cidr-block <cidr-block> \
--tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=maximus-vpc}]'

echo "Verifying creation of vpc"
aws ec2 describe-vpcs \
--vpc-id <vpc-id> # The ID that's assigned to the VPC

echo "Creating Maximus's Subnet in US East 1a"
aws ec2 create-subnet \
--vpc-id <vpc-id> \  
--availability-zone <availabily-zone> \
--cidr-block <cidr-block> \
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=maximus-subnet}]'

echo 'Verify creation of subnet'
aws ec2 describe-subnets \
--subnet-ids <subnet-id> # The ID that's assigned to the subnet
```

## 5 - Create an EC2 instance and attach an EBS volume
- Create an instance, e.g., using the following configuration
Amazon Machine Image (AMI): Amazon Linux 2 AMI (HVM), SSD volume type
Instance Type: t2.micro
Instance details: num of instances (1), network (maximus-vpc) subnet (maximus-subnet)
Storage: root-volume (default), additional-volume (EBS, 8GB, general purpose SSD gp2, deletes on termination)
Tags: optional
Security group: Default rule, allow all traffic from all hosts (0.0.0.0/0) to access the instance

```bash
aws ec2 run-instances \
# The ID of the image to use for the instance. Can be an AWS public image or one that's created by user.
--image-id <ami-id> \ 
--instance-type t2.micro \
# The name of an SSH public/private key pair
--key-name <key-name> \ 
--subnet-id <subnet-id> \
# The default allow-all security group
--security-group-ids '<security-group-id>' \ 
# Attaches an EBS volume to the instance
--block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp2","DeleteOnTermination":true}}]' \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=maximus-server}]'

# Verify creation of the instance
aws ec2 describe-instances \
# The id that's assigned to the instance
--instance-id <instance-id>
```

## 6 -  Connect to the instance via SSH by specifying its private ip address and the path to the private key on the client's machine.
```bash
ssh -i /path/to/key-file.pem ec2-user@<instance-ip-address>
```
- Generate and download a new key pair. This key pair will allow you to access your instance
using SSH from your local machine. Save the key-pair carefully because the same private key cannot be regenerated.

## 7 - Troubleshooting errors with SSH access
- Ensure a security with an ingress rule that allows SSH traffic has been created:

```bash
aws ec2 authorize-security-group-ingress \
--group-id <security-group-id> \
--protocol tcp --port 22 \
--cidr <cidr-block> # A range of ip addresses in /32 notation, e.g., the client's IP address
```

- Verify that an internet gateway has been created and attached to the VPC:

```bash
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output yaml)

aws ec2 attach-internet-gateway \
--internet-gateway-id "${IGW_ID}" \
--vpc-id <vpc-id>
```

- Add an internet route to the gateway and configure its destination cidr block. e.g., all ip addresses.
```bash
aws ec2 create-route \
--route-table-id <route-table-id> \
# Route traffic from the network to all ip addresses
--destination-cidr-block 0.0.0.0/0 \
--gateway-id $IGW_ID
```

- Allocate and associate Elastic IP.
```bash
ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
INSTANCE_ID="<instance-id>"
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOC_ID
```

- Connect to the instance using the elastic public IP
```bash
# Make sure the SSH key is not publicly viewable!
chmod +x 400 /path/to/key-file.pem
ssh -i /path/to/key-file.pem ec2-user@<instance-ip-address>
```

## Cleanup all resources
- Terminate the created instance
```bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```
- Delete the EBS volume (Do this if you did not specify `DeleteOnTermination=true` when creating the instance)
```bash
aws ec2 describe-volumes
aws ec2 delete-volume --volume-id $VOLUME_ID
```
- Delete the remaining resources in the VPC following the order below:
```bash
# Delete subnets in the VPC
aws ec2 delete-subnet --subnet-id <subnet-id>

# Detach the internet gateway from the VPC
aws ec2 detach-internet-gateway --internet-gateway-id <igw-id> --vpc-id <vpc-id>

# Delete the detached internet gateway
aws ec2 delete-internet-gateway --internet-gateway-id <igw-id>

# Delete the VPC
aws ec2 delete-vpc --vpc-id <vpc-id>

```

# Terraform config
The terraform configuration for this lab can be found in the [infra](./infra/) directory