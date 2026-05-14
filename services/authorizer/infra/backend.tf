terraform {
  backend "s3" {
    key     = "lambda.authorizer.tfstate"
    encrypt = "true"
  }
}
