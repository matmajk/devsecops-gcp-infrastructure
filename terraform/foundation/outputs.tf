output "artifact_registry_repository_id" {
  description = "Persistent Artifact Registry repository ID"
  value       = module.artifact_registry.repository_id
}

output "artifact_registry_repository_name" {
  description = "Persistent Artifact Registry repository resource name"
  value       = module.artifact_registry.repository_name
}

output "artifact_registry_repository_url" {
  description = "Docker repository URL used by application CI"
  value       = module.artifact_registry.docker_repository_url
}

output "github_actions_service_account_email" {
  description = "Service account used by application GitHub Actions"
  value       = module.github_actions_wif.service_account_email
}

output "workload_identity_pool_name" {
  description = "GitHub Actions Workload Identity Pool resource name"
  value       = module.github_actions_wif.workload_identity_pool_name
}

output "workload_identity_provider_name" {
  description = "GitHub Actions Workload Identity Provider resource name"
  value       = module.github_actions_wif.workload_identity_provider_name
}