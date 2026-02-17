variable "region" {
  description = "AWS region to deploy to"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for the event source"
  type        = string
}
