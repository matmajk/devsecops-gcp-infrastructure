# Terraform Persistent Foundation

This directory defines persistent Google Cloud resources required by the DevSecOps delivery platform.

The foundation has a lifecycle independent from the ephemeral portfolio runtime.

## Table of Contents

* [Purpose](#purpose)
* [Responsibilities](#responsibilities)
* [State Model](#state-model)
* [Lifecycle](#lifecycle)
* [Operations](#operations)
* [Current Status](#current-status)
* [Related Documentation](#related-documentation)

## Purpose

The foundation contains resources that must remain available when the GCP runtime environment is destroyed.

This allows the stage environment to be recreated without rebuilding artifact storage or CI authentication infrastructure.

## Responsibilities

The foundation currently manages:

* Google Artifact Registry
* GitHub Actions Workload Identity Pool
* GitHub OIDC provider
* application CI service account
* Workload Identity Federation binding
* Artifact Registry writer binding

Reusable implementations are defined under:

```text
terraform/modules/
```

## State Model

The foundation uses the same GCS Terraform backend as the portfolio environment but a separate state prefix.

```text
GCS State Bucket
├── foundation
└── portfolio
```

Foundation:

```text
prefix = "foundation"
```

Portfolio runtime:

```text
prefix = "portfolio"
```

This prevents persistent delivery resources from being coupled to the runtime lifecycle.

## Lifecycle

The foundation is persistent.

A normal:

```bash
make gcp-destroy
```

destroys only resources managed by:

```text
terraform/environments/portfolio/
```

It must not remove:

* Artifact Registry
* application artifacts
* GitHub Actions WIF
* CI service account
* Artifact Registry publication permissions

Foundation destruction is intentionally not exposed as a standard Makefile operation.

## Operations

Validate local configuration:

```bash
make gcp-foundation-preflight
```

Initialize the backend:

```bash
make gcp-foundation-init
```

Create and review a plan:

```bash
make gcp-foundation-plan
make gcp-foundation-show-plan
```

Apply the saved plan:

```bash
make gcp-foundation-apply
```

Remove a saved plan:

```bash
make gcp-foundation-clean-plan
```

Local configuration is created from:

```text
backend.hcl.example
terraform.tfvars.example
```

Real `backend.hcl` and `terraform.tfvars` files must not be committed.

## Current Status

The persistent foundation is implemented and owns the existing Artifact Registry and GitHub Actions WIF resources.

The foundation state is separated from the ephemeral portfolio runtime so that stage infrastructure can be destroyed and recreated without removing artifacts or CI federation.

## Related Documentation

* [Terraform](../README.md)
* [Terraform Bootstrap](../bootstrap/README.md)
* [Portfolio Environment](../environments/portfolio/README.md)
* [Artifact Registry Module](../modules/artifact-registry/README.md)
* [GitHub Actions WIF Module](../modules/github-actions-wif/README.md)
* [GCP Environment Lifecycle Runbook](../../docs/runbooks/gcp-environment-lifecycle.md)