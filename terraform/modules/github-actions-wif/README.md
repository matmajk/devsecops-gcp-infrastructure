# GitHub Actions Workload Identity Federation

Terraform module configuring keyless authentication between GitHub Actions and Google Cloud using Workload Identity Federation.

The module allows a selected GitHub repository to authenticate as a dedicated Google Service Account and publish container images to Artifact Registry without storing long-lived Google Cloud credentials in GitHub.

## Table of Contents

* [Resources](#resources)
* [Authentication Flow](#authentication-flow)
* [Repository Restriction](#repository-restriction)
* [Artifact Registry Access](#artifact-registry-access)
* [Usage](#usage)
* [Validation](#validation)
* [Related Documentation](#related-documentation)

## Resources

This module manages:

* Workload Identity Pool
* GitHub OIDC Workload Identity Provider
* dedicated Google Service Account for CI
* Workload Identity User binding
* Artifact Registry Writer binding

It does not manage:

* GitHub Actions workflows
* application build logic
* vulnerability scanning
* static code analysis
* GitOps image promotion
* Kubernetes workloads

Those concerns are handled by the application CI/CD and GitOps layers.

## Authentication Flow

GitHub Actions authenticates to Google Cloud using OIDC and [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation).

```text
    GitHub Actions
           ↓
   GitHub OIDC token
           ↓
Workload Identity Provider
           ↓
 Workload Identity Pool
           ↓
 Google Service Account
           ↓
   Artifact Registry
```

No Google Service Account JSON key is created.

The resulting credentials are short-lived and generated only when the GitHub Actions workflow runs.

## Repository Restriction

The Workload Identity Provider trusts GitHub's OIDC issuer:

```text
https://token.actions.githubusercontent.com
```

Access is restricted using GitHub token attributes.

The provider validates the repository owner, while Service Account impersonation is restricted to the configured repository.

The effective trust model is:

```text
      GitHub organization/owner
                  ↓
    allowed by provider condition
                  ↓
         specific repository
                  ↓
allowed to impersonate CI Service Account
```

This prevents unrelated GitHub repositories from using the CI identity.

See [Workload Identity Federation with deployment pipelines](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines) for the recommended GitHub OIDC configuration model.

## Artifact Registry Access

The CI Service Account receives:

```text
roles/artifactregistry.writer
```

for the configured Artifact Registry repository.

This allows CI to publish and manage container images without granting project-wide administrative permissions.

Repository access follows the [Artifact Registry access control model](https://cloud.google.com/artifact-registry/docs/access-control).

Expected flow:

```text
      GitHub Actions
            ↓
    CI Service Account
            ↓
roles/artifactregistry.writer
            ↓
online-boutique repository
```

GKE runtime access is managed separately and is not part of this module.

## Usage

The module is instantiated from:

```text
terraform/environments/portfolio/main.tf
```

Example:

```hcl
module "github_actions_wif" {
  source = "../../modules/github-actions-wif"

  project_id = var.project_id

  github_repository_owner = "matmajk"
  github_repository       = "matmajk/<APPLICATION_REPOSITORY>"

  workload_identity_pool_id     = "github-actions"
  workload_identity_provider_id = "github"
  service_account_id            = "github-actions-ci"

  artifact_registry_location      = var.region
  artifact_registry_repository_id = module.artifact_registry.repository_id

  depends_on = [
    module.project_services,
  ]
}
```

Required APIs are enabled through the existing:

```text
module.project_services
```

rather than through standalone `google_project_service` resources.

## Validation

Run the standard infrastructure workflow:

```bash
make gcp-plan
make gcp-show-plan
make gcp-apply
```

Verify the Workload Identity Pool:

```bash
gcloud iam workload-identity-pools list \
  --project=devsecops-portfolio-matmajk \
  --location=global
```

Verify the GitHub provider:

```bash
gcloud iam workload-identity-pools providers list \
  --project=devsecops-portfolio-matmajk \
  --location=global \
  --workload-identity-pool=github-actions
```

Verify the CI Service Account:

```bash
gcloud iam service-accounts describe \
  github-actions-ci@devsecops-portfolio-matmajk.iam.gserviceaccount.com \
  --project=devsecops-portfolio-matmajk
```

Verify Artifact Registry access:

```bash
gcloud artifacts repositories get-iam-policy online-boutique \
  --project=devsecops-portfolio-matmajk \
  --location=europe-central2
```

The repository IAM policy should contain:

```text
roles/artifactregistry.writer
```

for the dedicated CI Service Account.

For the portfolio lifecycle, verify teardown with:

```bash
make gcp-destroy
```

## Related Documentation

### Google Cloud IAM

* [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
* [Workload Identity Federation with deployment pipelines](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
* [Service Account impersonation](https://cloud.google.com/iam/docs/service-account-impersonation)

### Artifact Registry

* [Artifact Registry access control](https://cloud.google.com/artifact-registry/docs/access-control)
* [Artifact Registry IAM roles](https://cloud.google.com/iam/docs/roles-permissions/artifactregistry)

### GitHub

* [OpenID Connect in GitHub Actions](https://docs.github.com/en/actions/concepts/security/openid-connect)
* [Google Cloud authentication action](https://github.com/google-github-actions/auth)

### Terraform

* [google_iam_workload_identity_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool)
* [google_iam_workload_identity_pool_provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider)
* [google_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account)
* [google_artifact_registry_repository_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam)
