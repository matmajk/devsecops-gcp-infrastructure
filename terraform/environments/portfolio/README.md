# Portfolio Terraform Environment

Terraform composition root for the portfolio GCP environment.

This environment will assemble reusable Terraform modules into the cloud infrastructure required by the DevSecOps platform.

## Table of Contents

* [Purpose](#purpose)
* [Architecture](#architecture)
* [Responsibilities](#responsibilities)
* [State](#state)
* [Configuration Model](#configuration-model)
* [Network Foundation](#network-foundation)
* [Workflow](#workflow)
* [Current Status](#current-status)

## Purpose

The `portfolio` environment represents the environment-specific composition layer for the target GCP platform.

Reusable resources are implemented as Terraform modules, while this directory provides environment-specific composition and inputs.

## Architecture

```text
              portfolio
                  │
                  ▼
          Terraform Modules
                  │
       ┌──────────┼──────────┐
       │          │          │
       ▼          ▼          ▼
    Network      GKE       Tooling
                            Infra
                  │
                  ▼
                 GCP
```

The exact resource composition will evolve as GCP infrastructure is implemented.

## Responsibilities

This environment is expected to define:

* module composition
* environment-specific variables
* provider configuration
* backend configuration
* references between infrastructure components
* environment-specific outputs

Reusable resource implementation belongs under [terraform/modules](../../modules/README.md).

## State

The portfolio environment is intended to use remote Terraform state stored in Google Cloud Storage.

The state backend is created separately through [terraform/bootstrap](../../bootstrap/README.md).

## Configuration Model

```text
        reusable modules
               │
               ▼
     portfolio composition
               │
               ▼
    environment variables
               │
               ▼
          GCP resources
```

Environment-specific values should remain outside reusable module implementations.

## Network Foundation

The portfolio environment consumes the reusable [network module](../../modules/network/README.md).

The default address plan is:

| Purpose | CIDR |
|---|---|
| Nodes | `10.10.0.0/20` |
| Pods | `10.20.0.0/16` |
| Services | `10.30.0.0/20` |

The network uses a custom VPC, explicit GKE secondary ranges and Private Google Access.

Cloud NAT will be introduced together with private GKE.

## Workflow

The intended provisioning sequence is:

```text
       Bootstrap Backend
              │
              ▼
     Initialize Portfolio
              │
              ▼
          Plan Changes
              │
              ▼
         Review Plan
              │
              ▼
          Apply Changes
```

Concrete commands and variable requirements should be added as the environment implementation is introduced.

## Current Status

The project currently uses the validated local environment.

The `portfolio` Terraform environment represents the composition root for the future GCP migration rather than an already deployed cloud environment.

See [Terraform overview](../../README.md).