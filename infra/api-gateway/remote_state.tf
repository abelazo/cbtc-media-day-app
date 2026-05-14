data "aws_caller_identity" "current" {}

data "terraform_remote_state" "authorizer" {
  backend = "s3"

  config = {
    bucket = "cbtc-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "lambda.authorizer.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "content" {
  backend = "s3"

  config = {
    bucket = "cbtc-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "lambda.content.tfstate"
    region = var.aws_region
  }
}
