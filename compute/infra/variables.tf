
variable "vpc" {
  type        = string
  description = "The name of the VPC"
  default     = "maximus-network"
}

variable "subnet" {
  type        = string
  description = "The name of the subnet where instances are provisioned"
  default     = "maximus-subnet"
}

variable "region" {
  type        = string
  description = "The region where VPC resources are provisioned"
  default     = "us-east-1"
}

variable "zone" {
  type        = string
  description = "The availability zone where subnets are provisioned"
  default     = "us-east-1a"
}


variable "instance_name" {
  type        = string
  description = "The name tag of the instance"
  default     = ""
}
