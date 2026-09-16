variable "project_id" {
  description = "Google Cloud project ID where IAM resources will be created."
  type        = string
}

variable "name_prefix" {
  description = "Common prefix used for IAM resource names."
  type        = string
}