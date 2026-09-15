# Local DevSecOps Tooling

Local DevSecOps services used outside the Kind cluster by the development and CI environments.

The tooling stack is managed with Docker Compose and currently provides SonarQube and JFrog Container Registry backed by PostgreSQL.

## Table of Contents

* [Architecture](#architecture)
* [Design Goals](#design-goals)
* [Lifecycle](#lifecycle)
* [Resource Profiles](#resource-profiles)
* [Environment Configuration](#environment-configuration)
* [SonarQube](#sonarqube)
* [JFrog Container Registry](#jfrog-container-registry)
* [CI/CD Integration](#cicd-integration)
* [Security](#security)
* [Persistence](#persistence)
* [Quick Validation](#quick-validation)
* [Future GCP Model](#future-gcp-model)

## Architecture

```text
                  Developer Workstation
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
       Kind Kubernetes            Local Tooling
             │                         │
      Online Boutique          ┌───────┴───────┐
         Argo CD               │               │
      Observability            ▼               ▼
                           SonarQube          JFrog
                               │               │
                               ▼               ▼
                           PostgreSQL      PostgreSQL
```

Tooling remains outside Kind to reduce Kubernetes resource pressure and provide a model that can later map to dedicated cloud infrastructure.

## Design Goals

The local tooling environment provides:

* reproducible local DevSecOps services
* persistent application data
* explicit lifecycle control
* resource-aware execution
* CI integration
* separation from Kubernetes workloads
* a migration path toward dedicated GCP infrastructure

It is not intended to reproduce a production high-availability deployment.

## Lifecycle

The repository `Makefile` is the recommended interface.

Implementation details are documented in [scripts/README.md](../../scripts/README.md).

General:

```bash
make tooling-status
make tooling-down
```

SonarQube:

```bash
make tooling-sonar-up
make tooling-sonar-down
make tooling-sonar-status
make tooling-sonar-wait
make tooling-sonar-logs
```

JFrog:

```bash
make tooling-jcr-up
make tooling-jcr-down
make tooling-jcr-status
make tooling-jcr-wait
make tooling-jcr-logs
```

Lifecycle commands perform application-level readiness validation rather than relying only on Docker container state.

## Resource Profiles

The workstation does not normally run Kind, SonarQube and JFrog simultaneously.

### Kubernetes

```text
Kind        ON
SonarQube   OFF
JFrog       OFF
```

### SonarQube

```text
Kind        OFF
SonarQube   ON
JFrog       OFF
```

### JFrog

```text
Kind        OFF
SonarQube   OFF
JFrog       ON
```

The lifecycle scripts reject conflicting profiles unless concurrent execution is explicitly enabled for integration testing.

Example:

```bash
make tooling-jcr-up TOOLING_ALLOW_CONCURRENT=1
```

This override should not be used for normal local development.

## Environment Configuration

Local configuration is loaded from:

```text
local/tooling/.env
```

Create it from:

```bash
cp local/tooling/.env.example local/tooling/.env
```

The real `.env` file must not be committed.

It contains local database and version configuration required by SonarQube and JFrog.

Credentials stored in persistent PostgreSQL volumes must remain consistent with the corresponding runtime configuration and CI secrets.

## SonarQube

SonarQube provides static analysis and Quality Gate validation.

```text
          SonarQube
              │
              ▼
          PostgreSQL
```

Start:

```bash
make tooling-sonar-up
```

Status:

```bash
make tooling-sonar-status
```

Logs:

```bash
make tooling-sonar-logs
```

Stop:

```bash
make tooling-sonar-down
```

The lifecycle command preserves named Docker volumes.

SonarQube is used by the application CI pipeline after application and container security validation.

CI must pass the configured Quality Gate before artifact publication can proceed.

## JFrog Container Registry

JFrog provides the local Docker/OCI artifact registry.

```text
             CI Pipeline
                  │
                  ▼
                JFrog
                  │
                  ▼
             PostgreSQL
                  │
                  ▼
       online-boutique-docker-local
```

Start:

```bash
make tooling-jcr-up
```

Status:

```bash
make tooling-jcr-status
```

Logs:

```bash
make tooling-jcr-logs
```

Stop:

```bash
make tooling-jcr-down
```

Published application artifacts use immutable CI tags based on their source commit.

Example:

```text
<registry>/online-boutique-docker-local/productcatalogservice:ci-<git-sha>
```

The CI workflow verifies publication by pulling the artifact back from JFrog.

The same validated artifact is then selected by GitOps promotion rather than rebuilt.

The local registry currently uses HTTP connectivity and is therefore development-only infrastructure.

## CI/CD Integration

The tooling stack participates in the full validated local CI/CD flow.

```text
                 Source Code
                     │
                     ▼
             Unit Tests / Build
                     │
                     ▼
          Trivy Filesystem Scan
                     │
                     ▼
              Container Build
                     │
                     ▼
            Trivy Image Scan
                     │
                     ▼
              SonarQube
                     │
                     ▼
               Quality Gate
                     │
                     ▼
                  JFrog
                     │
                     ▼
           Publication Verification
                     │
                     ▼
             GitOps Promotion
                     │
                     ▼
                  Argo CD
                     │
                     ▼
             Kind Kubernetes
```

The application CI builds an image once.

The validated image is:

1. scanned
2. published to JFrog
3. pulled back for verification
4. promoted through GitOps
5. reconciled into Kubernetes by Argo CD

The infrastructure repository owns the local services and lifecycle automation required by these stages, not the application workflow or Kubernetes desired state.

## Security

Local tooling follows these principles:

* credentials are not committed to Git
* CI credentials use GitHub Actions Secrets
* JFrog authentication uses tokens
* container images are scanned before publication
* artifact versions are immutable
* the image published to JFrog is the same image that passed scanning
* generated CI `.env` files are removed during cleanup
* self-hosted runner execution is limited to trusted workflows

A dedicated least-privilege JFrog CI identity remains an appropriate hardening improvement for the cloud environment.

## Persistence

Named Docker volumes preserve:

* SonarQube configuration and history
* SonarQube PostgreSQL state
* JFrog configuration
* JFrog PostgreSQL state
* repository metadata
* stored artifacts

Normal `down` operations must not remove these volumes.

Avoid destructive `docker compose down -v` operations unless data deletion is intentional.

## Quick Validation

SonarQube:

```bash
curl -fsS http://localhost:9000/api/system/status
```

JFrog Router:

```bash
curl -fsS http://localhost:8082/router/api/v1/system/readiness
```

Artifactory:

```bash
curl -fsS http://localhost:8082/artifactory/api/system/ping
```

For detailed failure recovery procedures, use [docs/runbooks](../../docs/runbooks/README.md).

## Future GCP Model

The local Docker Compose tooling layer provides a functional baseline for the future cloud tooling environment.

```text
                    GCP
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
         GKE              Tooling Infrastructure
          │                     │
          │               ┌─────┴─────┐
          │               │           │
          ▼               ▼           ▼
   Applications       SonarQube     JFrog
```

Terraform will own infrastructure provisioning.

Ansible can own host-level and tooling configuration where required.

See:

* [Terraform](../../terraform/README.md)
* [Ansible](../../ansible/README.md)
