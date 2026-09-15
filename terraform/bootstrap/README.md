# Terraform Bootstrap

Terraform configuration responsible for creating resources required before the main GCP environment can use remote state.

## Table of Contents

* [Purpose](#purpose)
* [Why Bootstrap Is Separate](#why-bootstrap-is-separate)
* [State](#state)
* [Bootstrap Flow](#bootstrap-flow)
* [Security](#security)
* [Current Status](#current-status)

## Purpose

The bootstrap layer is intended to create the Terraform remote-state infrastructure.

This includes:

* a Google Cloud Storage state bucket
* bucket versioning
* access configuration
* lifecycle or deletion protection where appropriate

## Why Bootstrap Is Separate

The main Terraform environment requires remote state.

The remote-state bucket cannot itself depend on the backend that does not yet exist.

Therefore bootstrap uses local state first.

## State

Bootstrap state must never be committed to Git.

The main portfolio environment will use the created GCS bucket as its backend.

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

The portfolio composition is documented in [environments/portfolio/README.md](../environments/portfolio/README.md).

## Security

Bootstrap configuration must avoid committed credentials and state files.

Access to the state bucket should follow least-privilege IAM principles.

## Current Status

This directory represents the bootstrap layer of the target GCP architecture.

Concrete execution commands should be documented once the bootstrap implementation is introduced rather than documenting commands that do not yet exist.