module "project_services" {
  source = "../../modules/project-services"

  project_id = var.project_id
  services   = local.project_services
}

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  name_prefix = local.name_prefix

  depends_on = [
    module.project_services
  ]
}

module "network" {
  source = "../../modules/network"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  subnet_cidr   = var.network_cidrs.subnet
  pods_cidr     = var.network_cidrs.pods
  services_cidr = var.network_cidrs.services

  depends_on = [
    module.project_services
  ]
}