resource "google_compute_router_nat" "this" {
  project = var.project_id
  region  = var.region

  name   = "${var.name_prefix}-${var.region}-nat"
  router = var.router_name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = var.subnetwork_id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}