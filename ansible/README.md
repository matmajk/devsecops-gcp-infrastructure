# Ansible

Ansible is reserved for host and tooling configuration in the target GCP environment.

Terraform owns infrastructure provisioning; Ansible will manage configuration inside provisioned hosts where configuration management is required.

## Table of Contents

* [Responsibilities](#responsibilities)
* [Separation from Terraform](#separation-from-terraform)
* [Security](#security)
* [Current Status](#current-status)

## Responsibilities

The target Ansible layer can manage:

* base operating-system configuration
* required packages
* Docker Engine
* SonarQube
* JFrog Artifactory
* CI runner configuration where required
* configuration files
* service lifecycle
* host hardening

## Separation from Terraform

```text
             Terraform
                 │
                 ▼
       Infrastructure Provisioning
                 │
                 ▼
              Ansible
                 │
                 ▼
        Host Configuration
```

Terraform should create infrastructure resources.

Ansible should configure software and operating-system state inside provisioned hosts.

See [Terraform](../terraform/README.md).

## Security

Secrets must not be committed to this repository.

Cloud credentials and service secrets should be supplied through dedicated secret-management mechanisms rather than static Ansible variables committed to Git.

## Current Status

The current validated platform uses local Docker Compose tooling.

The Ansible layer belongs to the future GCP migration phase and should be implemented once the target Compute Engine/tooling-host architecture is introduced.