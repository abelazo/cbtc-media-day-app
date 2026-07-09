data "aws_caller_identity" "current" {}

# S3 bucket for Lambda source code ############################################
resource "aws_s3_bucket" "lambda_sources" {
  #checkov:skip=CKV_AWS_18:No login required
  #checkov:skip=CKV_AWS_21:No versioning required for this bucket
  #checkov:skip=CKV_AWS_144:No cross-region replication required
  #checkov:skip=CKV_AWS_145:AES256 encryption is enough
  #checkov:skip=CKV2_AWS_62:No event notifications required

  bucket = "lambda-sources-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "lambda-sources-${var.environment}"
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_sources" {
  bucket = aws_s3_bucket.lambda_sources.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "lambda_sources" {
  bucket = aws_s3_bucket.lambda_sources.id

  versioning_configuration {
    status = "Enabled"
  }
}
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_sources" {
  bucket = aws_s3_bucket.lambda_sources.id

  rule {
    blocked_encryption_types = ["SSE-C"]
    bucket_key_enabled       = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lambda_packages" {
  bucket = aws_s3_bucket.lambda_sources.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_lambda_code_signing_config" "lambdas" {
  description = "Code signing configuration for Lambda functions"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.lambdas.version_arn,
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce" # Block deployments that fail code signing validation
  }

  tags = {
    Purpose = "code-signing"
  }
}

resource "aws_signer_signing_profile" "lambdas" {
  platform_id = "AWSLambda-SHA384-ECDSA"
}
