output "gke_node_service_account_email" {
  description = "Email address of the service account used by GKE worker nodes."
  value       = google_service_account.gke_nodes.email
}

output "gke_node_service_account_member" {
  description = "IAM member representation of the GKE node service account."
  value       = "serviceAccount:${google_service_account.gke_nodes.email}"
}