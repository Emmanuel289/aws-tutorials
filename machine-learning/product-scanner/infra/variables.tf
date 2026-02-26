variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for all resources"
  type        = string
  default     = "product-scanner"
}

variable "openai_api_key" {
  description = "OpenAI API key — never commit this value, pass via TF_VAR or AWS Secrets Manager"
  type        = string
  sensitive   = true
}
