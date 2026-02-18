# S3 bucket that serves as the event source
resource "aws_s3_bucket" "source_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "${var.bucket_name}"
    Environment = "Dev"
  }

  force_destroy = true


}

# Package the lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/main.py"
  output_path = "${path.module}/main.zip"
}

# Lambda function
resource "aws_lambda_function" "main" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "main-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  code_sha256   = data.archive_file.lambda_zip.output_base64sha256
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      ENVIRONMENT = "dev"
      LOG_LEVEL   = "info"
    }
  }

  tags = {
    Environment = "dev"
    Application = "example"
  }

  # Advanced logging configuration
  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  # Ensure log group exists before function
  depends_on = [aws_cloudwatch_log_group.example]
}


# Cloud Watch Log Group for logging function invocations
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/main-lambda-function"
  retention_in_days = 1

  tags = {
    Environment = "dev"
    Application = "example"
  }
}


# Invoke the function during resource creation
resource "aws_lambda_invocation" "one_time_trigger" {
  function_name = aws_lambda_function.main.function_name
  input         = jsonencode(jsondecode(file("${path.module}/test-event.json")))

  triggers = {
    rerun = timestamp() # forces rerun on every apply
  }
}


