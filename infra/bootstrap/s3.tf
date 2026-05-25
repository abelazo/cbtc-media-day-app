# Get account id
data "aws_caller_identity" "current" {}

# Bucket for terraform state
locals {
  bucket_name = "cbtc-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "terraform_state" {
  #checkov:skip=CKV2_AWS_62:Not enabling event notifications for cost reasons
  #checkov:skip=CKV_AWS_144:Not enabling cross-region replication for cost reasons
  #checkov:skip=CKV_AWS_18:Not enabling access logging for cost reasons
  #checkov:skip=CKV_AWS_145:Using SSE-S3 instead of KMS for cost reasons

  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_stat_access_block" {
  bucket = aws_s3_bucket.terraform_state.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.bucket

  versioning_configuration {
    status = "Enabled"
  }
}
