# Infrastructure Scripts

This directory contains operational helper scripts used by the infrastructure repository.

The scripts provide reusable implementation logic behind higher-level developer workflows exposed through the repository `Makefile`.

Direct script execution is supported, but the Makefile is the recommended interface for common development operations.

## Available Scripts
### `kind-cluster.sh`

Manages the lifecycle of the local Kind Kubernetes cluster.

Supported operations: `create`, `start`, `stop`, `delete`, `status`, `wait`

Usage:

```bash
./scripts/kind-cluster.sh <command>
```

Examples:

```bash
./scripts/kind-cluster.sh create
./scripts/kind-cluster.sh start
./scripts/kind-cluster.sh stop
./scripts/kind-cluster.sh status
./scripts/kind-cluster.sh delete
```

#### Cluster Lifecycle Commands

##### `create`

Creates the configured Kind cluster.

If the cluster already exists, the script does not create a duplicate cluster.

If the existing Kind node containers are stopped, they are started and the script waits until Kubernetes nodes become ready.

##### `start`

Starts an existing stopped Kind cluster.

The script discovers Kind node containers using the cluster label rather than relying on hardcoded container names.

After the containers are started, the script refreshes the Kind kubeconfig and waits for the Kubernetes API server and cluster nodes to become available.

##### `stop`

Stops all Docker containers belonging to the configured Kind cluster.

The cluster is not deleted and can later be restored with the `start` command.

##### `delete`

Deletes the Kind cluster completely using Kind.

This operation removes the local Kubernetes cluster and should only be used when a full environment recreation is required.

##### `status`

Displays:
- Kind node container status
- container ports
- Kubernetes node status when the cluster is running

##### `wait`

Waits until the Kubernetes cluster becomes operational and all nodes report the `Ready` condition.

The `wait` command does not start a stopped cluster.

The readiness flow includes:
- validating that the cluster exists
- validating that Kind node containers are running
- refreshing the Kind kubeconfig
- polling the Kubernetes API server
- validating Kubernetes cluster access
- waiting until all nodes report `Ready`

The Kubernetes API server is polled periodically, allowing the command to complete as soon as the API becomes reachable instead of waiting for the full configured timeout.

#### Configuration

The script supports environment-based configuration.

##### `KIND_CLUSTER_NAME`

Defines the Kind cluster name.

Default: `devsecops-local`

Example:

```bash
KIND_CLUSTER_NAME=test-cluster \
  ./scripts/kind-cluster.sh create
```

##### `KIND_CONFIG`

Defines the Kind cluster configuration file.

Default: `local/kind/cluster.yaml`

Example:

```bash
KIND_CONFIG=local/kind/custom-cluster.yaml \
  ./scripts/kind-cluster.sh create
```

##### `KIND_READY_TIMEOUT`

Defines how long the script waits for Kubernetes nodes to become ready.

Default: `180s`

Example:

```bash
KIND_READY_TIMEOUT=300s \
  ./scripts/kind-cluster.sh wait
```

##### `KIND_API_TIMEOUT`

Defines the maximum amount of time spent waiting for the Kubernetes API server to become reachable.

Example:

```bash
KIND_API_TIMEOUT=120 \
  ./scripts/kind-cluster.sh wait
```

##### `KIND_API_RETRY_INTERVAL`

Defines the delay between Kubernetes API server connectivity checks.

Example:

```bash
KIND_API_RETRY_INTERVAL=3 \
  ./scripts/kind-cluster.sh wait
```

#### Git Bash Compatibility

The local infrastructure workflow supports Git Bash on Windows.

Git Bash uses MSYS argument conversion, which can interpret Kubernetes API paths beginning with `/` as Windows filesystem paths.

For raw Kubernetes API requests, path conversion is disabled only for the affected `kubectl` command.

This ensures paths such as: `/version`

are passed to the Kubernetes API unchanged without modifying the global shell environment.

#### Prerequisites

Depending on the requested operation, the script requires:
- Docker
- Kind
- kubectl

The script validates required commands before executing the corresponding operation.

The Kind cluster configuration file is also validated before cluster creation.

#### Error Handling

The script uses strict Bash execution: `set -Eeuo pipefail`

Unexpected failures are handled through an `ERR` trap.

When an operation fails, the script reports:
- exit code
- source line
- failed command

Example:

```text
ERROR: Kind cluster operation failed.
       Exit code : 1
       Line      : 120
       Command   : kubectl wait ...
```

This makes failures easier to diagnose when the script is used locally or from automation.

Expected lifecycle states, such as a missing or stopped cluster, are handled through explicit validation and controlled error messages.

#### Idempotency

Lifecycle operations are designed to avoid unnecessary cluster recreation.

For example:

```bash
./scripts/kind-cluster.sh create
./scripts/kind-cluster.sh create
```

does not create two clusters.

If the cluster already exists and is running, the existing environment is reused.

If it exists but is stopped, its Docker containers are restarted.

#### Makefile Integration

The repository-level `Makefile` provides the preferred interface for common operations:

```bash
make bootstrap
make up
make down
make status
make cluster-delete
```

Additional low-level lifecycle targets are available:

```bash
make cluster-create
make cluster-start
make cluster-stop
make cluster-status
make cluster-wait
```

The `Makefile` delegates the underlying lifecycle operations to: `scripts/kind-cluster.sh`

This keeps low-level implementation details separated from the developer-facing workflow.

### `tooling.sh`

Manages the lifecycle of resource-intensive local DevSecOps tooling deployed through Docker Compose.

Currently supported tooling profiles:
- `sonarqube`
- `jcr`

Supported operations: `up`, `down`, `status`, `wait`, `logs`, `down-all`

Usage:

```bash
./scripts/tooling.sh <command> [profile]
```

Examples:

```bash
./scripts/tooling.sh up sonarqube
./scripts/tooling.sh down sonarqube
./scripts/tooling.sh status sonarqube
./scripts/tooling.sh wait sonarqube
./scripts/tooling.sh logs sonarqube

./scripts/tooling.sh up jcr
./scripts/tooling.sh down jcr
./scripts/tooling.sh status jcr
./scripts/tooling.sh wait jcr
./scripts/tooling.sh logs jcr

./scripts/tooling.sh status
./scripts/tooling.sh down-all
```

#### Tooling Lifecycle Commands

##### `up`

Starts the selected Docker Compose tooling profile.

Before starting the profile, the script validates required dependencies and checks whether conflicting resource-intensive workloads are already running.

After the containers are started, the script waits until the selected tool reports that it is ready.

Examples:

```bash
./scripts/tooling.sh up sonarqube
./scripts/tooling.sh up jcr
```

##### `down`

Stops and removes containers belonging to the selected tooling profile.

Persistent Docker volumes are preserved, so application configuration, database state, and stored artifacts remain available for future startups.

Examples:

```bash
./scripts/tooling.sh down sonarqube
./scripts/tooling.sh down jcr
```

##### `status`

Displays the current Docker Compose state for a selected profile.

Example:

```bash
./scripts/tooling.sh status jcr
```

When no profile is provided, the script displays the state of all managed tooling:

```bash
./scripts/tooling.sh status
```

##### `wait`

Waits until an already-running tooling profile becomes ready.

The `wait` command does not start the profile.

Example:

```bash
./scripts/tooling.sh wait jcr
```

If the profile is not running, the script exits with a controlled error.

##### `logs`

Follows logs for the selected tooling profile and its associated database.

Examples:

```bash
./scripts/tooling.sh logs sonarqube
./scripts/tooling.sh logs jcr
```

##### `down-all`

Stops all managed local DevSecOps tooling profiles while preserving persistent Docker volumes.

Usage:

```bash
./scripts/tooling.sh down-all
```

This is useful before returning to Kubernetes-based development.

#### Readiness Validation

Starting a tooling profile includes application-level readiness validation rather than relying only on Docker container state.

##### `SonarQube`

SonarQube readiness is checked through: <http://localhost:9000/api/system/status>

The service is considered ready when the API reports: `UP`

##### `JFrog Container Registry`

JFrog readiness is checked through the Router readiness endpoint:
<http://localhost:8082/router/api/v1/system/readiness>

This is particularly important for JFrog because its container can enter the running state before all internal platform services become operational.

Readiness checks are repeated periodically until the service becomes ready or the configured timeout is reached.

#### Resource Protection

The development workstation has limited memory, so the script protects the local environment from accidentally running multiple resource-intensive workloads simultaneously.

By default, starting SonarQube or JFrog is blocked when the Kind cluster is running.

The script also prevents SonarQube and JFrog from being started concurrently.

Expected local workload profiles are:

```text
Kubernetes development:
Kind        ON
SonarQube   OFF
JFrog       OFF

SonarQube development:
Kind        OFF
SonarQube   ON
JFrog       OFF

JFrog development:
Kind        OFF
SonarQube   OFF
JFrog       ON
```

If a conflicting workload is detected, the script exits with a controlled error instead of automatically stopping another environment.

This behavior keeps lifecycle operations explicit and avoids unexpected service shutdowns.

#### Concurrent Workload Override

Concurrent workload protection can be explicitly disabled for intentional integration or resource testing.

Example:

```bash
TOOLING_ALLOW_CONCURRENT=1 \
  ./scripts/tooling.sh up jcr
```

The override should not normally be used during everyday local development.

#### Configuration

The script supports environment-based configuration.

##### `TOOLING_ALLOW_CONCURRENT`

Controls whether resource conflict validation is enforced.

Default: `0`

Set to `1` to explicitly allow concurrent resource-intensive workloads.

Example:

```bash
TOOLING_ALLOW_CONCURRENT=1 \
  ./scripts/tooling.sh up jcr
```

##### `TOOLING_RETRY_INTERVAL`

Defines the delay between application readiness checks.

Default: `5`

Example:

```bash
TOOLING_RETRY_INTERVAL=3 \
  ./scripts/tooling.sh wait jcr
```

##### `SONARQUBE_READY_TIMEOUT`

Defines the maximum amount of time spent waiting for SonarQube to become ready.

Default: `180`

Example:

```bash
SONARQUBE_READY_TIMEOUT=300 \
  ./scripts/tooling.sh up sonarqube
```

##### `JCR_READY_TIMEOUT`

Defines the maximum amount of time spent waiting for JFrog Container Registry to become ready.

Default: `600`

Example:

```bash
JCR_READY_TIMEOUT=900 \
  ./scripts/tooling.sh up jcr
```

##### `TOOLING_DIR`

Defines the local tooling directory.

Default: `local/tooling`

##### `TOOLING_COMPOSE_FILE`

Defines the Docker Compose configuration file.

Default: `local/tooling/compose.yaml`

##### `TOOLING_ENV_FILE`

Defines the Docker Compose environment file.

Default: `local/tooling/.env`

##### `KIND_CLUSTER_NAME`

Defines the Kind cluster checked by resource conflict validation.

Default: `devsecops-local`

#### Prerequisites

The tooling lifecycle script requires:
- Docker
- Docker Compose
- curl

The script also requires: `local/tooling/compose.yaml`, `local/tooling/.env`

The Docker daemon must be running before tooling lifecycle operations can be executed.

Required commands, files, and Docker availability are validated before performing operations.

#### Error Handling

The script uses strict Bash execution: `set -Eeuo pipefail`

Unexpected failures are handled through an `ERR` trap.

Expected operational conditions are validated explicitly, including:
- unavailable Docker daemon
- missing Compose configuration
- missing `.env` file
- unsupported tooling profile
- tooling profile not running
- Kind cluster already running
- conflicting tooling profile already running
- readiness timeout

When readiness validation times out, the script prints additional Docker Compose status and recent logs to simplify troubleshooting.

#### Idempotency

Tooling lifecycle operations are designed to safely reuse persistent local state.

For example:

```bash
./scripts/tooling.sh up jcr
./scripts/tooling.sh down jcr
./scripts/tooling.sh up jcr
```

recreates the JFrog containers while preserving:
- JFrog configuration
- PostgreSQL data
- repository metadata
- stored artifacts

The same lifecycle model applies to SonarQube.

Normal `down` operations do not remove named Docker volumes.

#### Makefile Integration

The repository-level `Makefile` provides the preferred interface for tooling operations.

General tooling commands:

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

JFrog Container Registry:

```bash
make tooling-jcr-up
make tooling-jcr-down
make tooling-jcr-status
make tooling-jcr-wait
make tooling-jcr-logs
```

The `Makefile` delegates the underlying lifecycle operations to: `scripts/tooling.sh`

This provides a consistent developer-facing interface while keeping Docker Compose implementation details inside the operational script.

A typical resource-constrained workflow is:

```bash
make down
make tooling-jcr-up
```

After completing JFrog-related work:

```bash
make tooling-jcr-down
make up
```

To stop all local DevSecOps tooling before returning to Kubernetes development:

```bash
make tooling-down
make up
```

### `docker-cleanup.sh`

The `docker-cleanup.sh` script provides conservative Docker storage cleanup for the local DevSecOps environment.

It is designed to reclaim disk space without removing persistent platform data.

Supported operations:

```text
status
cache
volumes
clean
help
```

#### Usage:

Show current Docker storage usage:

```bash
./scripts/docker-cleanup.sh status
```

Clean unused Docker build cache:

```bash
./scripts/docker-cleanup.sh cache
```

Clean unused anonymous Docker volumes:

```bash
./scripts/docker-cleanup.sh volumes
```

Run the complete safe cleanup:

```bash
./scripts/docker-cleanup.sh clean
```

#### Build Cache Retention

The amount of Docker build cache retained after cleanup is controlled through: `DOCKER_BUILD_CACHE_KEEP_STORAGE`

Default: `5GB`

Example:

```bash
DOCKER_BUILD_CACHE_KEEP_STORAGE=3GB \
  ./scripts/docker-cleanup.sh cache
```

The build cache cleanup uses Docker's storage retention mechanism instead of deleting Docker data indiscriminately.

#### Volume Safety

Volume cleanup intentionally uses:

```bash
docker volume prune
```

without the `--all` option.

As a result, cleanup is restricted to unused anonymous volumes.

Named persistent volumes used by local platform tooling are preserved, including:
- devsecops-tooling_jcr_data
- devsecops-tooling_jcr_db
- devsecops-tooling_sonarqube_data
- devsecops-tooling_sonarqube_db
- devsecops-tooling_sonarqube_extensions
- devsecops-tooling_sonarqube_logs

The cleanup script does not execute:

```bash
docker system prune
docker volume prune --all
docker image prune --all
```

#### Makefile Integration

The repository-level `Makefile` exposes the following targets:

```bash
make docker-status
make docker-clean-cache
make docker-clean-volumes
make docker-clean
```

The recommended general maintenance command is: `make docker-clean`

## Future Script Library

Some helper functions used by operational scripts are intentionally kept local for now.

Examples include:
- `log`
- `info`
- `warn`
- `die`
- `require_command`
- `require_file`
- error traps

Both `kind-cluster.sh` and `tooling.sh` now use similar operational helpers.

A shared shell library is intentionally deferred to keep the current lifecycle changes focused and avoid combining functional changes with a broader script refactoring.

As additional automation is introduced, shared functionality can be extracted into reusable shell libraries under: `scripts/lib/`

Potential structure:

```text
scripts/
├── lib/
│   ├── logging.sh
│   ├── validation.sh
│   └── common.sh
└── ...
```

This refactoring should be introduced as a dedicated change once the common interfaces used by multiple scripts have stabilized.