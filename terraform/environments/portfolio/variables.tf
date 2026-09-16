variable "project_id" {
  description = "Google Cloud project ID used by the portfolio environment."
  type        = string
}

variable "region" {
  description = "Primary Google Cloud region for the portfolio environment."
  type        = string
  default     = "europe-central2"
}

variable "environment" {
  description = "Environment name used for resource naming and labeling."
  type        = string
  default     = "portfolio"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "Environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}