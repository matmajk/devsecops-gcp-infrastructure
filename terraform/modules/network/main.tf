locals {
  network_name                  = "${var.name_prefix}-vpc"
  subnet_name                   = "${var.name_prefix}-${var.region}-subnet"
  router_name                   = "${var.name_prefix}-${var.region}-router"
  pods_secondary_range_name     = "${var.name_prefix}-pods"
  services_secondary_range_name = "${var.name_prefix}-services"
}

resource "google_compute_network" "this" {
  project = var.project_id

  name                    = local.network_name
  auto_create_subnetworks = false # We are creating custom subnets, so we don't want GCP to    create default subnets for us.
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project = var.project_id

  name          = local.subnet_name
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.subnet_cidr

  stack_type               = "IPV4_ONLY"
  private_ip_google_access = true # This allows the GKE nodes to access Google APIs and services without using public IPs.

  secondary_ip_range {
    range_name    = local.pods_secondary_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = local.services_secondary_range_name
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  project = var.project_id

  name    = local.router_name
  region  = var.region
  network = google_compute_network.this.id
}