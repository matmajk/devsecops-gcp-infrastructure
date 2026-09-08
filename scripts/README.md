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

Waits until all Kubernetes nodes report the `Ready` condition.

The `wait` command does not start a stopped cluster.

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

```nash
KIND_READY_TIMEOUT=300s \
  ./scripts/kind-cluster.sh wait
```

#### Prerequisites

Depending on the requested operation, the script requires:
- Docker
- Kind
- kubectl

The script validates required commands before executing the corresponding operation.

The Kind cluster configuration file is also validated before cluster creation.

#### Error Handling

The script uses strict Bash execution:

set -Eeuo pipefail

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

The `Makefile` delegates the underlying lifecycle operations to: `scripts/kind-cluster.sh`

This keeps low-level implementation details separated from the developer-facing workflow.

## Future Script Library

Some helper functions used by operational scripts are intentionally kept local for now.

Examples include:
- log
- info
- warn
- die
- require_command
- require_file
- error traps

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

This refactoring should be introduced when multiple scripts require the same functionality, rather than prematurely abstracting the current implementation.