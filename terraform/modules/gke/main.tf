locals {
  cluster_name   = "${var.name_prefix}-gke"
  node_pool_name = "${var.name_prefix}-primary"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = local.cluster_name
  location = var.region

  network    = var.network_id
  subnetwork = var.subnetwork_id

  networking_mode = "VPC_NATIVE"

  remove_default_node_pool = true
  initial_node_count       = 1

  # GKE requires an initial default node pool during cluster creation even
  # when remove_default_node_pool is enabled. Keep the temporary pool aligned
  # with the portfolio sizing to avoid unnecessary quota consumption.
  node_config {
    machine_type = var.machine_type

    disk_type    = "pd-balanced"
    disk_size_gb = var.node_disk_size_gb

    service_account = var.node_service_account_email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }

  deletion_protection = false

  datapath_provider     = "ADVANCED_DATAPATH"
  enable_shielded_nodes = true

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.control_plane_authorized_cidr
      display_name = "developer-workstation"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = local.node_pool_name
  location = var.region
  cluster  = google_container_cluster.this.name

  node_locations = var.node_locations

  node_count = 1

  node_config {
    machine_type = var.machine_type

    disk_type    = "pd-balanced"
    disk_size_gb = var.node_disk_size_gb

    image_type = "COS_CONTAINERD"

    service_account = var.node_service_account_email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}