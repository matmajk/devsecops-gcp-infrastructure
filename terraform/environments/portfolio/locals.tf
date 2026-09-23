locals {
  name_prefix = "devsecops-${var.environment}"

  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "devsecops-gcp-platform"
  }

  project_services = toset([
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com"
  ])
}