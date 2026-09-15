# Local GitHub Actions Runner

Documentation for the temporary self-hosted GitHub Actions runner used by the local DevSecOps environment.

The runner executes inside WSL and connects GitHub Actions with local Docker, SonarQube, JFrog and Kind infrastructure.

## Table of Contents

* [Architecture](#architecture)
* [Purpose](#purpose)
* [Runner Scope](#runner-scope)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Execution](#execution)
* [CI/CD Role](#cicd-role)
* [Security](#security)
* [Resource Model](#resource-model)
* [Validation](#validation)
* [Removal](#removal)

## Architecture

```text
                    GitHub
                      │
                      ▼
                 GitHub Actions
                      │
                      ▼
             Self-Hosted Runner
                  WSL/Linux
                      │
       ┌──────────────┼──────────────┐
       │              │              │
       ▼              ▼              ▼
     Docker       Local Tooling     Kind
       │              │              │
       │        ┌─────┴─────┐        └── kubectl/Argo CD
       │        │           │
       │        ▼           ▼
       │    SonarQube     JFrog
       │
       └── Trivy
```

## Purpose

The runner provides GitHub Actions with controlled access to services hosted on the local development workstation.

It is a temporary local integration mechanism rather than the final cloud CI execution model.

## Runner Scope

Runner name:

```text
devsecops-local-wsl
```

Custom label:

```text
devsecops-local
```

Workflows can target it with:

```yaml
runs-on:
  - self-hosted
  - linux
  - x64
  - devsecops-local
```

## Prerequisites

The runner environment requires:

* Git
* Bash
* Make
* curl
* Docker CLI
* Docker Compose
* Trivy
* kubectl
* Kind
* connectivity to SonarQube
* connectivity to JFrog

Infrastructure lifecycle automation is provided by this repository.

See:

* [Local tooling](../tooling/README.md)
* [Infrastructure scripts](../../scripts/README.md)

## Installation

Runner binaries and registration state must remain outside the Git repository.

Recommended location:

```text
~/github-actions-runners/application/
```

The runner is registered through GitHub repository settings.

Registration tokens are temporary credentials and must never be committed to Git.

## Execution

Interactive execution:

```bash
cd ~/github-actions-runners/application
./run.sh
```

Service execution:

```bash
sudo ./svc.sh install "$USER"
sudo ./svc.sh start
sudo ./svc.sh status
```

Stop:

```bash
sudo ./svc.sh stop
```

## CI/CD Role

The runner participates in the complete validated local delivery path.

```text
                 Source Code
                     │
                     ▼
            Application Validation
                     │
                     ▼
             Trivy Security Gates
                     │
                     ▼
              SonarQube Quality
                     │
                     ▼
              Container Build
                     │
                     ▼
                  JFrog
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

The runner executes resource-aware lifecycle operations through the infrastructure `Makefile`.

The application and infrastructure repositories are checked out separately so infrastructure lifecycle operations remain isolated from application source.

## Security

A self-hosted runner executes workflow code directly on the development workstation.

Therefore:

* only trusted workflows should execute on this runner
* arbitrary untrusted fork pull requests must not be allowed to execute privileged local automation
* registration tokens must not be stored in Git
* service credentials must come from GitHub Actions Secrets
* generated local configuration must be removed during cleanup
* concurrent workflows must not manipulate shared local infrastructure simultaneously

## Resource Model

The runner itself is lightweight.

SonarQube, JFrog and Kind are the resource-intensive components.

The CI flow therefore switches between local resource profiles rather than keeping all services active simultaneously.

```text
        SonarQube Stage
               │
               ▼
        SonarQube ON
          Kind OFF
          JFrog OFF
               │
               ▼
          JFrog Stage
               │
               ▼
          JFrog ON
          Kind OFF
       SonarQube OFF
               │
               ▼
       Deployment Stage
               │
               ▼
           Kind ON
```

See [Local DevSecOps Tooling](../tooling/README.md).

## Validation

Verify the runner environment:

```bash
git --version
make --version
docker version
docker compose version
kubectl version --client
kind version
trivy --version
```

Verify local infrastructure connectivity through the corresponding tooling and Kind validation procedures.

## Removal

The runner is temporary infrastructure.

When the local validation phase is no longer required:

1. deregister the runner from GitHub
2. stop the local runner service
3. remove the local installation directory

Do not delete the runner directory before deregistration.
