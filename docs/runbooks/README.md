# Runbooks

Operational procedures and troubleshooting guides for the DevSecOps platform.

## Table of Contents

* [Purpose](#purpose)
* [Runbook Scope](#runbook-scope)
* [Current Operational Documentation](#current-operational-documentation)
* [Candidate Runbooks](#candidate-runbooks)
* [Runbook Principles](#runbook-principles)

## Purpose

Runbooks provide repeatable procedures for diagnosing and recovering from operational failures.

They should contain procedural material that would make component README files unnecessarily large.

## Runbook Scope

Typical runbooks cover:

* symptom identification
* diagnostics
* recovery steps
* validation after recovery
* destructive-operation warnings
* escalation or fallback paths

## Current Operational Documentation

Some operational procedures currently remain close to their components:

* [Kind](../../local/kind/README.md)
* [Local tooling](../../local/tooling/README.md)
* [Self-hosted runner](../../local/runner/README.md)
* [Infrastructure scripts](../../scripts/README.md)

Detailed troubleshooting can be extracted from those documents into dedicated runbooks as the platform grows.

## Candidate Runbooks

Useful future runbooks include:

* Kind cluster access and kubeconfig recovery
* failed Kubernetes deployment investigation
* `ImagePullBackOff` investigation
* JFrog registry connectivity
* SonarQube recovery
* self-hosted runner recovery
* Docker storage cleanup and recovery
* Terraform state recovery
* GKE access troubleshooting
* tooling VM recovery

Cloud-specific runbooks should be added only when the corresponding GCP components exist.

## Runbook Principles

A runbook should be:

* focused on one operational scenario
* reproducible
* safe by default
* explicit about destructive operations
* validated against the current platform
* updated when the underlying automation changes

Architecture explanations belong in [docs/architecture](../architecture/README.md), not in runbooks.