# VPC
resource "aws_vpc" "maximus_network" {
  region     = var.region
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = var.vpc
  }
}

# Public subnet
resource "aws_subnet" "maximus_subnet" {
  vpc_id                  = aws_vpc.maximus_network.id
  availability_zone       = var.zone
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = var.subnet
  }

}

# Internet Gateway for Public subnet
resource "aws_internet_gateway" "maximus_igw" {
  vpc_id = aws_vpc.maximus_network.id

  tags = {
    Name = "maximus-igw"
  }
}

# Route table for public subnet
resource "aws_route_table" "maximus_public_rt" {
  vpc_id = aws_vpc.maximus_network.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.maximus_igw.id
  }

  tags = {
    Name = "maximus-public-rt"
  }
}

# Route table association to public subnet
resource "aws_route_table_association" "maximus_public_rta" {
  subnet_id      = aws_subnet.maximus_subnet.id
  route_table_id = aws_route_table.maximus_public_rt.id
}
