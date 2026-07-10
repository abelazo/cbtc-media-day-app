data "aws_caller_identity" "current" {}

data "terraform_remote_state" "global" {
  backend = "s3"

  config = {
    bucket = "cbtc-terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "env:/${var.environment}/global.tfstate"
    region = var.aws_region
  }
}
