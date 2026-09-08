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
└── SonarQube
    └── PostgreSQL
```

JFrog Container Registry will be added in a later iteration.

```text
Directory Structure
local/tooling/
├── compose.yaml
├── .env.example
├── .gitignore
└── README.md
```

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

The current profile is: `sonarqube`

This allows SonarQube to be started only when code quality analysis is required.

Example:

```bash
docker compose \
  --profile sonarqube \
  up -d
```

This resource-aware model avoids keeping all platform components active simultaneously.

Future profiles will include additional tooling such as JFrog Container Registry.

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
docker compose \
  --profile sonarqube \
  down
```

does not remove persistent data.

Avoid:

```bash
docker compose down -v
```

unless the intention is to delete all local SonarQube and database data.

## Resource Configuration

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

## Validate Docker Compose Configuration

Before starting the environment, validate the rendered configuration:

```bash
docker compose \
  --profile sonarqube \
  config
```

The resulting configuration should contain:
`sonarqube`, `sonarqube-db`

and should not contain unresolved environment variables.

## Start SonarQube

From: `local/tooling/`

run:

```bash
docker compose \
  --profile sonarqube \
  up -d
```

Check container status:

```bash
docker compose \
  --profile sonarqube \
  ps
```

Monitor SonarQube startup:

```bash
docker compose logs -f sonarqube
```

SonarQube can require additional startup time because Elasticsearch and internal services must initialize before the web interface becomes available.

## Validate SonarQube

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

## Stop SonarQube

Stop and remove containers while preserving persistent volumes:

```bash
docker compose \
  --profile sonarqube \
  down
```

## Restart SonarQube

Start the same persisted environment again:

```bash
docker compose \
  --profile sonarqube \
  up -d
```

Verify:

```bash
curl http://localhost:9000/api/system/status
```

The previously stored SonarQube configuration should remain available.

## Persistence Validation

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

## Runtime Resource Usage

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

## Troubleshooting
### SonarQube Does Not Start

Check:

```bash
docker compose logs sonarqube
```

Look for messages related to: `Elasticsearch`, `vm.max_map_count`, `memory`, `database connection`, `permissions`

### Database Is Not Healthy

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

### Port 9000 Is Already Used

Check:

```bash
docker ps \
  --format 'table {{.Names}}\t{{.Ports}}'
```

or on Windows:

```powershell
netstat -ano | findstr :9000
```

### SonarQube Is OOMKilled or Restarting

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

## JFrog Container Registry

JFrog Container Registry will be added to the local tooling environment in the next iteration.

Its purpose will be to provide a private registry for:
- Docker images
- OCI artifacts
- Helm-related artifacts
- CI-generated build outputs

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

## Future GCP Architecture

The local Docker Compose environment provides the functional baseline for the future cloud tooling layer.

The planned GCP architecture is:

```text
Terraform
    ↓
GCP Tooling VM
    ↓
Ansible
    ↓
Docker
    |
    +--> SonarQube
    |
    +--> JFrog Container Registry
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

1. Integrate JFrog Container Registry
2. Validate Docker image push and pull
3. Integrate SonarQube with GitHub Actions
4. Add Trivy security scanning
5. Integrate JFrog with the CI pipeline
6. Automate tooling lifecycle through Make
7. Run a complete local DevSecOps workflow
8. Move the validated architecture to GCP