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

## 5 - Create a VPC
- Create a VPC with a single public subnet using the following field values
and leaving the rest as defaults.
VPC name: maximus-vpc
Availability zone: us-east-1a
IPv4 CIDR block for VPC: 10.0.0.0/16 (65,531 available IP addresses and 5 reserved for AWS)
IPv4 CIDR block for subnet: 10.0.0.0/24 (251 available IP addresses and 5 reserved to AWS)
Subnet name: maximus-subnet

```bash
echo "Creating Maximus's VPC in US East 1"
aws ec2 create-vpc \
--region us-east-1 \
--cidr-block 10.0.0.0/16 \
--tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=maximus-vpc}]'

echo "Verifying creation of vpc"
aws ec2 describe-vpcs \
--vpc-id 'vpc-0e6c27e517e8196fc' # The ID assigned to maximus-vpc

echo "Creating Maximus's Subnet in US East 1a"
aws ec2 create-subnet \
--vpc-id 'vpc-0e6c27e517e8196fc' \  
--availability-zone us-east-1a \
--cidr-block 10.0.0.0/24 \
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=maximus-subnet}]'

echo 'Verify creation of subnet'
aws ec2 describe-subnets \
--subnet-ids 'subnet-02209d5cd89cc422e' # The ID assigned to maximus-subnet
```

## 6 - Create an EC2 instance and attach an EBS volume
- Create an instance with the following configuration
Amazon Machine Image (AMI): Amazon Linux 2 AMI (HVM), SSD volume type
Instance Type: t2.micro
Instance details: num of instances (1), network (maximus-vpc) subnet (maximus-subnet)
Storage: root-volume (default), additional-volume (EBS, 8GB, general purpose SSD gp2, deletes on termination)
Tags: optional
Security group: Default rule, allow all traffic from all hosts (0.0.0.0/0) to access the instance

```bash
aws ec2 run-instances \
--image-id 'ami-0c1fe732b5494dc14' \
--instance-type t2.micro \
--key-name maximus-ec2-keys \
--subnet-id 'subnet-02209d5cd89cc422e' \
# The default allow-all security group
--security-group-ids 'sg-000c2851918f99a00' \ 
# Attaches an EBS volume to the instance
--block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8,"VolumeType":"gp2","DeleteOnTermination":true}}]' \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=maximus-server}]'

# Verify creation of the instance
aws ec2 describe-instances \
--instance-id i-0ac5568260fce883d

# Connect to the instance via SSH by specifying its private ip address and the path to the private key on your machine
ssh -i '~/.ssh/maximus-ec2-keys.pem' ec2-user@10.0.0.228
```
- Generate and download a new key pair. This key pair will allow you to access your instance
using SSH from your local machine. Save the key-pair carefully because the same private key cannot be regenerated

## Troubleshooting errors with SSH access
- Add SSH rule
```bash
aws ec2 authorize-security-group-ingress \
--group-id sg-000c2851918f99a00 \
--protocol tcp --port 22 \
--cidr 99.239.203.165/32 # My IP address
```

- Create and attach Internet Gateway
```bash
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output yaml)

aws ec2 attach-internet-gateway \
--internet-gateway-id "${IGW_ID}" \
--vpc-id vpc-0e6c27e517e8196fc
```

- Add internet route
```bash
aws ec2 create-route \
--route-table-id rtb-0fc84955db767db7a \
--destination-cidr-block 0.0.0.0/0 \
--gateway-id $IGW_ID
```

- Allocate and associate Elastic IP
```bash
ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
INSTANCE_ID="i-0ac5568260fce883d"
aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOC_ID
```

- Connect to the instance using the elastic public IP
```bash
# Make sure the SSH key is not publicly viewable!
chmod +x 400 ~/.ssh/maximus-ec2-keys.pem
ssh -i "~/.ssh/maximus-ec2-keys.pem" ec2-user@98.89.109.252
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
aws ec2 delete-subnet --subnet-id subnet-02209d5cd89cc422e

# Detach the internet gateway from the VPC
aws ec2 detach-internet-gateway --internet-gateway-id igw-01d7fa87b222cfdc6 --vpc-id vpc-0e6c27e517e8196fc

# Delete the detached internet gateway
aws ec2 delete-internet-gateway --internet-gateway-id igw-01d7fa87b222cfdc6

# Delete the VPC
aws ec2 delete-vpc --vpc-id vpc-0e6c27e517e8196fc

```

# Terraform config
The terraform configuration for this lab can be found in the [infra](./infra/) directory