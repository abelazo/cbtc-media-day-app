output "lambda_sources_bucket_name" {
  description = "Name of the Lambda sources S3 bucket"
  value       = aws_s3_bucket.lambda_sources.id
}

output "lambda_sources_bucket_arn" {
  description = "ARN of the Lambda sources S3 bucket"
  value       = aws_s3_bucket.lambda_sources.arn
}

output "content_bucket_name" {
  description = "Name of the content S3 bucket"
  value       = aws_s3_bucket.content.id
}

output "content_bucket_arn" {
  description = "ARN of the content S3 bucket"
  value       = aws_s3_bucket.content.arn
}

output "users_table_name" {
  description = "Name of the users DynamoDB table"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "ARN of the users DynamoDB table"
  value       = aws_dynamodb_table.users.arn
}

output "signing_config_arn" {
  description = "ARN of the Lambda code signing config"
  value       = aws_lambda_code_signing_config.lambdas.arn
}

output "signing_profile_name" {
  description = "Name of the AWS Signer signing profile"
  value       = aws_signer_signing_profile.lambdas.name
}
