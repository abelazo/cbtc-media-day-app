resource "aws_lambda_function" "content_service" {
  #checkov:skip=CKV_AWS_50:No need to enable X-Ray
  #checkov:skip=CKV_AWS_116:No need for DLQ
  #checkov:skip=CKV_AWS_117:It is OK to be in VPC without NAT for this function
  #checkov:skip=CKV_AWS_173:No need to encrypt environment variables

  function_name = "${var.project_name}-${var.environment}-content"
  description   = var.release_version
  role          = aws_iam_role.content_lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 512

  reserved_concurrent_executions = -1

  s3_bucket               = data.terraform_remote_state.global.outputs.lambda_sources_bucket_name
  s3_key                  = "content/content.zip"
  code_signing_config_arn = data.terraform_remote_state.global.outputs.signing_config_arn

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      USERS_TABLE_NAME    = data.terraform_remote_state.global.outputs.users_table_name
      CONTENT_BUCKET_NAME = data.terraform_remote_state.global.outputs.content_bucket_name
      CBTC_APP_URL        = var.app_url
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.content_lambda,
    aws_iam_role_policy_attachment.content_lambda_basic
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-content"
  }
}

resource "aws_cloudwatch_log_group" "content_lambda" {
  #checkov:skip=CKV_AWS_158:AWS-manged key is acceptable for content_lambda logs
  #checkov:skip=CKV_AWS_338:30 days retention is acceptable for content_lambda logs

  name              = "/aws/lambda/${var.project_name}-${var.environment}-content"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-content-logs"
  }
}
