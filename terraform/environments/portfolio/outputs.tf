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

output "network_name" {
  description = "Name of the portfolio VPC network."
  value       = module.network.network_name
}

output "subnetwork_name" {
  description = "Name of the portfolio regional subnetwork."
  value       = module.network.subnetwork_name
}

output "pods_secondary_range_name" {
  description = "Secondary range used by GKE Pods."
  value       = module.network.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Secondary range used by Kubernetes Services."
  value       = module.network.services_secondary_range_name
}

output "router_name" {
  description = "Name of the portfolio Cloud Router."
  value       = module.network.router_name
}

output "enabled_project_services" {
  description = "Google Cloud APIs managed for the portfolio project."
  value       = module.project_services.enabled_services
}

output "gke_node_service_account_email" {
  description = "Service account used by GKE worker nodes."
  value       = module.iam.gke_node_service_account_email
}