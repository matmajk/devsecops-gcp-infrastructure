# Local DevSecOps Tooling

This directory contains local development tooling used by the DevSecOps platform outside the Kubernetes cluster.

The tooling environment is intentionally separated from the local Kind cluster to reduce Kubernetes resource consumption and to reflect the future cloud architecture, where platform tooling can run on dedicated infrastructure.

The local tooling stack is managed with Docker Compose.

## Architecture

```text
Developer Workstation
        |
        +----------------------------+
        ↓                            ↓
Kind Kubernetes               Local Tooling
        |                            |
        |                            +--> SonarQube
        |                            |      ↓
        |                            |   PostgreSQL
        |                            |
        |                            +--> JFrog Container Registry
        |                                           ↓
        |                                       PostgreSQL
        |                               
        |
        ↓
 Online Boutique
     Argo CD
  Observability
```
The current implementation includes:

```text
Local Tooling 
├── SonarQube
│   └── PostgreSQL
└── JFrog Container Registry
    └── PostgreSQL
```


```text
Directory Structure
local/tooling/
├── compose.yaml
├── .env.example
├── .gitignore
└── README.md
```

## Lifecycle management

Local DevSecOps tooling is managed through the repository-level `Makefile`.

The `Makefile` is the recommended developer-facing interface, while the underlying Docker Compose operations are implemented by: `scripts/tooling.sh`

The lifecycle architecture is:

```text
Developer
    ↓
Makefile
    ↓
scripts/tooling.sh
    ↓
Docker Compose
    │
    ├── SonarQube + PostgreSQL
    │
    └── JFrog + PostgreSQL
```

Direct Docker Compose commands remain useful for troubleshooting, but normal lifecycle operations should use the Make targets documented below.

### Available lifecycle commands:

```bash
make tooling-status
make tooling-down
```

#### `SonarQube:`

```bash
make tooling-sonar-up
make tooling-sonar-down
make tooling-sonar-status
make tooling-sonar-wait
make tooling-sonar-logs
```

#### `JFrog Container Registry:`

```bash
make tooling-jcr-up
make tooling-jcr-down
make tooling-jcr-status
make tooling-jcr-wait
make tooling-jcr-logs
```

Starting a tooling profile through the `Makefile` performs application-level readiness validation rather than relying only on Docker container state.

The lifecycle implementation also prevents accidental concurrent execution of resource-intensive workloads. By default, SonarQube or JFrog cannot be started while the Kind cluster is running, and SonarQube and JFrog cannot be started together.

Concurrent execution can be explicitly enabled for integration or resource testing:

```bash
make tooling-jcr-up TOOLING_ALLOW_CONCURRENT=1
```

The override should not be used during normal local development.

## Design Goals

The local tooling environment is designed to provide:
- reproducible local DevSecOps services
- isolated lifecycle management
- persistent application data
- explicit resource limits
- resource-aware development on a constrained workstation
- compatibility with future CI pipelines
- a migration path to a dedicated tooling VM in GCP

The local implementation is not intended to reproduce a production-grade high-availability setup.

Its purpose is to validate integration, configuration and DevSecOps workflows before moving the platform to GCP.

## Docker Compose Profiles

Tooling services are grouped using Docker Compose profiles.

The currently available profiles are:
- `sonarqube`
- `jcr`

Profiles isolate resource-intensive tooling components and allow them to be started only when required.

Normal lifecycle operations should be executed through the repository-level `Makefile`:

```bash
make tooling-sonr-up
```

or

```bash
make tooling-jcr-up
```

Direct Docker Compose commands remain available for configuration validation and troubleshooting.

For example:

```bash
docker compose \
  --profile sonarqube \
  config
```

or

```bash
docker compose \
  --profile jcr \
  config
```

This resource-aware model avoids keeping all platform components active simultaneously.

## Resource-Constrained Development Workflow

The local workstation has limited memory available for the complete platform.

For this reason, Kubernetes and resource-intensive tooling are not expected to remain active simultaneously during normal development.

The lifecycle tooling prevents accidental concurrent startup of the main resource-intensive workloads.

Recommended Kubernetes profile:

```text
Kind        ON
SonarQube   OFF
JFrog       OFF
```

Start or restore Kind:

```bash
make up
```

Recommended SonarQube profile:

```text
Kind        OFF
SonarQube   ON
JFrog       OFF
```

Switch to SonarQube:

```bash
make down
make tooling-jcr-down
make tooling-sonar-up
```

Recommended JFrog profile:

```text
Kind        OFF
SonarQube   OFF
JFrog       ON
```

Switch to JFrog:

```bash
make down
make tooling-sonar-down
make tooling-jcr-up
```

Return to Kubernetes development:

```bash
make tooling-down
make up
```

Normal lifecycle operations preserve the existing Kind cluster and persistent tooling data.

A full local environment can still be activated temporarily for end-to-end validation by explicitly allowing concurrent tooling execution when required.

## Environment Configuration

Local configuration is loaded from: `.env`

The file is intentionally excluded from version control.

Create it from the provided template:

```bash
cp .env.example .env
```

Example configuration:

```bash
SONARQUBE_VERSION=26.9.0.129388-community
POSTGRES_VERSION=17
SONAR_DB_NAME=sonar
SONAR_DB_USER=sonar
SONAR_DB_PASSWORD=change-me

JCR_VERSION=7.161.24
JCR_DB_NAME=artifactory
JCR_DB_USER=artifactory
JCR_DB_PASSWORD=change-me
```

The real local password should be changed before starting the environment.

Do not commit `.env.`

## SonarQube

SonarQube provides static code analysis and code quality validation for the DevSecOps pipeline.

The local deployment consists of:

```text
SonarQube
    ↓
PostgreSQL
```

PostgreSQL is used instead of the embedded database so the local environment more closely resembles a real deployment.

### SonarQube Persistence

Persistent Docker volumes are used for:

```text
SonarQube
├── data
├── extensions
└── logs

PostgreSQL
└── database data
```

This allows configuration and analysis history to survive container recreation.

Stopping the environment with:

```bash
make tooling-sonar-down
```

does not remove persistent data.

The lifecycle command stops and removes the SonarQube profile containers while preserving the named Docker volumes.

Avoid:

```bash
docker compose --profile sonarqube down -v
```

unless the intention is to delete all local SonarQube and database data.

### Resource Configuration

The local SonarQube profile uses explicit resource limits.

Configured limits:

|Component|CPU limit|Memory limit|
|:---|:---:|:---:|
|SonarQube|2 CPUs|4 GiB|
|PostgreSQL|—|512 MiB|
|Total configured maximum|2 CPUs + database overhead|4.5 GiB|

These values represent maximum allowed consumption.

They do not mean that Docker reserves the complete amount of memory immediately.

### Host Requirements

SonarQube uses Elasticsearch internally and therefore requires appropriate Linux kernel settings.

The following values should be verified before starting SonarQube:

```text
vm.max_map_count >= 524288
fs.file-max >= 131072
```

#### Docker Desktop / WSL2

The current value can be checked from the Docker runtime with:

```bash
docker run --rm alpine sh -c '
  sysctl vm.max_map_count
  sysctl fs.file-max
'
```

Example required output:

```powershell
vm.max_map_count = 524288
```

or a higher value.

If Docker Desktop uses the `docker-desktop` WSL2 distribution and `vm.max_map_count` is too low, it can be changed from PowerShell:

```powershell
wsl -d docker-desktop -u root sysctl -w vm.max_map_count=524288
```

Verify:

```powershell
wsl -d docker-desktop -u root sysctl vm.max_map_count
```

The setting may need to be revalidated after Docker Desktop or WSL restarts.

### Validate Docker Compose Configuration

Before starting the environment, validate the rendered configuration:

```bash
docker compose \
  --profile sonarqube \
  config
```

The resulting configuration should contain:
`sonarqube`, `sonarqube-db`

and should not contain unresolved environment variables.

### Start SonarQube

From the infrastructure repository root, run:

```bash
make tooling-sonar-up
```

The command starts SonarQube and PostgreSQL and waits until SonarQube reports the `UP` state.

Check container status:

```bash
make tooling-sonar-status
```

Monitor SonarQube startup:

```bash
make tooling-sonar-logs
```

Wait explicitly for an already-running SonarQube profile:

```bash
make tooling-sonar-wait
```

SonarQube can require additional startup time because Elasticsearch and internal services must initialize before the web interface becomes available.

### Validate SonarQube

Check the system status:

```bash
curl http://localhost:9000/api/system/status
```

The expected state is:

```json
{
  "status": "UP"
}
```

Access the UI: <http://localhost:9000>

For a fresh installation, use the initial administrator credentials and change the password when prompted.

### Stop SonarQube

Stop and remove containers while preserving persistent volumes:

```bash
make tooling-sonar-down
```

### Restart SonarQube

Start the same persisted environment again:

```bash
make tooling-sonar-up
```

Verify:

```bash
curl http://localhost:9000/api/system/status
```

The previously stored SonarQube configuration should remain available.

### Persistence Validation

Verify Docker volumes:

```bash
docker volume ls \
  | grep -E 'sonarqube|tooling'
```

A persistence test should include:

1. Start SonarQube
2. Change configuration or create a project
3. Stop the environment
4. Start the environment again
5. Verify the configuration still exists

This confirms that container recreation does not remove SonarQube state.

### Runtime Resource Usage

Actual resource consumption was measured after SonarQube reached a stable running state using:

```bash
docker stats --no-stream
```

Measured values:

|Component|CPU usage|Memory usage|Memory limit|Memory utilization|
|:---|:---:|:---:|:---:|:---:|
|SonarQube|1.90%|1.567 GiB|4 GiB|39.17%|
|PostgreSQL|0.03%|60.44 MiB|512 MiB|11.80%|
|Total|~1.93%|~1.63 GiB|4.5 GiB|—|

The configured memory limits represent maximum allowed consumption rather than reserved memory.

During the measured stable state, the complete SonarQube tooling profile consumed approximately: `1.63 GiB RAM`

This is significantly below the configured maximum of: `4.5 GiB`

Actual resource usage will vary depending on:

- size of the analyzed repository
- number of source files
- programming languages
 -number of concurrent scans
- Elasticsearch activity
- SonarQube background tasks
- PostgreSQL activity

Resource usage should be measured again during an actual CI analysis.

That measurement will provide a more representative peak runtime baseline.

## JFrog Container Registry

JFrog Container Registry is used as the local Docker/OCI artifact registry for the DevSecOps platform.

It runs outside the Kind Kubernetes cluster using Docker Compose and uses PostgreSQL for persistent metadata storage.

The local registry will later be integrated with the CI pipeline to store container images produced from the Online Boutique application.

### Architecture

```text
Developer / CI
      │
      │ docker push/pull
      ▼
JFrog Container Registry
      │
      ├── Docker/OCI artifacts
      │
      └── PostgreSQL
            │
            └── repository metadata
```

The JFrog environment is intentionally deployed outside Kubernetes because it is resource-intensive and does not need to consume resources from the local Kind cluster.

### Docker Compose profile

JFrog is isolated using the following Docker Compose profile: `jcr`

This allows JFrog to be started independently from other local tooling.

Validate the Compose configuration:

```bash
docker compose --profile jcr config
```

### Environment configuration

JFrog-specific configuration is stored in `.env`.

Example:

```bash
JCR_VERSION=7.161.24

JCR_DB_NAME=artifactory
JCR_DB_USER=artifactory
JCR_DB_PASSWORD=change-me
```

The real `.env` file must not be committed to Git.

The `.env.example` file should contain only safe example values.

### Start JFrog

Because JFrog is one of the most resource-intensive components in the local environment, stop workloads that are not required before starting it.

Stop the Kind cluster:

```bash
make down
```

Stop SonarQube:

```bash
make tooling-sonar-down
```
Start JFrog:

```bash
make tooling-jcr-up
```

The command starts JFrog and PostgreSQL and polls the JFrog Router readiness endpoint until the platform becomes operational.

Check status:

```bash
make tooling-jcr-status
```

Follow JFrog and PostgreSQL logs:

```bash
make tooling-jcr-logs
```

Wait explicitly for an already-running JFrog profile:

```bash
make tooling-jcr-wait
```

JFrog may require significantly more startup time than SonarQube.

A running container does not necessarily mean that all JFrog services are already ready.

The lifecycle command therefore waits for application-level readiness before reporting a successful startup.

### Stop JFrog

Stop and remove the JFrog profile containers while preserving persistent data:

```bash
make tooling-jcr-down
```

JFrog configuration, PostgreSQL data, repository metadata and stored artifacts remain available for the next startup.

Start the persisted environment again with:

```bash
make tooling-jcr-up
```

Do not use:

```bash
docker compose --profile jcr down -v
```

unless the JFrog and PostgreSQL persistent volumes should intentionally be deleted.

### Ports

The local JFrog deployment exposes:

```text
8081 - Artifactory service
8082 - JFrog Router/Platform
```

The UI is available at: <http://localhost:8082/ui/>

The main Artifactory API is available through: <http://localhost:8082/artifactory/>
### Health checks

Check Artifactory availability:

```bash
curl http://localhost:8082/artifactory/api/system/ping
```

Expected response: `OK`

Check JFrog Router readiness:

```bash
curl http://localhost:8082/router/api/v1/system/readiness
```

A healthy platform should return a successful readiness response.

These API checks are more reliable than waiting for the JFrog UI to become responsive.

### UI performance

JFrog Container Registry is significantly more resource-intensive than the other local tooling components.

On a memory-constrained workstation, the UI may respond slowly even when:

```text
Artifactory API       OK
Router readiness      OK
PostgreSQL            healthy
Docker registry       operational
```

For this project, CLI and API functionality are more important than UI responsiveness.

The future CI pipeline will interact with JFrog mainly through:
- Docker CLI
- JFrog REST API
- JFrog CLI

rather than through the browser interface.

### Local Docker repository

The project uses the following Docker repository: `online-boutique-docker-local`

Images stored in JFrog follow the structure:

```text
<registry>/online-boutique-docker-local/<image>:<tag>
```

Example:

```text
192.168.1.50:8082/online-boutique-docker-local/frontend:v0.10.6
```

### Local registry address

Define the JFrog registry address:

```bash
export JCR_HOST=192.168.1.50:8082
```

The IP address must match the local host address configured for Docker registry access.

Verify:

```bash
echo "${JCR_HOST}"
```

### Docker insecure registry

The local JFrog environment currently uses HTTP instead of TLS.

Docker Desktop must therefore allow the local registry as an insecure development registry.

Open:

```text
Docker Desktop
      ↓
Settings
      ↓
Docker Engine
```

Example Docker Engine configuration:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "insecure-registries": [
    "192.168.1.50:8082"
  ]
}
```

After applying the configuration, restart Docker Desktop.

Verify:

```bash
docker info
```

The configured host should appear under: `Insecure Registries`

This configuration is intended only for local development.

The future cloud environment should use TLS.

### Docker authentication

Authenticate to the local registry:

```bash
docker login "${JCR_HOST}"
```

Use the configured JFrog credentials.

For future CI integration, administrator credentials should not be used.

A dedicated CI identity or access token should be configured instead.

### Registry smoke test

A lightweight BusyBox image can be used to validate the complete registry workflow.

Pull the image:

```bash
docker pull busybox:1.36
```

Tag it for the JFrog repository:

```bash
docker tag \
  busybox:1.36 \
  "${JCR_HOST}/online-boutique-docker-local/busybox:test"
```

Push it:

```bash
docker push \
  "${JCR_HOST}/online-boutique-docker-local/busybox:test"
```

The expected workflow is:

```text
Docker Hub
    ↓
docker pull
    ↓
docker tag
    ↓
JFrog Container Registry
```

#### List Docker images through the API

The repository contents can be inspected without using the UI.

List Docker repositories:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/docker/online-boutique-docker-local/v2/_catalog \
  | jq
```

Example response:

```json
{
  "repositories": [
    "busybox"
  ]
}
```

#### List image tags

List tags for the BusyBox image:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/docker/online-boutique-docker-local/v2/busybox/tags/list \
  | jq
```

Example response:

```json
{
  "name": "busybox",
  "tags": [
    "test"
  ]
}
```

#### List Artifactory repositories

List all configured repositories:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/repositories \
  | jq
```

Print only repository names:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/repositories \
  | jq -r '.[].key'
```

The following repository should be present: `online-boutique-docker-local`

#### Inspect repository storage

Inspect the repository root:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/storage/online-boutique-docker-local \
  | jq
```

Inspect the BusyBox artifact path:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/storage/online-boutique-docker-local/busybox \
  | jq
```

#### Pull validation

After successfully pushing the image, remove its JFrog-tagged local copy:

```bash
docker image rm \
  "${JCR_HOST}/online-boutique-docker-local/busybox:test"
```

Optionally remove the original image:

```bash
docker image rm busybox:1.36
```

Pull the image back from JFrog:

```bash
docker pull \
  "${JCR_HOST}/online-boutique-docker-local/busybox:test"
``` 
Run the downloaded image:

```bash
docker run --rm \
  "${JCR_HOST}/online-boutique-docker-local/busybox:test" \
  echo "JFrog registry works"
```

Expected output: `JFrog registry works`

The complete validation flow is:

```text
Docker Hub
    ↓
docker pull
    ↓
docker tag
    ↓
JFrog push
    ↓
remove local image
    ↓
JFrog pull
    ↓
docker run
```

### Persistence validation

Stop the JFrog environment:

```bash
make tooling-jcr-down
```

Restart it:

```bash
make tooling-jcr-up
```

The startup command waits until the JFrog Router reports readiness.

Verify that the repository still exists:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/repositories \
  | jq -r '.[].key'
```

Verify that the previously pushed image still exists:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/docker/online-boutique-docker-local/v2/busybox/tags/list \
  | jq
```

The `test` tag should still be available.

This confirms persistence across container recreation.

### Resource configuration

The local environment currently uses the following limits:

|Component|CPU limit|Memory limit|
|:---|:---:|:---:|
|JFrog Container Registry|4 CPU|6 GiB|
|PostgreSQL|-|512 MiB|
|Total configured maximum|~4 CPU|6.5 GiB|

These values provide enough headroom for JFrog startup while preventing the service from consuming unrestricted host resources.

#### Measured resource usage

Resource consumption was measured after the JFrog platform completed its initial startup and became operational.

Measurement command:

```bash
docker stats --no-stream
```

Observed JFrog usage for `devsecops-tooling-jcr-1`

```text
CPU:        6.00%
Memory:     3.671 GiB/6 GiB
Memory:     61.18%
Network:    3.71 MB/7.44 MB
Block I/O:  114 MB/3.3 MB
PIDs:       486
```

Observed PostgreSQL usage for `devsecops-tooling-jcr-db-1`

```text
CPU:        0.10%
Memory:     72.6 MiB/512 MiB
Memory:     14.18%
Network:    2.71 MB/3.65 MB
Block I/O:  7.07 MB/13.2 MB
PIDs:       25
```

Approximate combined steady-state memory usage:

```text
JFrog Container Registry:  ~3.67 GiB
PostgreSQL:                ~0.07 GiB
------------------------------------
Total:                     ~3.74 GiB
```

The measured runtime footprint is lower than the configured maximum but still makes JFrog the most memory-intensive component in the local DevSecOps environment.

A second measurement should be performed later during an actual Online Boutique image build and push.

#### Docker Desktop/WSL memory

During initial JFrog testing, the Docker Desktop WSL environment reported approximately:

```text
Memory total:       7.6 GiB
Memory used:        4.9 GiB
Memory available:   2.5 GiB

Swap total:         2.0 GiB
Swap used:          ~624 MiB
```

Check the current Docker Desktop WSL memory state from PowerShell:

```powershell
wsl -d docker-desktop free -h
```

The observed swap usage can contribute to slow JFrog UI responsiveness.

If required, WSL resource limits can be configured with:

```powershell
%USERPROFILE%\.wslconfig
```

Example:

```yaml
[wsl2]
memory=10GB
swap=4GB
```

After changing the configuration:

```powershell
wsl --shutdown
```

Then restart Docker Desktop.

Verify:

```powershell
wsl -d docker-desktop free -h
```

## Troubleshooting
### SonarQube
#### SonarQube Does Not Start

Check:

```bash
docker compose logs sonarqube
```

Look for messages related to: `Elasticsearch`, `vm.max_map_count`, `memory`, `database connection`, `permissions`

#### Database Is Not Healthy

Check:

```bash
docker compose logs sonarqube-db
```

Verify:

```bash
docker compose \
  --profile sonarqube \
  ps
```

The PostgreSQL container should report a healthy state before SonarQube starts.

#### Port 9000 Is Already Used

Check:

```bash
docker ps \
  --format 'table {{.Names}}\t{{.Ports}}'
```

or on Windows:

```powershell
netstat -ano | findstr :9000
```

#### SonarQube Is OOMKilled or Restarting

Check:

```bash
docker inspect devsecops-tooling-sonarqube-1 \
  --format '{{.State.OOMKilled}}'
```

and:

```bash
docker stats --no-stream
```

Avoid reducing the SonarQube memory limit aggressively only to allow more local services to run simultaneously.

The preferred strategy is to disable unrelated workloads through the existing local platform lifecycle mechanisms.

### JFrog
#### JFrog UI loads slowly

Check Artifactory:

```bash
curl http://localhost:8082/artifactory/api/system/ping
```

Check Router readiness:

```bash
curl http://localhost:8082/router/api/v1/system/readiness
```

Check resource usage:

```bash
docker stats --no-stream
```

Check Docker Desktop memory:

```powershell
wsl -d docker-desktop free -h
```

If health endpoints respond correctly while the UI remains slow, use the REST API and Docker CLI for local validation.

#### JFrog container is running but the platform is unavailable

Check JFrog logs:

```bash
docker compose logs jcr --tail=200
```

Filter common errors:

```bash
docker compose logs jcr --tail=500 \
  | grep -Ei 'error|warn|router|frontend|access|database|oom'
```

Check PostgreSQL:

```bash
docker compose logs jcr-db --tail=100
```

Check status:

```bash
docker compose --profile jcr ps
```

Check for OOM termination:

```bash
docker inspect devsecops-tooling-jcr-1 \
  --format 'OOMKilled={{.State.OOMKilled}} RestartCount={{.RestartCount}}'
```

Expected: `OOMKilled=false`

#### Docker cannot connect to JFrog

Verify the registry configuration:

```bash
docker info
```

Check JFrog:

```bash
curl http://localhost:8082/artifactory/api/system/ping
```

Check authentication:

```bash
docker login "${JCR_HOST}"
```

#### Docker push fails with authentication errors

Logout:

```bash
docker logout "${JCR_HOST}"
```

Login again:

```bash
docker login "${JCR_HOST}"
```

Verify that the target repository exists:

```bash
curl -s -u admin:<PASSWORD> \
  http://localhost:8082/artifactory/api/repositories \
  | jq -r '.[].key'
```

## Future CI Integration

SonarQube will become part of the CI quality gate.

The planned pipeline is:

```text
Pull Request
     ↓
GitHub Actions
     |
     +--> unit tests
     |
     +--> linting
     |
     +--> SonarQube analysis
     |
     +--> quality gate
     |
     +--> security scanning
     |
     +--> container build
```

The CI pipeline should stop or fail the appropriate stage when the defined quality requirements are not satisfied.

The first local implementation will validate this workflow before moving the tooling to GCP.

JFrog Container Registry will later become part of the CI/CD workflow.

The expected flow is:

```text
Source Code
     ↓
CI Pipeline
     ↓
Docker Build
     ↓
Trivy Scan
     ↓
JFrog Container Registry
     ↓
GitOps Image Version Update
     ↓
Argo CD
     ↓
Kubernetes
```

Like SonarQube, JFrog will be started only when required by the active development scenario.

The initial CI implementation should validate the workflow with one representative Online Boutique service.

After that, the pipeline can be generalized using reusable or matrix-based GitHub Actions workflows.

## Future GCP Architecture

The local Docker Compose environment provides the functional baseline for the future cloud tooling layer.

The future cloud architecture may move DevSecOps tooling to dedicated infrastructure provisioned with Terraform and configured with Ansible.

Target direction:

```text
 GCP
  │ 
  ├── GKE
  │    ├── Online Boutique
  │    ├── Argo CD
  │    └── Observability
  │
  └── DevSecOps tooling
        ├── SonarQube
        ├── JFrog
        └── supporting services
```

Responsibilities will be separated as follows:

```text
Terraform
└── infrastructure lifecycle

Ansible
└── operating system and tooling configuration

Docker
└── application runtime

GitHub Actions
└── CI orchestration

Argo CD
└── Kubernetes deployment lifecycle
```

This allows the same tooling concepts validated locally to be reused when the platform is migrated to GCP.

### Local vs Cloud Tooling

The local tooling profile prioritizes:
- low idle resource consumption
- reproducibility
- persistence between development sessions
- integration testing
- simple lifecycle management
- CI workflow validation

The future cloud environment will additionally focus on:
- persistent infrastructure
- controlled network access
- TLS
- secrets management
- backups
- monitoring
- infrastructure automation
- configuration management
- service reliability

## Next Steps

The next local tooling milestones are:

1. Complete JFrog Docker image push, pull and persistence validation
2. Integrate SonarQube with GitHub Actions
3. Add Trivy filesystem and container image security scanning
4. Integrate JFrog Container Registry with the CI pipeline
5. Run a complete local DevSecOps workflow
6. Measure tooling resource consumption during actual CI workloads
7. Move the validated architecture to GCP