# Local GitHub Actions Runner

This directory documents the temporary local self-hosted GitHub Actions runner used to validate the complete DevSecOps workflow before migrating the platform to GCP.

The runner itself is not installed inside the infrastructure repository.

It runs in the local WSL Linux environment and connects GitHub Actions with services running on the development workstation.

## Architecture

```text
GitHub
   ↓
GitHub Actions
   ↓
Self-Hosted Runner
WSL/Linux
   |
   +--> Docker Desktop
   |
   +--> SonarQube
   |
   +--> Trivy
   |
   +--> JFrog Container Registry
   |
   +--> Kind
   |
   +--> kubectl / Argo CD
```

The local runner provides the execution environment required to validate the complete CI/CD workflow against locally hosted DevSecOps services.

## Purpose

The local self-hosted runner is intended to provide a temporary bridge between GitHub Actions and the local development environment.

It allows the CI pipeline to access:

```text
Docker Engine
SonarQube
JFrog Container Registry
Kind Kubernetes cluster
kubectl
local infrastructure lifecycle automation
```

This makes it possible to perform a complete local end-to-end DevSecOps validation before moving the platform to GCP.

The runner is not intended to be the final CI execution model.

The future cloud environment is expected to use GitHub-hosted runners together with services accessible from GCP.

## Installation Location

The runner application is installed outside the Git repository.

Recommended location:

```text
~/github-actions-runners/application/
```

Example structure:

```text
~/github-actions-runners/
└── application/
    ├── config.sh
    ├── run.sh
    ├── svc.sh
    ├── bin/
    ├── externals/
    └── _work/
```

Runner binaries, registration state and work directories must not be committed to the infrastructure repository.

## Runner Scope

The initial runner is registered at repository level for the application repository.

Runner name:

```text
devsecops-local-wsl
```

Custom runner label:

```text
devsecops-local
```

GitHub also provides the standard runner labels:

```text
self-hosted
linux
x64
```

Workflows can therefore target the runner with:

```yaml
runs-on:
  - self-hosted
  - linux
  - x64
  - devsecops-local
```

## Prerequisites

The WSL Linux environment used by the runner must provide access to:

```text
Git
Bash
Make
curl
Docker CLI
Docker Compose
```

Future CI stages will additionally require:

```text
Trivy
kubectl
Kind
SonarQube connectivity
JFrog connectivity
```

Docker connectivity should be validated before registering the runner:

```bash
docker version
docker compose version
docker ps
```

Both the Docker client and Docker server must be reachable.

## Local Tooling Connectivity

The runner executes jobs inside WSL.

Before integrating a local DevSecOps service into CI, connectivity from the same WSL environment should be verified.

SonarQube:

```bash
curl -fsS \
  http://localhost:9000/api/system/status
```

JFrog Router:

```bash
curl -fsS \
  http://localhost:8082/router/api/v1/system/readiness
```

Artifactory:

```bash
curl -fsS \
  http://localhost:8082/artifactory/api/system/ping
```

If services exposed by Docker Desktop are not available through `localhost` from WSL, the Windows host address should be used instead.

## Registration

The runner is registered through the application repository:

```text
Repository
→ Settings
→ Actions
→ Runners
→ New self-hosted runner
```

The runner platform is:

```text
Linux
x64
```

GitHub provides the current runner download, checksum verification and registration commands.

The registration token is temporary and must never be stored in Git.

## Manual Execution

For initial validation, the runner can be started interactively:

```bash
cd ~/github-actions-runners/application

./run.sh
```

A ready runner reports that it is connected to GitHub and listening for jobs.

This mode is useful during initial CI development because runner logs remain directly visible in the terminal.

## Service Execution

After runner validation, it can be configured as a Linux system service.

From the runner installation directory:

```bash
sudo ./svc.sh install "$USER"
sudo ./svc.sh start
sudo ./svc.sh status
```

Stop the service:

```bash
sudo ./svc.sh stop
```

Start it again:

```bash
sudo ./svc.sh start
```

The runner becomes unavailable to GitHub Actions when the WSL environment or the runner service is stopped.

## Security Model

The local self-hosted runner executes GitHub Actions workflow code directly on the development workstation.

For this reason, it must only execute trusted workflows and trusted source code.

The local runner should not execute arbitrary pull requests from untrusted forks.

The initial local CI workflows use manual execution or explicitly controlled development branches.

The runner should be removed after local end-to-end validation is complete.

## Resource Model

The runner application itself is lightweight.

The resource-intensive components are the workloads started by the CI pipeline.

The local CI workflow should therefore use the existing resource-aware lifecycle automation to run heavy services sequentially.

Target model:

```text
Start SonarQube
      ↓
Run code analysis
      ↓
Stop SonarQube
      ↓
Build container
      ↓
Run Trivy image scan
      ↓
Start JFrog
      ↓
Push image
      ↓
Stop JFrog
      ↓
Start Kind
      ↓
Validate deployment
```

This prevents SonarQube, JFrog and the complete Kubernetes environment from consuming workstation resources simultaneously.

## Initial Validation

The first runner workflow validates only the execution environment.

The initial smoke test checks:

```text
GitHub Actions job routing
runner identity
Git availability
Make availability
curl availability
Docker CLI availability
Docker Compose availability
Docker daemon connectivity
```

SonarQube, JFrog, Trivy and Kubernetes orchestration are added in later CI stages.

## Local CI Lifecycle

The local runner is intended for the local validation phase:

```text
Local development
      ↓
Self-hosted GitHub Actions runner
      ↓
Complete local CI/CD validation
      ↓
GCP migration
      ↓
GitHub-hosted CI
```

The self-hosted runner is therefore an integration tool rather than permanent production infrastructure.

## Removal

After completing the local end-to-end validation, the runner should be removed from GitHub and from the workstation.

The runner registration should first be removed from the repository settings or using the removal command generated by GitHub.

After successful deregistration, the local installation directory can be removed.

Example:

```bash
rm -rf ~/github-actions-runners/application
```

Do not remove the runner directory before deregistering the runner from GitHub.

## Next Steps

After the runner smoke test is validated, the CI pipeline will be extended incrementally.

The planned local CI sequence is:

```text
Unit tests
   ↓
SonarQube analysis
   ↓
Trivy filesystem scan
   ↓
Docker build
   ↓
Trivy image scan
   ↓
JFrog publication
   ↓
GitOps update
   ↓
Argo CD deployment
   ↓
Local end-to-end validation
```

Each stage should be introduced and validated independently before extending the workflow further.
