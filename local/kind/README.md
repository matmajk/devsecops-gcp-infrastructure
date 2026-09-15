# Local Kubernetes Environment

Local Kubernetes environment used to validate the DevSecOps platform before migration to GKE.

The cluster is implemented with Kind and integrates with the GitOps and local CI/CD workflows.

## Table of Contents

* [Purpose](#purpose)
* [Architecture](#architecture)
* [Cluster Topology](#cluster-topology)
* [Prerequisites](#prerequisites)
* [Lifecycle](#lifecycle)

  * [Bootstrap](#bootstrap)
  * [Start](#start)
  * [Stop](#stop)
  * [Status](#status)
  * [Delete](#delete)
* [Kubeconfig Restoration](#kubeconfig-restoration)
* [Local Registry Integration](#local-registry-integration)
* [Resource Model](#resource-model)
* [CI/CD Integration](#cicd-integration)
* [Security](#security)
* [Quick Validation](#quick-validation)
* [Local vs GCP](#local-vs-gcp)

## Purpose

The local environment validates:

* Kubernetes workloads
* Helm-rendered application configuration
* Argo CD and GitOps reconciliation
* private registry image pulls
* CI/CD integration
* observability
* security settings
* application lifecycle and failure scenarios

Daily development remains local while GCP is reserved for final cloud integration and GKE validation.

## Architecture

```text
                 Application CI
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
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
    Online Boutique  GitOps     Observability
```

## Cluster Topology

The local cluster contains two Kubernetes nodes:

```text
               devsecops-local
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
   control-plane              worker
```

The control-plane node hosts Kubernetes control-plane services.

The worker node provides additional scheduling capacity for application workloads.

Cluster configuration is stored in:

```text
local/kind/cluster.yaml
```

## Prerequisites

Required tools:

* Docker
* Kind
* kubectl

Verify:

```bash
docker version
kind version
kubectl version --client
```

## Lifecycle

The repository-level `Makefile` is the recommended interface.

Implementation details are documented in [scripts/README.md](../../scripts/README.md).

### Bootstrap

Create the cluster or restore it when it already exists:

```bash
make bootstrap
```

### Start

Restore an existing stopped cluster:

```bash
make up
```

Starting the cluster:

1. starts existing Kind node containers
2. configures local JFrog registry access
3. refreshes Kind kubeconfig
4. waits for the Kubernetes API
5. waits until all nodes are `Ready`

### Stop

Stop the cluster while preserving its state:

```bash
make down
```

This releases most Kind runtime resources without deleting the cluster.

### Status

```bash
make status
```

### Delete

Completely remove the cluster:

```bash
make cluster-delete
```

Deletion should be used only when a full environment recreation is required.

## Kubeconfig Restoration

Kind nodes are Docker containers and can survive while the local Kubernetes context is missing from the runner kubeconfig.

For this reason, cluster startup refreshes the Kind kubeconfig before Kubernetes access is validated.

Expected context:

```text
kind-devsecops-local
```

Verify:

```bash
kubectl config current-context
```

The lifecycle automation is designed so a stopped existing cluster can be restored without relying on previously persisted kubeconfig state.

## Local Registry Integration

Kind pulls CI-produced application images from the local JFrog Container Registry.

Set the registry address through:

```bash
export JFROG_REGISTRY="<host>:8082"
```

Registry configuration is applied automatically to each Kind node when the cluster is created or started.

The configuration is stored inside each Kind node under:

```text
/etc/containerd/certs.d/<registry>/hosts.toml
```

The local environment uses HTTP registry connectivity for development.

This configuration must not be reused as the cloud security model.

Registry connectivity and workload authentication remain separate:

```text
        Kind containerd
              │
              ▼
       registry connectivity

       imagePullSecret
              │
              ▼
      registry authentication
```

Credentials are provided to workloads through Kubernetes Secrets and are not stored in the Kind registry configuration.

## Resource Model

The workstation is intentionally operated using resource profiles.

Typical Kubernetes development profile:

```text
Kind        ON
SonarQube   OFF
JFrog       OFF
```

For tooling work:

```text
Kind        OFF
SonarQube   ON or JFrog ON
```

The cluster should normally be stopped rather than deleted when switching profiles.

See [Local DevSecOps Tooling](../tooling/README.md).

## CI/CD Integration

The local Kind cluster is the final deployment target of the validated local delivery workflow.

```text
             Source Commit
                  │
                  ▼
             CI Validation
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

A validated JFrog image can be pulled by both Kind nodes through the configured local registry integration.

## Security

The local environment follows the target security model where practical:

* workloads run as non-root where supported
* privilege escalation is restricted
* Kubernetes RBAC follows least-privilege principles
* credentials are not committed to Git
* registry credentials use Kubernetes Secrets
* immutable image versions are used for CI artifacts
* resource requests and limits are configured
* readiness and liveness probes are used
* images are vulnerability-scanned before publication
* desired state is managed declaratively

## Quick Validation

Verify context:

```bash
kubectl config current-context
```

Verify nodes:

```bash
kubectl get nodes -o wide
```

Verify cluster:

```bash
kubectl cluster-info
```

Verify Argo CD-managed workloads:

```bash
kubectl get applications -n argocd
kubectl get pods -A
```

Detailed operational troubleshooting should be maintained under [docs/runbooks](../../docs/runbooks/README.md).

## Local vs GCP

The local and cloud environments should reuse the same application artifacts, Helm configuration and GitOps model wherever practical.

```text
        LOCAL                         CLOUD
          │                             │
          ▼                             ▼
         Kind                           GKE
          │                             │
     Argo CD                        Argo CD
          │                             │
 Online Boutique                 Online Boutique
```

Cloud-specific networking, IAM, secrets management and production-grade reliability controls belong to the GCP environment rather than the local Kind profile.