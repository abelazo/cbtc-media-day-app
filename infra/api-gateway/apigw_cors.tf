resource "aws_api_gateway_method" "content_options" {
  rest_api_id          = aws_api_gateway_rest_api.main.id
  resource_id          = aws_api_gateway_resource.content.id
  http_method          = "OPTIONS"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.main.id
}

resource "aws_api_gateway_method_response" "content_options_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.content.id
  http_method = aws_api_gateway_method.content_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "content_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.content.id
  http_method = aws_api_gateway_method.content_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "content_options_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.content.id
  http_method = aws_api_gateway_method.content_options.http_method
  status_code = aws_api_gateway_method_response.content_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Authorization,Content-Type'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'${data.terraform_remote_state.content.outputs.app_url}'"
  }

  depends_on = [
    aws_api_gateway_integration.content_options,
    aws_api_gateway_method_response.content_options_200
  ]
}

# Errors raised by API Gateway itself (authorizer deny, missing credentials, throttling, ...) skip the lambda, so the
# CORS header must be added here or the browser hides the status code from the app.
resource "aws_api_gateway_gateway_response" "cors" {
  for_each = toset(["DEFAULT_4XX", "DEFAULT_5XX"])

  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = each.key

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${data.terraform_remote_state.content.outputs.app_url}'"
  }
}
