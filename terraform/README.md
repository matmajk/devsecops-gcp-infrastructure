# Terraform

Terraform provisions Google Cloud infrastructure for the DevSecOps platform.

## Structure

- `bootstrap/` - bootstraps resources required by Terraform itself, primarily the remote state bucket.
- `modules/` - reusable infrastructure modules.
- `environments/portfolio/` - composition and configuration of the portfolio environment.

## Responsibilities

Terraform manages infrastructure lifecycle including:

- VPC networking
- subnets and secondary GKE ranges
- Cloud Router and Cloud NAT
- IAM and service accounts
- GKE
- Compute Engine tooling VM
- Secret Manager
- DNS
- supporting GCP infrastructure

Application and operating-system configuration is intentionally kept outside Terraform.
