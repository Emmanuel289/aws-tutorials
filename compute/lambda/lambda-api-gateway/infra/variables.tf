variable "region" {
  type        = string
  description = "AWS region to deploy to"
}

variable "bucket" {
  type        = string
  description = "Name of bucket to store the inputs and lambda function"
}
