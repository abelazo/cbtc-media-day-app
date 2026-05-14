terraform {
  backend "s3" {
    key     = "lambda.content.tfstate"
    encrypt = "true"
  }
}
