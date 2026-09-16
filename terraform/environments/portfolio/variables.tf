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

variable "network_cidrs" {
  description = "IPv4 CIDR ranges used by the portfolio network and GKE."
  type = object({
    subnet   = string
    pods     = string
    services = string
  })

  default = {
    subnet   = "10.10.0.0/20"
    pods     = "10.20.0.0/16"
    services = "10.30.0.0/20"
  }

  validation {
    condition = (
      can(cidrhost(var.network_cidrs.subnet, 0)) &&
      can(cidrhost(var.network_cidrs.pods, 0)) &&
      can(cidrhost(var.network_cidrs.services, 0))
    )

    error_message = "All network CIDR values must be valid CIDR ranges."
  }
}