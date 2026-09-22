variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for JFrog backing services"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for JFrog resource names"
  type        = string
}

variable "network_id" {
  description = "VPC network ID used by the JFrog Cloud SQL instance"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version used by JFrog"
  type        = string
  default     = "POSTGRES_15"
}

variable "database_tier" {
  description = "Cloud SQL machine tier used by the portfolio JFrog environment"
  type        = string
  default     = "db-g1-small"
}

variable "database_disk_size_gb" {
  description = "Initial Cloud SQL disk size in GB"
  type        = number
  default     = 10
}

variable "database_disk_autoresize_limit_gb" {
  description = "Maximum Cloud SQL disk size in GB"
  type        = number
  default     = 20
}

variable "jfrog_namespace" {
  description = "Kubernetes namespace used by JFrog"
  type        = string
  default     = "jfrog"
}

variable "jfrog_kubernetes_service_account" {
  description = "Kubernetes ServiceAccount used by JFrog"
  type        = string
  default     = "jfrog"
}