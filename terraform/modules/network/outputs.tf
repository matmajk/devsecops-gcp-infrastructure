output "network_id" {
  description = "ID of the VPC network."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the VPC network."
  value       = google_compute_network.this.name
}

output "subnetwork_id" {
  description = "ID of the regional subnetwork."
  value       = google_compute_subnetwork.this.id
}

output "subnetwork_name" {
  description = "Name of the regional subnetwork."
  value       = google_compute_subnetwork.this.name
}

output "subnetwork_cidr" {
  description = "Primary CIDR range of the regional subnetwork."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "pods_secondary_range_name" {
  description = "Name of the secondary IP range reserved for GKE Pods."
  value       = local.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Name of the secondary IP range reserved for Kubernetes Services."
  value       = local.services_secondary_range_name
}

output "router_name" {
  description = "Name of the regional Cloud Router."
  value       = google_compute_router.this.name
}