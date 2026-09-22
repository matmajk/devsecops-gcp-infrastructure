locals {
  network_name                  = "${var.name_prefix}-vpc"
  subnet_name                   = "${var.name_prefix}-${var.region}-subnet"
  router_name                   = "${var.name_prefix}-${var.region}-router"
  pods_secondary_range_name     = "${var.name_prefix}-pods"
  services_secondary_range_name = "${var.name_prefix}-services"
  private_services_range_name   = "${var.name_prefix}-private-services"
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

resource "google_compute_global_address" "private_services" {
  count   = var.private_services_access_enabled ? 1 : 0
  project = var.project_id

  name          = local.private_services_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_services_prefix_length
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "private_services" {
  count = var.private_services_access_enabled ? 1 : 0

  network = google_compute_network.this.id
  service = "servicenetworking.googleapis.com"

  reserved_peering_ranges = [
    google_compute_global_address.private_services[0].name
  ]

  deletion_policy = "REMOVE_PEERING"
}