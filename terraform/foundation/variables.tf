variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Primary Google Cloud region"
  type        = string
}

variable "artifact_registry_repository_id" {
  description = "Persistent Artifact Registry repository ID"
  type        = string
  default     = "online-boutique"
}

variable "github_repository_owner" {
  description = "GitHub repository owner allowed to authenticate through WIF"
  type        = string
  default     = "matmajk"
}

variable "github_repository" {
  description = "GitHub repository allowed to authenticate through WIF"
  type        = string
  default     = "matmajk/online-boutique-devsecops"
}

variable "workload_identity_pool_id" {
  description = "Persistent GitHub Actions Workload Identity Pool ID"
  type        = string
  default     = "github-actions"
}

variable "workload_identity_provider_id" {
  description = "Persistent GitHub Actions Workload Identity Provider ID"
  type        = string
  default     = "github"
}

variable "service_account_id" {
  description = "Service account used by application GitHub Actions"
  type        = string
  default     = "github-actions-ci"
}