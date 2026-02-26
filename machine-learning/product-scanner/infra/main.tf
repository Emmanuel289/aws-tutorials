# ── Local values ───────────────────────────────────────────────────────────────
locals {
  name_prefix = var.project_name
  src         = "${path.module}/../backend"
  zip         = "${path.module}/backend.zip"
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 BUCKET — image uploads
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "inputs" {
  bucket        = "${local.name_prefix}-input"
  force_destroy = true

  tags = local.common_tags
}

resource "aws_s3_bucket_cors_configuration" "inputs" {
  bucket = aws_s3_bucket.inputs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["${data.http.myip.response_body}"] # Restricted to client IP
    max_age_seconds = 300
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inputs" {
  bucket = aws_s3_bucket.inputs.id

  rule {
    id     = "expire-uploads"
    status = "Enabled"

    expiration {
      days = 1
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM — Lambda execution role
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

}
resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = data.aws_iam_policy_document.policy_document.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachments_exclusive" "lambda_basic" {
  role_name = aws_iam_role.lambda.name

  policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${local.name_prefix}-lambda-s3-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      Resource = "${aws_s3_bucket.inputs.arn}/*"
    }]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Package and deploy the Lambda handler
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "ecr_repository" {
  name                 = "${local.name_prefix}-ecr-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = local.common_tags
}

resource "null_resource" "docker_build_push" {
  triggers = {
    dockerfile = filemd5("${path.module}/../backend/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin \
      ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      docker build \
        -t ${aws_ecr_repository.ecr_repository.repository_url}:latest \
        -f ${path.module}/../backend/Dockerfile \
        --no-cache \
        ${path.module}/../backend

      docker push ${aws_ecr_repository.ecr_repository.repository_url}:latest
    EOT
  }
}

resource "aws_lambda_function" "api" {
  function_name = "${local.name_prefix}-api"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.ecr_repository.repository_url}:latest"
  timeout       = 600
  memory_size   = 256

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.inputs.id
      OPENAI_API_KEY = var.openai_api_key
    }
  }

  depends_on = [null_resource.docker_build_push]

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 7
  tags              = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# API GATEWAY
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "api" {
  name        = "${local.name_prefix}-api"
  description = "AI Product Scanner API"

  tags = local.common_tags
}

# /upload-url
resource "aws_api_gateway_resource" "upload_url" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "upload-url"
}

resource "aws_api_gateway_method" "upload_url" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.upload_url.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_url" {
  http_method             = aws_api_gateway_method.upload_url.http_method
  resource_id             = aws_api_gateway_resource.upload_url.id
  rest_api_id             = aws_api_gateway_rest_api.api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# /analyze
resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "analyze"
}

resource "aws_api_gateway_method" "analyze" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "analyze" {
  http_method             = aws_api_gateway_method.analyze.http_method
  resource_id             = aws_api_gateway_resource.analyze.id
  rest_api_id             = aws_api_gateway_rest_api.api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn

}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
data "aws_caller_identity" "current" {}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload_url.id,
      aws_api_gateway_method.upload_url.id,
      aws_api_gateway_integration.upload_url.id,
      aws_api_gateway_resource.analyze.id,
      aws_api_gateway_method.analyze.id,
      aws_api_gateway_integration.analyze.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"

  tags = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# SHARED
# ─────────────────────────────────────────────────────────────────────────────
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
