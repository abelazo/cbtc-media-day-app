locals {
  audit_bucket_name = "cbtc-deployments-audit-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "deployments_audit" {
  #checkov:skip=CKV_AWS_18:No access-logging required for an audit bucket on a solo project
  #checkov:skip=CKV_AWS_144:No cross-region replication required
  #checkov:skip=CKV_AWS_145:AES256 encryption is enough
  #checkov:skip=CKV2_AWS_62:No event notifications required

  bucket = local.audit_bucket_name

  tags = {
    Name    = local.audit_bucket_name
    Purpose = "deployments-audit-log"
  }
}

resource "aws_s3_bucket_public_access_block" "deployments_audit" {
  bucket = aws_s3_bucket.deployments_audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "deployments_audit" {
  bucket = aws_s3_bucket.deployments_audit.id

  versioning_configuration {
    status = "Enabled"
  }
}

#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "deployments_audit" {
  bucket = aws_s3_bucket.deployments_audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "deployments_audit" {
  bucket = aws_s3_bucket.deployments_audit.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
