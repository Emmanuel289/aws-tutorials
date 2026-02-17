# ---- IAM role for the Lambda execution ----- #

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


# ---- IAM policy for S3 access ---- #

data "aws_iam_policy_document" "lambda_s3_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:DeleteObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.source_bucket.arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.source_bucket.arn]
  }
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "${var.bucket_name}_s3_policy"
  description = "A policy that allows objects to be read, modified, inserted into, and deleted from the specified bucket"
  policy      = data.aws_iam_policy_document.lambda_s3_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}


# ---- IAM policy to enable logging to CloudWatch ---- #

data "aws_iam_policy_document" "lambda_logging_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "logging_policy" {
  name   = "lambda_logging_policy"
  policy = data.aws_iam_policy_document.lambda_logging_policy.json
}

resource "aws_iam_role_policy_attachment" "logging_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.logging_policy.arn
}
