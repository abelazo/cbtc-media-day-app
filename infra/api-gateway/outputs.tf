output "api_gateway_url" {
  description = "Public URL for the API Gateway"
  value       = "${aws_api_gateway_stage.v1.invoke_url}/content"
}

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}
