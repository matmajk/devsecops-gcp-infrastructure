# Terraform Bootstrap

This directory contains the Terraform configuration required to bootstrap resources used by Terraform itself.

## Purpose

The bootstrap configuration creates the infrastructure required before the main Terraform environment can use remote state.

Initially, this includes:

- Google Cloud Storage bucket for Terraform remote state
- bucket versioning
- appropriate access configuration
- optional lifecycle and protection settings

## Why Bootstrap Is Separate

The main Terraform configuration stores its state remotely in Google Cloud Storage.

However, the GCS bucket must exist before Terraform can use it as a backend.

Therefore, the bootstrap configuration is executed first using local Terraform state:

1. Run Terraform in this directory.
2. Create the GCS state bucket.
3. Configure the `portfolio` environment to use the bucket as its remote backend.
4. Run the main infrastructure Terraform configuration.

## State

The bootstrap configuration initially uses local state.

Its state file must never be committed to Git.

## Usage

Usage instructions will be added when the bootstrap configuration is implemented.
