resource "aws_s3_bucket" "content" {
  bucket = "${var.project_name}-${var.environment}-content-${data.aws_caller_identity.current.account_id}"

  force_destroy = false

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
