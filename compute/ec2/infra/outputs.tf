output "vpc_id" {
  value       = aws_vpc.maximus_network.id
  description = "ID assigned to the network"
}

output "subnet_id" {
  value       = aws_subnet.maximus_subnet.id
  description = "ID assigned to the subnet"
}

output "instance_id" {
  value       = aws_instance.maximus-server.id
  description = "ID assigned to the EC2 instance"
}

output "instance_ip" {
  value       = aws_instance.maximus-server.public_ip
  description = "Public IP address assigned to the EC2 instance"
}
