output "api_gateway_url" {
  description = "Public URL for the API Gateway"
  value       = "${aws_api_gateway_stage.v1.invoke_url}/content"
}

output "content_lambda_arn" {
  description = "ARN of the content Lambda function"
  value       = aws_lambda_function.content_service.arn
}

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "users_table_name" {
  description = "Name of the users DynamoDB table"
  value       = aws_dynamodb_table.users.name
}

output "signing_profile_name" {
  description = "Name of the AWS Signer signing profile"
  value       = aws_signer_signing_profile.dev.name
}
