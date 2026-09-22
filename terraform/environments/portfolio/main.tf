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

  private_services_access_enabled = true
  private_services_prefix_length  = 24

  depends_on = [
    module.project_services
  ]
}

module "nat" {
  source = "../../modules/nat"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  router_name   = module.network.router_name
  subnetwork_id = module.network.subnetwork_id
}

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  network_id    = module.network.network_id
  subnetwork_id = module.network.subnetwork_id

  pods_secondary_range_name     = module.network.pods_secondary_range_name
  services_secondary_range_name = module.network.services_secondary_range_name

  node_service_account_email = module.iam.gke_node_service_account_email

  node_locations    = var.gke_config.node_locations
  machine_type      = var.gke_config.machine_type
  node_disk_type    = var.gke_config.node_disk_type
  node_disk_size_gb = var.gke_config.node_disk_size_gb

  master_ipv4_cidr              = var.gke_config.master_ipv4_cidr
  control_plane_authorized_cidr = var.gke_config.control_plane_authorized_cidr

  autoscaling_total_min_nodes = var.gke_config.autoscaling.total_min_nodes
  autoscaling_total_max_nodes = var.gke_config.autoscaling.total_max_nodes

  depends_on = [
    module.nat,
    module.project_services,
  ]
}

module "jfrog" {
  source = "../../modules/jfrog"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  network_id = module.network.network_id

  database_version                  = "POSTGRES_15"
  database_tier                     = "db-g1-small"
  database_disk_size_gb             = 10
  database_disk_autoresize_limit_gb = 20

  jfrog_namespace                  = "jfrog"
  jfrog_kubernetes_service_account = "jfrog"

  depends_on = [
    module.project_services,
    module.network,
  ]
}