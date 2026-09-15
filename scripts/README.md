# Infrastructure Scripts

Operational scripts implementing infrastructure lifecycle automation behind the repository-level `Makefile`.

Direct script execution is supported, but `make` targets are the recommended developer and CI interface.

## Table of Contents

* [Architecture](#architecture)
* [Available Scripts](#available-scripts)

  * [kind-cluster.sh](#kind-clustersh)
  * [tooling.sh](#toolingsh)
  * [docker-cleanup.sh](#docker-cleanupsh)
* [Kind Lifecycle](#kind-lifecycle)
* [Tooling Lifecycle](#tooling-lifecycle)
* [Docker Cleanup](#docker-cleanup)
* [Error Handling](#error-handling)
* [Idempotency](#idempotency)
* [Makefile Integration](#makefile-integration)
* [Shared Script Library](#shared-script-library)

## Architecture

```text
               Developer/CI
                     │
                     ▼
                  Makefile
                     │
                     ▼
                  scripts/
                     │
        ┌────────────┼────────────┐
        │            │            │
        ▼            ▼            ▼
      Kind       Docker Compose  Docker
   lifecycle       tooling      cleanup
```

## Available Scripts

### kind-cluster.sh

Manages the local Kind cluster.

Supported commands:

```text
create
start
stop
delete
status
wait
```

Usage:

```bash
./scripts/kind-cluster.sh <command>
```

Configuration includes:

* `KIND_CLUSTER_NAME`
* `KIND_CONFIG`
* `KIND_READY_TIMEOUT`
* `KIND_API_TIMEOUT`
* `KIND_API_RETRY_INTERVAL`
* `JFROG_REGISTRY`

See [Local Kind Environment](../local/kind/README.md).

### tooling.sh

Manages Docker Compose tooling profiles.

Supported profiles:

```text
sonarqube
jcr
```

Supported commands:

```text
up
down
status
wait
logs
down-all
```

Usage:

```bash
./scripts/tooling.sh <command> [profile]
```

Configuration includes:

* `TOOLING_ALLOW_CONCURRENT`
* `TOOLING_RETRY_INTERVAL`
* `SONARQUBE_READY_TIMEOUT`
* `JCR_READY_TIMEOUT`
* `TOOLING_DIR`
* `TOOLING_COMPOSE_FILE`
* `TOOLING_ENV_FILE`
* `KIND_CLUSTER_NAME`

See [Local DevSecOps Tooling](../local/tooling/README.md).

### docker-cleanup.sh

Provides conservative Docker storage cleanup.

Supported commands:

```text
status
cache
volumes
clean
help
```

Usage:

```bash
./scripts/docker-cleanup.sh <command>
```

## Kind Lifecycle

### Create

`create` creates the cluster when it does not exist.

If the cluster exists but is stopped, the existing nodes are reused instead of creating a duplicate cluster.

### Start

`start` restores stopped Kind node containers.

The startup flow includes:

```text
          Start Kind Nodes
                 │
                 ▼
       Configure JFrog Registry
                 │
                 ▼
        Refresh Kubeconfig
                 │
                 ▼
       Wait for Kubernetes API
                 │
                 ▼
          Wait for Nodes
```

Refreshing kubeconfig makes startup independent of a previously persisted `kind-devsecops-local` context.

### Stop

Stops Kind node containers without deleting the cluster.

### Delete

Deletes the complete Kind cluster.

### Wait

Validates:

* cluster existence
* running Kind nodes
* kubeconfig access
* Kubernetes API availability
* node readiness

The command does not start a stopped cluster.

## Tooling Lifecycle

Starting a tooling profile:

1. validates required dependencies
2. checks for resource conflicts
3. starts the selected Docker Compose profile
4. waits for application-level readiness

SonarQube readiness uses its system status API.

JFrog readiness uses its Router readiness endpoint.

Persistent named volumes remain intact during normal stop/start operations.

## Docker Cleanup

Show storage usage:

```bash
make docker-status
```

Clean build cache:

```bash
make docker-clean-cache
```

Clean unused anonymous volumes:

```bash
make docker-clean-volumes
```

Recommended safe cleanup:

```bash
make docker-clean
```

Named platform volumes are intentionally preserved.

The cleanup workflow does not use destructive commands such as:

```text
docker system prune
docker volume prune --all
docker image prune --all
```

## Error Handling

Operational scripts use strict Bash execution:

```bash
set -Eeuo pipefail
```

Unexpected failures report:

* exit code
* source line
* failed command

Expected operational states are handled explicitly.

## Idempotency

Lifecycle operations are designed to reuse local state.

Examples:

* creating an existing cluster does not create a duplicate
* starting an existing stopped cluster restores it
* tooling recreation preserves persistent volumes
* cleanup avoids persistent named volumes

## Makefile Integration

Preferred Kind operations:

```bash
make bootstrap
make up
make down
make status
make cluster-delete
```

Preferred tooling operations:

```bash
make tooling-sonar-up
make tooling-sonar-down
make tooling-jcr-up
make tooling-jcr-down
make tooling-status
make tooling-down
```

Preferred Docker maintenance:

```bash
make docker-clean
```

## Shared Script Library

Several scripts use similar helpers for:

* logging
* command validation
* file validation
* controlled failures
* error traps

These helpers can later be extracted into:

```text
scripts/
├── lib/
│   ├── logging.sh
│   ├── validation.sh
│   └── common.sh
└── ...
```

The extraction should remain a dedicated refactoring rather than being coupled with lifecycle feature changes.
