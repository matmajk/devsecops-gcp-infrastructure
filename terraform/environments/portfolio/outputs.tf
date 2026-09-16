output "project_id" {
  description = "Google Cloud project ID configured for the portfolio environment."
  value       = var.project_id
}

output "region" {
  description = "Primary Google Cloud region configured for the portfolio environment."
  value       = var.region
}

output "environment" {
  description = "Environment name."
  value       = var.environment
}

output "name_prefix" {
  description = "Common resource naming prefix."
  value       = local.name_prefix
}