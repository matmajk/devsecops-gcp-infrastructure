locals {
  name_prefix = "devsecops-${var.environment}"

  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "devsecops-gcp-platform"
  }
}