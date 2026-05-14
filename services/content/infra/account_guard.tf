locals {
  expected_account_ids = {
    dev  = "454591548336"
    prod = "788070448579"
  }
}

resource "terraform_data" "account_guard" {
  input = {
    environment = var.environment
    account_id  = data.aws_caller_identity.current.account_id
  }

  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == local.expected_account_ids[var.environment]
      error_message = "Wrong AWS account for env '${var.environment}': expected ${local.expected_account_ids[var.environment]}, got ${data.aws_caller_identity.current.account_id}."
    }
  }
}
