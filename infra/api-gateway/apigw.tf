resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "API Gateway for ${var.project_name}"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api"
  }
}

resource "aws_api_gateway_resource" "content" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "content"
}

resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name                   = "${var.project_name}-${var.environment}-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  authorizer_uri         = data.terraform_remote_state.authorizer.outputs.authorizer_invoke_arn
  authorizer_credentials = aws_iam_role.authorizer_invocation.arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.Authorization"
}

resource "aws_iam_role" "authorizer_invocation" {
  name = "${var.project_name}-${var.environment}-authorizer-invocation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "authorizer_invocation" {
  name = "${var.project_name}-${var.environment}-authorizer-invocation"
  role = aws_iam_role.authorizer_invocation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = data.terraform_remote_state.authorizer.outputs.authorizer_function_arn
      }
    ]
  })
}

resource "aws_api_gateway_request_validator" "main" {
  name                        = "${var.project_name}-${var.environment}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "content_get" {
  rest_api_id          = aws_api_gateway_rest_api.main.id
  resource_id          = aws_api_gateway_resource.content.id
  http_method          = "GET"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.lambda_authorizer.id
  request_validator_id = aws_api_gateway_request_validator.main.id
}

resource "aws_api_gateway_integration" "content_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.content.id
  http_method             = aws_api_gateway_method.content_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.content.outputs.content_invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.content.outputs.content_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "v1" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.content.id,
      aws_api_gateway_method.content_get.id,
      aws_api_gateway_integration.content_lambda.id,
      aws_api_gateway_authorizer.lambda_authorizer.id,
      aws_api_gateway_method.content_options.id,
      aws_api_gateway_integration.content_options.id,
      data.terraform_remote_state.authorizer.outputs.authorizer_invoke_arn,
      data.terraform_remote_state.content.outputs.content_invoke_arn,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.content_lambda
  ]
}

resource "aws_api_gateway_stage" "v1" {
  #checkov:skip=CKV_AWS_73:Not activating X-Ray for cost reasons
  #checkov:skip=CKV_AWS_76:Not activating access logging for cost reasons
  #checkov:skip=CKV_AWS_120:Not activating Catching for cost reasons
  #checkov:skip=CKV2_AWS_51:Not using client cert auth for operational simplicity
  #checkov:skip=CKV2_AWS_4:Not setting logging level for cost reasons
  #checkov:skip=CKV2_AWS_29:Not enabling WAF for cost reasons

  deployment_id = aws_api_gateway_deployment.v1.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "v1"

  tags = {
    Name = "${var.project_name}-${var.environment}-v1"
  }
}
