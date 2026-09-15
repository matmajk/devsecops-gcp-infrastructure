# Terraform Modules

Reusable Terraform modules for the target DevSecOps GCP platform.

## Table of Contents

* [Planned Modules](#planned-modules)
* [Module Responsibilities](#module-responsibilities)
* [Environment Composition](#environment-composition)
* [Design Principles](#design-principles)

## Planned Modules

The target module set includes:

* `network`
* `nat`
* `iam`
* `gke`
* `compute`
* `secret-manager`
* `dns`

Modules should be implemented incrementally as the corresponding GCP infrastructure is introduced.

## Module Responsibilities

Modules should encapsulate reusable infrastructure resources and expose clear inputs and outputs.

Environment-specific values should not be hardcoded inside reusable modules.

## Environment Composition

Modules are composed by environment configuration under:

```text
terraform/environments/
```

The current target environment is documented in [portfolio/README.md](../environments/portfolio/README.md).

## Design Principles

Terraform modules should:

* have a focused responsibility
* avoid hidden environment assumptions
* expose required outputs explicitly
* use least-privilege IAM
* support reproducible environment creation
* separate reusable logic from environment-specific configuration