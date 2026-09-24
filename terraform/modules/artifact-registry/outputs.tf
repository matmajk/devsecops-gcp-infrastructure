output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_name" {
  description = "Artifact Registry repository resource name"
  value       = google_artifact_registry_repository.this.name
}

output "repository_location" {
  description = "Artifact Registry repository location"
  value       = google_artifact_registry_repository.this.location
}

output "docker_registry_host" {
  description = "Artifact Registry Docker registry hostname"
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev"
}

output "docker_repository_url" {
  description = "Base Docker repository URL"
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}