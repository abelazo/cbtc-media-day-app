resource "aws_s3_bucket" "content" {
  #checkov:skip=CKV2_AWS_62:Not enabling event notifications for cost reasons
  #checkov:skip=CKV_AWS_21:Not enabling versioning for cost reasons
  #checkov:skip=CKV_AWS_144:Not enabling cross-region replication for cost reasons
  #checkov:skip=CKV_AWS_18:Not enabling access logging for cost reasons
  #checkov:skip=CKV_AWS_145:Using SSE-S3 instead of KMS for cost reasons

  bucket = "${var.project_name}-${var.environment}-content-${data.aws_caller_identity.current.account_id}"

  force_destroy = false

  tags = {
    Name = "${var.project_name}-${var.environment}-content-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "content" {
  bucket = aws_s3_bucket.content.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
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
