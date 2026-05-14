resource "aws_lambda_code_signing_config" "lambdas" {
  description = "Code signing configuration for Lambda functions"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.lambdas.version_arn,
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce" # Block deployments that fail code signing validation
  }

  tags = {
    Purpose = "code-signing"
  }
}

resource "aws_signer_signing_profile" "lambdas" {
  platform_id = "AWSLambda-SHA384-ECDSA"
}
