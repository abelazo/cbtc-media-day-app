terraform {
  backend "s3" {
    key     = "api-gateway.tfstate"
    encrypt = "true"
  }
}
