
# Data source to reference a public Amazon Linux 2023 image
data "aws_ami" "amzn_linux_2023_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Data source to get the client's public IP
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

# Security group for ingress SSH traffic and all egress traffic 
resource "aws_security_group" "maximus_fwrule" {
  name        = "maximus-fwrule"
  description = "Allow ingress SSH traffic and all egress traffic"
  vpc_id      = aws_vpc.maximus_network.id

  tags = {
    Name = "maximus-fwrule"
  }
}

# Ingress rule allowing SSH traffic
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ingress" {
  security_group_id = aws_security_group.maximus_fwrule.id
  cidr_ipv4         = "${chomp(data.http.myip.response_body)}/32"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH access from my IP"
}

# Egress rule allowing all traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_egress" {
  security_group_id = aws_security_group.maximus_fwrule.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# EC2 instance with an associated Public IP address
resource "aws_instance" "maximus-server" {
  ami                         = data.aws_ami.amzn_linux_2023_ami.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.maximus_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.maximus_fwrule.id]
  key_name                    = "maximus-ec2-keys"
  monitoring                  = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name = var.instance_name == "" ? "maximus-server" : var.instance_name
  }
}

# Additional EBS volume
resource "aws_ebs_volume" "maximus_data_volume" {
  availability_zone = var.zone
  size              = 8     # Size in GB
  type              = "gp2" # or gp2, io1, io2, st1, sc1
  encrypted         = true  # Optional but recommended

  tags = {
    Name = "maximus-data-volume"
  }
}

# Attach the EBS volume to the EC2 instance
resource "aws_volume_attachment" "maximus_data_attachment" {
  device_name = "/dev/sdf" # Will appear as /dev/nvme1n1 on newer instances
  volume_id   = aws_ebs_volume.maximus_data_volume.id
  instance_id = aws_instance.maximus-server.id
}
