variable "project_id" {
  description = "Google Cloud project ID where networking resources will be created."
  type        = string
}

variable "region" {
  description = "Google Cloud region for regional networking resources."
  type        = string
}

variable "name_prefix" {
  description = "Common prefix used for network resource names."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary IPv4 CIDR range used by GKE nodes and regional resources."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR range."
  }
}

variable "pods_cidr" {
  description = "Secondary IPv4 CIDR range reserved for GKE Pods."
  type        = string

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be a valid CIDR range."
  }
}

variable "services_cidr" {
  description = "Secondary IPv4 CIDR range reserved for Kubernetes Services."
  type        = string

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be a valid CIDR range."
  }
}
