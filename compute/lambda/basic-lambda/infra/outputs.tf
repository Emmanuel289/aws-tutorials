output "function_arn" {
  value = aws_lambda_function.main.arn
}

output "bucket_name" {
  value = aws_s3_bucket.source_bucket.arn
}

output "lambda_result" {
  value = jsondecode(aws_lambda_invocation.one_time_trigger.result)
}
