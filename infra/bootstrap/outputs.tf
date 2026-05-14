output "tfstate_bucket" {
  description = "The name of the S3 bucket used for Terraform state storage"
  value       = aws_s3_bucket.terraform_state.id
}

output "deployments_audit_bucket" {
  description = "Name of the S3 bucket holding the deployments audit log (deployments.jsonl)"
  value       = aws_s3_bucket.deployments_audit.id
}
