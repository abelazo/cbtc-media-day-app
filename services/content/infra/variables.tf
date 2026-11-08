variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cbtc-media-day"
}

variable "app_url" {
  description = "Origin of the frontend allowed by CORS. Set via TF_VAR_app_url (APP_URL secret in CI, .env locally)."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https?://[^/]+$", var.app_url))
    error_message = "app_url must be a bare origin (scheme://host[:port], no path or trailing slash)."
  }
}

variable "release_version" {
  description = "Release version stamped on every resource and on the Lambda function Description. Set by CI to e.g. content-v1.4.0."
  type        = string
  default     = "content-v0.0.0-dev"
}
