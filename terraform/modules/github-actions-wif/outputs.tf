output "service_account_email" {
  description = "Google Service Account email used by GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "workload_identity_pool_name" {
  description = "Workload Identity Pool resource name"
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider_name" {
  description = "Workload Identity Provider resource name"
  value       = google_iam_workload_identity_pool_provider.github.name
}