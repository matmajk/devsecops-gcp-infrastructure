# DevSecOps GCP Infrastructure

Infrastructure repository for an end-to-end DevSecOps platform built around the Google Online Boutique microservices application.

The repository contains the local platform infrastructure, DevSecOps tooling lifecycle, operational automation and the target Google Cloud infrastructure layer.

The complete platform is validated locally before migration to Google Kubernetes Engine.

## Table of Contents

* [Technology Stack](#technology-stack)
* [Repository Responsibilities](#repository-responsibilities)
* [Repository Structure](#repository-structure)
* [Local Environment](#local-environment)
* [Infrastructure Lifecycle](#infrastructure-lifecycle)
* [Delivery Architecture](#delivery-architecture)
* [Documentation](#documentation)
* [Target GCP Environment](#target-gcp-environment)
* [Security](#security)
* [Current Status](#current-status)

## Technology Stack

### Cloud and Infrastructure

<p align="left">
  <img src="https://img.shields.io/badge/Google%20Cloud-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white" alt="Google Cloud Platform" />
  <img src="https://img.shields.io/badge/Google%20Kubernetes%20Engine-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white" alt="Google Kubernetes Engine" />
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Kubernetes" />
  <img src="https://img.shields.io/badge/Kind-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" alt="Kind" />
  <img src="https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform" />
  <img src="https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white" alt="Ansible" />
</p>

### Containers and Delivery

<p align="left">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Docker%20Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker Compose" />
  <img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions" />
  <img src="https://img.shields.io/badge/Argo%20CD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white" alt="Argo CD" />
  <img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white" alt="Helm" />
</p>

### DevSecOps and Security

<p align="left">
  <img src="https://img.shields.io/badge/JFrog%20Artifactory-40BE46?style=for-the-badge&logo=jfrog&logoColor=white" alt="JFrog Artifactory" />
  <img src="https://img.shields.io/badge/SonarQube-126ED3?style=for-the-badge&logo=sonarqube&logoColor=white" alt="SonarQube" />
  <img src="https://img.shields.io/badge/Trivy-1904DA?style=for-the-badge&logo=trivy&logoColor=white" alt="Trivy" />
</p>

### Observability

<p align="left">
  <img src="https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" alt="Prometheus" />
  <img src="https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white" alt="Grafana" />
  <img src="https://img.shields.io/badge/Grafana%20Loki-F46800?style=for-the-badge&logo=grafana&logoColor=white" alt="Grafana Loki" />
  <img src="https://img.shields.io/badge/Grafana%20Alloy-F46800?style=for-the-badge&logo=grafana&logoColor=white" alt="Grafana Alloy" />
  <img src="https://img.shields.io/badge/OpenTelemetry-000000?style=for-the-badge&logo=opentelemetry&logoColor=white" alt="OpenTelemetry" />
  <img src="https://img.shields.io/badge/Jaeger-66CFE3?style=for-the-badge&logo=jaeger&logoColor=black" alt="Jaeger" />
</p>

## Repository Responsibilities

This repository owns:

* local Kubernetes infrastructure lifecycle
* local SonarQube and JFrog environments
* resource-aware DevSecOps tooling orchestration
* local self-hosted runner integration
* infrastructure automation and maintenance scripts
* operational and architecture documentation
* target GCP Infrastructure as Code
* future host configuration with Ansible

Application source code and CI workflow definitions belong to the application repository.

Kubernetes desired state, Helm configuration, Argo CD Applications and artifact promotion belong to the GitOps repository.

```text
        application
             │
             └── source code + CI
                     │
                     ▼
       infrastructure
             │
             └── infrastructure + tooling
                     │
                     ▼
           gitops
             │
             └── desired state + Argo CD
```

## Repository Structure

```text
.
├── ansible/
│   └── target host and tooling configuration
│
├── docs/
│   ├── adr/
│   ├── architecture/
│   └── runbooks/
│
├── local/
│   ├── kind/
│   ├── runner/
│   └── tooling/
│
├── scripts/
│   └── infrastructure lifecycle automation
│
├── terraform/
│   ├── bootstrap/
│   ├── environments/
│   │   ├── portfolio/
│   └── modules/
│
└── Makefile
```

## Local Environment

The current platform runs locally on a development workstation.

```text
                  Developer Workstation
                          │
           ┌──────────────┼──────────────┐
           │              │              │
           ▼              ▼              ▼
      Ubuntu WSL2    Docker Desktop   Kind Kubernetes
           │              │              │
           │              ├── SonarQube  ├── Online Boutique
           │              └── JFrog      ├── Argo CD
           │                             └── Observability
           │
           └── Self-Hosted GitHub Actions Runner
```

Because the workstation is resource-constrained, Kind, SonarQube and JFrog are normally operated through separate resource profiles rather than remaining active simultaneously.

Detailed documentation:

* [Local Kind environment](local/kind/README.md)
* [Local DevSecOps tooling](local/tooling/README.md)
* [Local GitHub Actions runner](local/runner/README.md)

## Infrastructure Lifecycle

The repository-level `Makefile` is the primary developer and CI interface.

```text
          Developer / CI
                │
                ▼
             Makefile
                │
                ▼
             scripts/
                │
                ▼
     Docker/Compose/Kind
```

Typical commands:

```bash
make bootstrap
make up
make down
make status

make tooling-sonar-up
make tooling-jcr-up
make tooling-down

make docker-clean
```

Implementation details are documented in [scripts/README.md](scripts/README.md).

## Delivery Architecture

The complete local delivery path is validated end to end.

```text
              Application Source
                      │
                      ▼
                GitHub Actions
                      │
                      ▼
          Tests + Security + Quality
                      │
                      ▼
           JFrog Container Registry
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

Infrastructure automation supports this flow by:

* providing the self-hosted execution environment
* managing SonarQube and JFrog lifecycle
* controlling local resource profiles
* managing Kind cluster lifecycle
* configuring Kind access to the local JFrog registry
* restoring Kubernetes access when an existing cluster is started

CI does not directly own Kubernetes desired state.

Deployment state remains Git-driven and is reconciled by Argo CD.

## Documentation

### Architecture Decision Records

Significant technical decisions belong under [docs/adr/](docs/adr/README.md).

### Architecture

Platform architecture documentation belongs under [docs/architecture/](docs/architecture/README.md).

### Runbooks

Operational and recovery procedures belong under [docs/runbooks/](docs/runbooks/README.md).

Component-specific documentation remains close to the implementation:

* [Kind](local/kind/README.md)
* [Runner](local/runner/README.md)
* [Tooling](local/tooling/README.md)
* [Scripts](scripts/README.md)
* [Terraform](terraform/README.md)
* [Ansible](ansible/README.md)

## Target GCP Environment

The local platform provides the functional baseline for the future cloud environment.

```text
                         GCP
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
            GKE                DevSecOps Tooling
             │                         │
     ┌───────┼────────┐         ┌──────┴──────┐
     │       │        │         │             │
     ▼       ▼        ▼         ▼             ▼
 Online   Argo CD  Observ.   SonarQube       JFrog
 Boutique
```

Terraform will provision the cloud infrastructure.

Ansible is reserved for operating-system and host-level configuration where required.

See:

* [Terraform](terraform/README.md)
* [Ansible](ansible/README.md)

## Security

Secrets and credentials must not be committed to Git.

The local model uses:

* GitHub Actions Secrets for CI credentials
* runtime-generated local tooling configuration
* token-based JFrog authentication
* Kubernetes `imagePullSecrets`
* vulnerability scanning before artifact publication
* immutable commit-based image tags
* GitOps-controlled deployment state
* least-privilege principles where supported by the local environment

## Current Status

The local platform currently provides:

* Kind-based Kubernetes
* Online Boutique deployment through GitOps
* Argo CD automated reconciliation
* Prometheus, Grafana, Loki, Alloy, OpenTelemetry and Jaeger
* SonarQube quality analysis
* Trivy filesystem and image scanning
* JFrog artifact publication and retrieval validation
* self-hosted GitHub Actions execution
* automated GitOps artifact promotion
* end-to-end deployment of validated artifacts into Kind

The local architecture is now a working baseline for the next phase: infrastructure and workload hardening followed by GCP migration.
