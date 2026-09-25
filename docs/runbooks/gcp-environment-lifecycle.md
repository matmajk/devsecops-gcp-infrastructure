# GCP Environment Lifecycle

This runbook describes the standard lifecycle of the Google Cloud infrastructure managed by Terraform.

The platform uses separate lifecycle boundaries for persistent infrastructure and the ephemeral GCP runtime environment.

## Table of Contents

* [Lifecycle Model](#lifecycle-model)
* [Prerequisites](#prerequisites)
* [Persistent Foundation](#persistent-foundation)
* [Portfolio Runtime](#portfolio-runtime)
* [Destroy Procedure](#destroy-procedure)
* [Recreate Procedure](#recreate-procedure)
* [Validation](#validation)
* [Decommissioning](#decommissioning)
* [Related Documentation](#related-documentation)

## Lifecycle Model

Terraform infrastructure is divided into three layers:

```text
bootstrap
    │
    ▼
Terraform state backend

foundation
    │
    ├── Artifact Registry
    ├── GitHub Actions WIF
    └── application CI identity

portfolio
    │
    ├── VPC
    ├── Cloud NAT
    ├── GKE
    └── runtime infrastructure
```

The lifecycle rules are:

```text
bootstrap   persistent
foundation  persistent
portfolio   ephemeral
```

A normal runtime destroy must not remove bootstrap or foundation resources.

## Prerequisites

Verify local Google Cloud configuration:

```bash
gcloud auth list
gcloud config get-value project
```

The expected project is:

```text
devsecops-portfolio-matmajk
```

Terraform local configuration must exist for the required root module.

Portfolio:

```text
terraform/environments/portfolio/backend.hcl
terraform/environments/portfolio/terraform.tfvars
```

Foundation:

```text
terraform/foundation/backend.hcl
terraform/foundation/terraform.tfvars
```

These files must not be committed.

## Persistent Foundation

The foundation contains resources that must survive normal runtime destruction.

Validate foundation configuration:

```bash
make gcp-foundation-preflight
```

Initialize the remote backend:

```bash
make gcp-foundation-init
```

Create and review a plan:

```bash
make gcp-foundation-plan
make gcp-foundation-show-plan
```

For a stable foundation, the expected result is:

```text
No changes.
Your infrastructure matches the configuration.
```

Apply intentional foundation changes only after reviewing the saved plan:

```bash
make gcp-foundation-apply
```

Remove an unused saved plan with:

```bash
make gcp-foundation-clean-plan
```

Foundation destruction is not part of the normal development lifecycle.

## Portfolio Runtime

The portfolio environment contains the disposable GCP runtime.

Validate local configuration:

```bash
make gcp-preflight
```

Initialize Terraform:

```bash
make gcp-init
```

Create and review a plan:

```bash
make gcp-plan
make gcp-show-plan
```

Apply the reviewed plan:

```bash
make gcp-apply
```

The normal apply flow is therefore:

```text
gcp-preflight
      │
      ▼
  gcp-init
      │
      ▼
  gcp-plan
      │
      ▼
gcp-show-plan
      │
      ▼
  gcp-apply
```

## Destroy Procedure

Create a destroy plan:

```bash
make gcp-destroy-plan
```

Review it before destroying infrastructure:

```bash
make gcp-show-destroy-plan
```

The destroy plan may contain runtime resources such as:

* GKE cluster
* GKE node pools
* runtime IAM resources
* VPC networking
* Cloud Router
* Cloud NAT
* future stage-specific runtime infrastructure

The destroy plan must not contain:

* Terraform state bucket
* Artifact Registry
* GitHub Actions Workload Identity Pool
* GitHub Actions Workload Identity Provider
* application CI service account
* Artifact Registry writer binding

A quick check can be performed with:

```bash
make gcp-show-destroy-plan \
  | grep -Ei \
    'artifact_registry|workload_identity|github-actions-ci|artifactregistry.writer' \
  || true
```

No foundation resources should appear.

After reviewing the destroy plan:

```bash
make gcp-destroy
```

Remove stale saved plans if required:

```bash
make gcp-clean-plans
```

## Recreate Procedure

After the runtime environment has been destroyed, verify that the persistent foundation is still healthy:

```bash
make gcp-foundation-plan
make gcp-foundation-show-plan
```

The expected result is no changes.

Recreate the portfolio runtime:

```bash
make gcp-preflight
make gcp-init
make gcp-plan
make gcp-show-plan
make gcp-apply
```

The recreated runtime must reuse the existing persistent foundation.

## Validation

After a destroy or recreate operation, validate the lifecycle boundary.

Artifact Registry must still exist:

```bash
gcloud artifacts repositories describe online-boutique \
  --location=europe-central2 \
  --project=devsecops-portfolio-matmajk
```

Published artifacts must remain available:

```bash
gcloud artifacts docker images list \
  europe-central2-docker.pkg.dev/devsecops-portfolio-matmajk/online-boutique/productcatalogservice \
  --include-tags \
  --project=devsecops-portfolio-matmajk
```

The GitHub Actions Workload Identity Pool must still exist:

```bash
gcloud iam workload-identity-pools describe github-actions \
  --location=global \
  --project=devsecops-portfolio-matmajk
```

The GitHub OIDC provider must still exist:

```bash
gcloud iam workload-identity-pools providers describe github \
  --workload-identity-pool=github-actions \
  --location=global \
  --project=devsecops-portfolio-matmajk
```

The application CI service account must still exist:

```bash
gcloud iam service-accounts describe \
  github-actions-ci@devsecops-portfolio-matmajk.iam.gserviceaccount.com \
  --project=devsecops-portfolio-matmajk
```

The expected lifecycle result is:

```text
Portfolio Runtime
      │
      ▼
Destroy
      │
      ├── GKE removed
      ├── runtime networking removed
      └── runtime resources removed

Persistent Foundation
      │
      ├── Artifact Registry retained
      ├── application artifacts retained
      ├── GitHub WIF retained
      └── CI identity retained
```

## Decommissioning

Persistent foundation removal is not a standard lifecycle operation.

There is intentionally no normal Makefile target for:

```text
gcp-foundation-destroy
```

A full platform decommission must be handled explicitly and should include:

1. destroy the portfolio runtime
2. confirm that no runtime dependencies remain
3. back up or remove required artifacts
4. remove foundation resources deliberately
5. remove the Terraform backend only as the final step

The Terraform state bucket must never be removed before all dependent Terraform states have been safely handled.

## Related Documentation

* [Terraform](../../terraform/README.md)
* [Terraform Bootstrap](../../terraform/bootstrap/README.md)
* [Terraform Persistent Foundation](../../terraform/foundation/README.md)
* [Portfolio Environment](../../terraform/environments/portfolio/README.md)
* [Artifact Registry Module](../../terraform/modules/artifact-registry/README.md)
* [GitHub Actions WIF Module](../../terraform/modules/github-actions-wif/README.md)