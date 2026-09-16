variable "project_id" {
  description = "Google Cloud project ID containing the Terraform state bucket."
  type        = string
}

variable "region" {
  description = "Google Cloud region used for the Terraform state bucket."
  type        = string
  default     = "europe-central2"
}

variable "state_bucket_name" {
  description = "Globally unique name of the Cloud Storage bucket used for Terraform state."
  type        = string

  validation {
    condition = (
      length(var.state_bucket_name) >= 3 &&
      length(var.state_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9_-]*[a-z0-9]$", var.state_bucket_name))
    )

    error_message = "State bucket name must contain 3-63 lowercase letters, numbers, hyphens or underscores and must start and end with a letter or number."
  }
}