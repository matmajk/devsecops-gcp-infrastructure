# Ansible

Ansible configures the operating system and DevSecOps tooling running on the Compute Engine tooling VM.

## Responsibilities

Ansible manages:

- base operating system configuration
- required packages
- Docker Engine
- SonarQube
- JFrog Artifactory
- GitHub Actions self-hosted runner
- configuration files
- service lifecycle
- host hardening

Infrastructure provisioning is handled by Terraform.

Secrets must not be committed to this repository.
