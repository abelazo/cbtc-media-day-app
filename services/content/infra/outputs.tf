output "content_function_arn" {
  description = "ARN of the content Lambda function"
  value       = aws_lambda_function.content_service.arn
}

output "content_invoke_arn" {
  description = "Invoke ARN of the content Lambda function"
  value       = aws_lambda_function.content_service.invoke_arn
}

output "content_function_name" {
  description = "Name of the content Lambda function"
  value       = aws_lambda_function.content_service.function_name
}
