# GCP Environment Lifecycle

This runbook describes the standard lifecycle for the disposable GCP `portfolio` environment.

The primary goals are predictable infrastructure changes, cost control and complete environment destruction.

## Table of Contents

* [Prerequisites](#prerequisites)
* [Lifecycle Model](#lifecycle-model)
* [Preflight](#preflight)
* [Plan](#plan)
* [Apply](#apply)
* [Destroy](#destroy)
* [Destroy Preview](#destroy-preview)
* [Cost Model](#cost-model)
* [Expected Residual Infrastructure](#expected-residual-infrastructure)

## Prerequisites

Real GCP lifecycle operations require:

* an existing GCP project
* configured billing
* Application Default Credentials
* an existing Terraform state bucket
* `terraform.tfvars`
* `backend.hcl`

These files must not be committed to Git.

## Lifecycle Model

```text
        Plan
          │
          ▼
        Review
          │
          ▼
        Apply
          │
          ▼
       Validate
          │
          ▼
       Destroy
          │
          ▼
    Verify cleanup
          │
          ▼
Recreate when required
```

Infrastructure destruction and recreation are treated as normal parts of the portfolio environment lifecycle.

## Preflight

Verify that local environment configuration exists:

```bash
make gcp-preflight
```

## Plan

Create a saved Terraform plan:

```bash
make gcp-plan
```

Review it:

```bash
make gcp-show-plan
```

Do not apply infrastructure changes without reviewing the plan.

## Apply

Apply exactly the previously generated plan:

```bash
make gcp-apply
```

A successful apply removes the saved plan file to prevent accidental reuse.

## Destroy

The complete portfolio environment can be destroyed with:

```bash
make gcp-destroy
```

Terraform displays the destroy plan and requires explicit confirmation before deleting resources.

The bootstrap state bucket is managed by a separate Terraform root module and is intentionally retained.

## Destroy Preview

To inspect destruction without changing infrastructure:

```bash
make gcp-destroy-plan
make gcp-show-destroy-plan
```

This is recommended whenever the environment contains important stateful resources.

## Cost Model

Every infrastructure change should document:

```text
Creation:
Runtime:
Destroyed:
Residual:
```

Paid resources should only remain active while they are required for development, validation or demonstration.

The complete portfolio environment is designed to be disposable.

## Expected Residual Infrastructure

After a successful full portfolio destroy, billable runtime infrastructure should be removed.

Expected deleted resources will eventually include:

```text
GKE
GKE node pools
Compute Engine tooling VMs
Cloud SQL
Cloud NAT
load balancers
managed environment disks
environment IP addresses
```

The expected persistent resource is:

```text
Terraform GCS state bucket
```

The state bucket has a separate bootstrap lifecycle and is intentionally excluded from normal portfolio destruction.
