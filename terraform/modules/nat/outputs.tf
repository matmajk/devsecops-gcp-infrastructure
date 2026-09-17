output "name" {
  description = "Name of the Cloud NAT configuration."
  value       = google_compute_router_nat.this.name
}