output "authorizer_function_arn" {
  description = "ARN of the authorizer Lambda function"
  value       = aws_lambda_function.authorizer.arn
}

output "authorizer_invoke_arn" {
  description = "Invoke ARN of the authorizer Lambda function"
  value       = aws_lambda_function.authorizer.invoke_arn
}

output "authorizer_function_name" {
  description = "Name of the authorizer Lambda function"
  value       = aws_lambda_function.authorizer.function_name
}
