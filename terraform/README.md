# Terraform

Terraform defines the target Google Cloud infrastructure for the DevSecOps platform.

The current local platform is already validated independently; this directory represents the Infrastructure as Code layer for the future GCP migration.

## Table of Contents

* [Structure](#structure)
* [Responsibilities](#responsibilities)
* [Environment Model](#environment-model)
* [State Model](#state-model)
* [Separation of Responsibilities](#separation-of-responsibilities)
* [Current Status](#current-status)

## Structure

```text
terraform/
├── bootstrap/
│   └── Terraform backend bootstrap
├── environments/
│   └── portfolio/
│       └── environment composition
├── modules/
│   └── reusable GCP components
└── README.md
```

Detailed documentation:

* [Bootstrap](bootstrap/README.md)
* [Portfolio Environment](environments/portfolio/README.md)
* [Modules](modules/README.md)

## Responsibilities

The target Terraform layer covers infrastructure such as:

* VPC networking
* subnets and GKE secondary ranges
* Cloud Router
* Cloud NAT
* IAM and service accounts
* GKE
* Compute Engine tooling infrastructure
* Secret Manager
* DNS
* supporting GCP services

## Environment Model

Reusable infrastructure belongs in `modules/`.

Environment-specific module composition belongs in:

```text
environments/portfolio/
```

This separates reusable infrastructure building blocks from environment inputs and composition.

## State Model

Terraform remote state will use Google Cloud Storage.

The backend infrastructure itself must exist before the main environment can use it.

That dependency is handled by [terraform/bootstrap](bootstrap/README.md).

```text
          bootstrap
              │
              ▼
       GCS State Bucket
              │
              ▼
      portfolio backend
              │
              ▼
      GCP Infrastructure
```

## Separation of Responsibilities

Terraform manages infrastructure lifecycle.

It does not manage:

* application source code
* Kubernetes application desired state
* CI pipelines
* operating-system configuration inside provisioned hosts

Host configuration belongs to [Ansible](../ansible/README.md).

Kubernetes desired state belongs to the GitOps repository.

## Current Status

The local environment is the currently validated platform.

Terraform represents the next infrastructure layer required to reproduce that architecture on GCP.

Implementation should proceed incrementally after the local architecture and delivery model are stable.