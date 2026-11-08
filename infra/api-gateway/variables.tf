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

variable "release_version" {
  description = "Release version stamped on every resource via the DeployedVersion tag. Set by CI to e.g. api-gateway-v1.4.0."
  type        = string
  default     = "api-gateway-vunreleased"
}

variable "throttling_rate_limit" {
  description = "Steady-state requests per second allowed on the stage, shared by all clients. Excess requests get HTTP 429."
  type        = number
  default     = 10
}

variable "throttling_burst_limit" {
  description = "Maximum requests accepted at once on the stage (token bucket size) before the rate limit applies."
  type        = number
  default     = 50
}
