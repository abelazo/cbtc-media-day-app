resource "aws_lambda_function" "authorizer" {
  #checkov:skip=CKV_AWS_50:No need to enable X-Ray
  #checkov:skip=CKV_AWS_116:No need for DLQ
  #checkov:skip=CKV_AWS_117:It is OK to be in VPC without NAT for this function
  #checkov:skip=CKV_AWS_173:No need to encrypt environment variables

  function_name = "${var.project_name}-${var.environment}-authorizer"
  description   = var.release_version
  role          = aws_iam_role.authorizer_lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  reserved_concurrent_executions = -1

  s3_bucket               = data.terraform_remote_state.global.outputs.lambda_sources_bucket_name
  s3_key                  = "authorizer/authorizer.zip"
  code_signing_config_arn = data.terraform_remote_state.global.outputs.signing_config_arn

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      USERS_TABLE_NAME = data.terraform_remote_state.global.outputs.users_table_name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.authorizer_lambda,
    aws_iam_role_policy_attachment.authorizer_lambda_basic
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-authorizer"
  }
}

resource "aws_cloudwatch_log_group" "authorizer_lambda" {
  #checkov:skip=CKV_AWS_158:AWS-manged key is acceptable
  #checkov:skip=CKV_AWS_338:30 days retention is acceptable

  name              = "/aws/lambda/${var.project_name}-${var.environment}-authorizer"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-authorizer-logs"
  }
}
