provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "cbtc-media-day"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
