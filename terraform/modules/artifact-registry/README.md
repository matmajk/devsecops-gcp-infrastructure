# Artifact Registry

Terraform module provisioning the Google Cloud Artifact Registry Docker repository used by the portfolio platform.

The repository stores container images produced by CI and later deployed to GKE through the GitOps workflow.

## Table of Contents

* [Resources](#resources)
* [Repository](#repository)
* [Cleanup Policy](#cleanup-policy)
* [Access](#access)
* [Usage](#usage)
* [Validation](#validation)
* [Related Documentation](#related-documentation)

## Resources

This module manages:

* one regional Artifact Registry repository
* Docker repository format
* repository cleanup policies
* repository metadata
* outputs required by other infrastructure components

It does not manage:

* CI authentication
* Workload Identity Federation
* IAM bindings for CI
* GKE image pull permissions
* image builds or pushes
* GitOps promotion

Those concerns are handled by their respective infrastructure and CI/CD components.

## Repository

The portfolio environment uses:

```text
Project:     devsecops-portfolio-matmajk
Region:      europe-central2
Repository:  online-boutique
Format:      Docker
Mode:        Standard
```

Repository URL:

```text
europe-central2-docker.pkg.dev/devsecops-portfolio-matmajk/online-boutique
```

Images follow the standard [Artifact Registry Docker naming format](https://cloud.google.com/artifact-registry/docs/docker/names):

```text
<region>-docker.pkg.dev/<project>/<repository>/<image>:<tag>
```

Example:

```text
europe-central2-docker.pkg.dev/devsecops-portfolio-matmajk/online-boutique/productcatalogservice:<tag>
```

Artifact Registry replaces the previously considered self-hosted container registry so that registry infrastructure does not consume GKE CPU, memory, storage, or database resources.

## Cleanup Policy

The repository uses [Artifact Registry cleanup policies](https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy) to limit storage growth caused by CI-generated image versions.

Configured policies:

```text
DELETE
├── images older than 30 days
└── regardless of tag state

KEEP
└── 10 most recent versions
```

The `KEEP` rule protects recent versions even if they also satisfy the age-based deletion condition.

Cleanup is performed asynchronously by Artifact Registry.

## Access

IAM is intentionally not managed by this module.

Future access will follow the least-privilege model described in [Artifact Registry access control](https://cloud.google.com/artifact-registry/docs/access-control):

```text
CI
→ roles/artifactregistry.writer

GKE
→ roles/artifactregistry.reader
```

CI authentication will be implemented separately using Workload Identity Federation rather than long-lived Google Service Account keys.

GKE permissions will also be configured separately after verifying the identity used by the existing node pool.

## Usage

The module is instantiated from:

```text
terraform/environments/portfolio/main.tf
```

Example:

```hcl
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = "online-boutique"

  depends_on = [
    module.project_services,
  ]
}
```

The Artifact Registry API is enabled through the existing:

```text
module.project_services
```

using:

```text
artifactregistry.googleapis.com
```

## Validation

Run the standard infrastructure workflow:

```bash
make gcp-plan
make gcp-show-plan
make gcp-apply
```

Verify the repository:

```bash
gcloud artifacts repositories describe online-boutique \
  --project=devsecops-portfolio-matmajk \
  --location=europe-central2
```

Expected configuration:

```text
format: DOCKER
mode: STANDARD_REPOSITORY
location: europe-central2
```

List repositories:

```bash
gcloud artifacts repositories list \
  --project=devsecops-portfolio-matmajk \
  --location=europe-central2
```

The Terraform plan should include:

```text
module.artifact_registry.google_artifact_registry_repository.this
```

For the portfolio apply-test-destroy lifecycle, verify teardown with:

```bash
make gcp-destroy
```

and confirm that the repository is no longer present.

## Related Documentation

### Google Cloud

* [Artifact Registry](https://cloud.google.com/artifact-registry/docs)
* [Artifact Registry repositories](https://cloud.google.com/artifact-registry/docs/repositories)
* [Docker image naming](https://cloud.google.com/artifact-registry/docs/docker/names)
* [Cleanup policies](https://cloud.google.com/artifact-registry/docs/repositories/cleanup-policy)
* [Access control](https://cloud.google.com/artifact-registry/docs/access-control)
* [Integrate Artifact Registry with GKE](https://cloud.google.com/artifact-registry/docs/integrate-gke)

### Terraform

* [google_artifact_registry_repository](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository)
