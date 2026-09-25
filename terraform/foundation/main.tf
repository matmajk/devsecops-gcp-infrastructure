module "artifact_registry" {
  source = "../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_registry_repository_id
}

module "github_actions_wif" {
  source = "../modules/github-actions-wif"

  project_id = var.project_id

  github_repository_owner = var.github_repository_owner
  github_repository       = var.github_repository

  workload_identity_pool_id     = var.workload_identity_pool_id
  workload_identity_provider_id = var.workload_identity_provider_id
  service_account_id            = var.service_account_id

  artifact_registry_location      = var.region
  artifact_registry_repository_id = module.artifact_registry.repository_id
}