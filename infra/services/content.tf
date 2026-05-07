# Content Lambda function #####################################################
resource "aws_lambda_function" "content_service" {
  #checkov:skip=CKV_AWS_50:No need to enable X-Ray
  #checkov:skip=CKV_AWS_116:No need for DLQ
  #checkov:skip=CKV_AWS_117:It is OK to be in VPC without NAT for this function
  #checkov:skip=CKV_AWS_173:No need to encrypt environment variables

  function_name = "${var.project_name}-${var.environment}-content"
  role          = aws_iam_role.content_lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 512

  reserved_concurrent_executions = -1

  s3_bucket               = local.lambda_sources_bucket_name
  s3_key                  = "content_service/content_service.zip"
  code_signing_config_arn = aws_lambda_code_signing_config.dev.arn

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      USERS_TABLE_NAME    = aws_dynamodb_table.users.name
      CONTENT_BUCKET_NAME = aws_s3_bucket.content.id
      CBTC_APP_URL        = var.app_url
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.content_lambda,
    aws_iam_role_policy_attachment.content_lambda_basic
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-content"
  }
}



# IAM permissions #############################################################
resource "aws_iam_role" "content_lambda" {
  name = "${var.project_name}-${var.environment}-content-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-content-lambda"
  }
}

resource "aws_iam_role_policy_attachment" "content_lambda_basic" {
  role       = aws_iam_role.content_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "content_lambda_s3" {
  name = "${var.project_name}-${var.environment}-content-s3"
  role = aws_iam_role.content_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.content.arn,
          "${aws_s3_bucket.content.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "content_lambda_dynamodb" {
  name = "${var.project_name}-${var.environment}-content-dynamodb"
  role = aws_iam_role.content_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.users.arn
      }
    ]
  })
}

# CloudWatch Log Group for content Lambda #####################################
resource "aws_cloudwatch_log_group" "content_lambda" {
  #checkov:skip=CKV_AWS_158:AWS-manged key is acceptable for content_lambda logs
  #checkov:skip=CKV_AWS_338:30 days retention is acceptable for content_lambda logs

  name              = "/aws/lambda/${var.project_name}-${var.environment}-content"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-content-logs"
  }
}

# Content Bucket ##############################################################
resource "aws_s3_bucket" "content" {
  bucket = "${var.project_name}-${var.environment}-content-${data.aws_caller_identity.current.account_id}"

  # Force destroy for easier cleanup in dev/local
  force_destroy = var.environment == "local" ? true : false

  tags = {
    Name = "${var.project_name}-${var.environment}-content-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id

  versioning_configuration {
    status = "Disabled"
  }
}

#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "content" {
  bucket = aws_s3_bucket.content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
