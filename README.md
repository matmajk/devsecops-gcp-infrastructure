# DevSecOps GCP Infrastructure

Infrastructure repository for an end-to-end DevSecOps platform running on Google Cloud Platform.

The platform hosts the Google Online Boutique microservices application on Google Kubernetes Engine.

## Technology Stack

- Google Cloud Platform
- Terraform
- Ansible
- GKE / Kubernetes
- Docker
- GitHub Actions
- Argo CD
- Helm
- JFrog Artifactory
- SonarQube
- Trivy
- Prometheus
- Grafana
- OpenTelemetry

## Repository Responsibilities

This repository manages cloud infrastructure and host configuration.

Application source code and GitOps configuration are maintained in separate repositories.

## Structure

```text
terraform/   Infrastructure as Code
ansible/     Host and tooling configuration
docs/        Architecture decisions and operational documentation
scripts/     Supporting automation
```

## Environments

The initial implementation provides a cost-optimized ```portfolio``` environment.
Production-grade alternatives and architectural trade-offs are documented separately.

## Security

No credentials, private keys, service-account keys or other secrets should be committed to this repository.
