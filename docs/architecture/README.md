# Architecture

Architecture documentation for the DevSecOps platform.

This directory is intended for cross-component architecture material that is broader than an individual component README.

## Table of Contents

* [Scope](#scope)
* [Architecture Areas](#architecture-areas)
* [Existing Component Documentation](#existing-component-documentation)
* [Documentation Principles](#documentation-principles)

## Scope

Architecture documentation should describe:

* component relationships
* trust and security boundaries
* infrastructure flows
* deployment flows
* cloud architecture
* significant cross-repository interactions

Implementation-specific usage belongs in the README closest to the component.

## Architecture Areas

Relevant architecture areas include:

* high-level system architecture
* local platform architecture
* GCP network architecture
* CI/CD architecture
* GitOps deployment flow
* security architecture
* observability architecture

## Existing Component Documentation

Current implementation details are documented in:

* [Infrastructure overview](../../README.md)
* [Local Kubernetes architecture](../../local/kind/README.md)
* [Local tooling architecture](../../local/tooling/README.md)
* [Local runner architecture](../../local/runner/README.md)
* [Terraform architecture](../../terraform/README.md)

Cross-component diagrams should be moved into this directory when they become too detailed for the root README.

## Documentation Principles

Architecture documentation should describe the **current architecture** clearly.

Historical implementation steps, temporary debugging procedures and operational command collections should not be mixed into architecture documents.

Important architecture decisions should be captured separately as [ADRs](../adr/README.md).
