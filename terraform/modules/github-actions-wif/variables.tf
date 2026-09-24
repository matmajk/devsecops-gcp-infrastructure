variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "github_repository_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/repository format"
  type        = string
}

variable "workload_identity_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-actions"
}

variable "workload_identity_provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github"
}

variable "service_account_id" {
  description = "Google Service Account ID used by GitHub Actions"
  type        = string
  default     = "github-actions-ci"
}

variable "artifact_registry_location" {
  description = "Artifact Registry repository location"
  type        = string
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID accessible by GitHub Actions"
  type        = string
}