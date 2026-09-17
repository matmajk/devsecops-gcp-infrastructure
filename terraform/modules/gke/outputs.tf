output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "Location of the GKE control plane."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "Public endpoint of the GKE control plane."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "node_pool_name" {
  description = "Name of the primary GKE node pool."
  value       = google_container_node_pool.primary.name
}