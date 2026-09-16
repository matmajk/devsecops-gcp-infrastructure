# Terraform Bootstrap

Terraform configuration responsible for creating resources required before the main GCP environment can use remote state.

The bootstrap layer is intentionally separated from the main `portfolio` environment so that the GCP infrastructure can later be destroyed and recreated without removing the Terraform state backend.

## Table of Contents

* [Purpose](#purpose)
* [Why Bootstrap Is Separate](#why-bootstrap-is-separate)
* [Architecture](#architecture)
* [Configuration](#configuration)
* [State](#state)
* [State Protection](#state-protection)
* [Bootstrap Flow](#bootstrap-flow)
* [Local Validation](#local-validation)
* [Lifecycle Model](#lifecycle-model)
* [Security](#security)
* [Cost Impact](#cost-impact)
* [Current Status](#current-status)
* [Related Documentation](#related-documentation)

## Purpose

The bootstrap layer creates the persistent infrastructure required for Terraform remote state.

This includes:

* a Google Cloud Storage state bucket
* bucket versioning
* soft-delete protection
* uniform bucket-level access
* public-access prevention
* Terraform-level deletion protection

The bootstrap layer does not manage the main application platform.

Resources such as networking, GKE, Compute Engine, Cloud SQL and other environment infrastructure belong to the `portfolio` Terraform environment.

## Why Bootstrap Is Separate

The main Terraform environment requires remote state.

The remote-state bucket cannot itself depend on the backend that does not yet exist.

Therefore the bootstrap configuration uses local state first.

This creates two intentionally separate lifecycles:

```text
Terraform Bootstrap
        │
        ▼
Persistent GCS State Bucket
        │
        ▼
Portfolio Environment
        │
        ├── create
        ├── destroy
        └── recreate
```

The state bucket remains available while the `portfolio` environment is destroyed and recreated.

## Architecture

```text
                     GCP Project
                          │
                          ▼
                 Terraform Bootstrap
                          │
                          ▼
                   GCS State Bucket
                          │
                          ▼
                Terraform Remote State
                          │
                          ▼
                 Portfolio Environment
                          │
              ┌───────────┼───────────┐
              │           │           │
              ▼           ▼           ▼
            Network      GKE       Tooling
```

The bootstrap layer owns only the infrastructure required to persist Terraform state.

## Configuration

Bootstrap input values are defined through Terraform variables.

The repository contains:

```text
terraform.tfvars.example
```

with placeholders for values that will only be known after the GCP project is created.

Example:

```hcl
project_id        = "<GCP_PROJECT_ID>"
region            = "europe-central2"
state_bucket_name = "<GLOBALLY_UNIQUE_TF_STATE_BUCKET_NAME>"
```

The real configuration will later be created locally as:

```text
terraform.tfvars
```

and must not be committed to Git.

The state bucket name must be globally unique.

## State

Bootstrap initially uses local Terraform state because the remote backend does not exist yet.

Bootstrap state must never be committed to Git.

Once the bootstrap configuration creates the GCS bucket, the main portfolio environment will use that bucket as its remote backend.

The portfolio backend is declared through partial backend configuration:

```hcl
terraform {
  backend "gcs" {}
}
```

Environment-specific backend values are provided separately through:

```text
backend.hcl
```

based on the committed template:

```text
backend.hcl.example
```

Example:

```hcl
bucket = "<TF_STATE_BUCKET_NAME>"
prefix = "portfolio"
```

The real `backend.hcl` file must not be committed to Git.

## State Protection

The Terraform state bucket uses multiple independent protection mechanisms.

### Object Versioning

Bucket versioning preserves previous versions of Terraform state objects.

This provides recovery capability if the active state is accidentally overwritten or corrupted.

```text
terraform.tfstate v1
terraform.tfstate v2
terraform.tfstate v3
                         ← current
```

### Soft Delete

The bucket defines a soft-delete retention window.

This provides additional protection against accidental object deletion before data is permanently removed.

### Uniform Bucket-Level Access

Uniform bucket-level access is enabled so access is controlled consistently through IAM rather than legacy object ACLs.

### Public Access Prevention

Public access prevention is enforced.

Terraform state may contain sensitive infrastructure information and must never be publicly accessible.

### Destroy Protection

The bucket uses both Terraform and storage-level protections:

```hcl
force_destroy = false
```

and:

```hcl
lifecycle {
  prevent_destroy = true
}
```

These protections ensure the state bucket cannot be removed accidentally during normal infrastructure lifecycle operations.

Deleting the bootstrap infrastructure requires a separate and explicit decommissioning procedure.

## Bootstrap Flow

```text
        Local Bootstrap State
                 │
                 ▼
         Create GCS Bucket
                 │
                 ▼
        Configure GCS Backend
                 │
                 ▼
        Portfolio Environment
                 │
                 ▼
         GCP Infrastructure
```

The bootstrap configuration therefore has a different lifecycle from the main GCP environment.

The portfolio composition is documented in [environments/portfolio/README.md](../environments/portfolio/README.md).

## Local Validation

The bootstrap configuration can be formatted, initialized and validated before a GCP account or project exists.

The repository Makefile provides:

```bash
make terraform-fmt
make terraform-fmt-check
make terraform-init-local
make terraform-validate
```

Local initialization uses:

```bash
terraform init -backend=false
```

so Terraform can install and validate the required provider configuration without attempting to initialize the future GCS backend.

The validation workflow checks both Terraform root modules:

```text
     terraform/bootstrap
              │
              ▼
           validate

terraform/environments/portfolio
              │
              ▼
           validate
```

This stage:

* does not create GCP resources
* does not require GCP credentials
* does not require a billing account
* does not generate cloud costs

## Lifecycle Model

The bootstrap infrastructure is intentionally persistent.

Normal portfolio lifecycle:

```text
GCS State Bucket
       │
       │ remains
       ▼
Portfolio Environment
       │
       ├── apply
       ├── validate
       ├── destroy
       └── recreate
```

A future:

```bash
make gcp-destroy
```

will remove the disposable `portfolio` infrastructure but must not remove the Terraform state bucket.

Expected normal destroy result:

```text
GKE                 removed
Compute Engine      removed
Cloud SQL           removed
Cloud NAT           removed
Load Balancer       removed
Managed disks       removed

Terraform state     retained
```

Complete removal of the project, including the state bucket, will use a separate decommissioning procedure.

That procedure will include:

1. destroying the portfolio environment
2. preserving or exporting the final state where required
3. disabling bootstrap destroy protection
4. removing bucket contents
5. destroying the bootstrap infrastructure

This operation is intentionally separate from normal environment lifecycle commands.

## Security

Bootstrap configuration must avoid committed credentials and state files.

The security model includes:

* no committed GCP credentials
* no committed Terraform state
* no committed real `terraform.tfvars`
* no committed real `backend.hcl`
* enforced public-access prevention
* uniform bucket-level IAM
* bucket versioning
* soft-delete protection
* explicit destroy protection
* least-privilege IAM for future state access

Local GCP authentication will later use Application Default Credentials rather than service-account key files.

CI access will eventually use short-lived federated identity rather than long-lived JSON credentials.

## Cost Impact

Before the bootstrap configuration is applied:

```text
Creation:   $0
Runtime:    $0
Destroyed:  n/a
Residual:   $0
```

After the state bucket is created:

```text
Runtime:    negligible
Residual:   GCS Terraform state bucket
```

The state bucket is expected to store only small Terraform state files and their versions, so its ongoing storage cost should remain minimal.

The bucket is intentionally retained after normal destruction of the `portfolio` environment.

## Current Status

The Terraform bootstrap layer is implemented and can be initialized and validated locally without GCP credentials or backend access.

The current implementation includes:

* GCS state bucket definition
* object versioning
* soft-delete protection
* uniform bucket-level access
* public-access prevention
* explicit destroy protection
* bootstrap input variables
* bootstrap outputs
* local Terraform validation
* partial GCS backend configuration for the `portfolio` environment

No GCP resources have been created yet.

Real bootstrap execution will be performed only after:

* a GCP account is created
* billing is configured
* a GCP project exists
* real project and bucket values are available
* local GCP authentication is configured

Concrete `plan` and `apply` execution steps will be added when the project reaches that stage.

## Related Documentation

For the overall Terraform structure and ownership model, see [Terraform documentation](../README.md).

For the main GCP environment composition root, see [Portfolio Environment](../environments/portfolio/README.md).

For reusable Terraform modules, see [Terraform Modules](../modules/README.md).

For infrastructure architecture documentation, see [Architecture Documentation](../../docs/architecture/README.md).

For operational procedures, see [Runbooks](../../docs/runbooks/README.md).
