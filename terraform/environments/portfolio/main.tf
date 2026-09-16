locals {
  name_prefix = "devsecops-${var.environment}"

  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "devsecops-gcp-platform"
  }
}

module "network" {
  source = "../../modules/network"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  subnet_cidr   = var.network_cidrs.subnet
  pods_cidr     = var.network_cidrs.pods
  services_cidr = var.network_cidrs.services
}