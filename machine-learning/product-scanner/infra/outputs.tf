output "api_base_url" {
  description = "Base URL for the API Gateway — append /upload-url or /analyze"
  value       = aws_api_gateway_stage.api.invoke_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for image uploads"
  value       = aws_s3_bucket.inputs.id
}

output "lambda_function_name" {
  description = "Lambda function name (useful for logs)"
  value       = aws_lambda_function.api.function_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}
