# Local Kubernetes Environment

This directory contains the configuration and documentation for the local Kubernetes development environment used by the DevSecOps platform project.

The local environment is designed to provide a low-cost, reproducible Kubernetes platform for development and integration testing before deploying the same workloads to Google Kubernetes Engine (GKE).

The local Kubernetes cluster is created with **Kind (Kubernetes IN Docker)**.

## Purpose

The local environment is used to validate Kubernetes, Helm, GitOps, CI/CD and observability workflows without requiring cloud infrastructure.

It will be used to test:

* Kubernetes workloads
* Helm charts
* Argo CD
* GitOps workflows
* Online Boutique microservices
* RBAC
* NetworkPolicies
* Horizontal Pod Autoscaling
* resource requests and limits
* readiness and liveness probes
* Prometheus
* Grafana
* Loki
* OpenTelemetry
* Jaeger
* failure and recovery scenarios

The goal is to keep daily development local while using GCP only for final cloud integration and GKE validation.

The same application and Helm configuration should work both locally and later on GKE with only environment-specific configuration changes.

## Local Environment Resource Budget 

The local DevSecOps platform is designed to run on a resource-constrained development workstation. Because the complete platform contains the application, Kubernetes control plane, GitOps tooling, observability components and additional DevSecOps services, not every optional component needs to remain active continuously. 

The local environment therefore uses reduced resource allocations and enables resource-intensive workloads only when they are required for a particular validation scenario.

### Explicit Kubernetes Resource Budget

The following values represent Kubernetes resource requests and limits explicitly configured by the project.

| Workload group | CPU requests | Memory requests | CPU limits | Memory limits | 
| --- | ---: | ---: | ---: | ---: | 
| Online Boutique core | 1.270 cores | 1112 MiB | 2.325 cores | 2030 MiB | 
| Prometheus, Grafana and Prometheus Operator | 0.300 cores | 448 MiB | 0.850 cores | 1344 MiB | 
| **Base local platform** | **1.570 cores** | **1560 MiB (~1.52 GiB)** | **3.175 cores** | **3374 MiB (~3.29 GiB)** | 
| Optional Load Generator | +0.300 cores | +256 MiB | +0.500 cores | +512 MiB | 
| **With Load Generator** | **1.870 cores** | **1816 MiB (~1.77 GiB)** | **3.675 cores** | **3886 MiB (~3.79 GiB)** |

These values represent only resources explicitly configured through Kubernetes requests and limits. They do not represent the complete memory or CPU footprint of the local environment.

Additional resources are consumed by components such as:
- Kubernetes control plane
- etcd
- CoreDNS
- kube-proxy
- container networking
- Argo CD controllers
- Argo CD Redis
- Grafana sidecars
- kube-state-metrics
- node-exporter
- Prometheus configuration sidecars
- Docker/containerd
- Docker Desktop and WSL2
- the host operating system

For this reason, actual host resource consumption can be significantly higher than the sum of Kubernetes resource requests. 

### Resource-Constrained Development Strategy

The local environment separates core workloads from components that are required only for specific test scenarios.

#### Core workloads

The following components are normally kept running:
- Kind Kubernetes cluster
- Argo CD
- Online Boutique core microservices

#### Scenario-dependent workloads

Resource-intensive capabilities can be enabled when required:
- Prometheus and Grafana
- Load Generator
- Loki and Grafana Alloy
- OpenTelemetry Collector
- Jaeger
- SonarQube
- JFrog Artifactory

This allows each platform capability to be tested locally without requiring all components to consume resources continuously. A full-stack environment can still be enabled temporarily for end-to-end integration and demonstration scenarios.

### Load Generation

The Online Boutique Load Generator is disabled when continuous application traffic is not required.

It can be enabled through environment-specific Helm values when testing:
- application traffic
- Prometheus metrics
- dashboards
- autoscaling
- tracing
- logging
- failure scenarios
- resilience behavior

Example:

```yaml
loadGenerator: 
  enabled: true
  users: 12
  rate: 1
```

When the test is complete, the workload can be disabled again through Git and removed automatically by Argo CD pruning.

### Runtime Resource Monitoring

Configured Kubernetes requests and limits describe scheduling requirements and resource boundaries. Actual runtime resource consumption should be measured separately.

Prometheus can be used to calculate the current memory usage of all monitored containers:

```
sum(
  container_memory_working_set_bytes{
    container!="",
    image!=""
  }
) / 1024 / 1024 / 1024
```

The result is expressed in GiB.

Current CPU consumption across monitored containers can be calculated using:

```
sum(
  rate(
    container_cpu_usage_seconds_total{
      container!="",
      image!=""
    }[5m]
  )
)
```

The result is expressed in CPU cores.

### Namespace Resource Usage

Online Boutique memory usage:

```
sum(
  container_memory_working_set_bytes{
    namespace="online-boutique",
    container!="",
    image!=""
  }
) / 1024 / 1024
```

Argo CD memory usage:

```
sum(
  container_memory_working_set_bytes{
    namespace="argocd",
    container!="",
    image!=""
  }
) / 1024 / 1024
```

Observability stack memory usage:

```
sum(
  container_memory_working_set_bytes{
    namespace="monitoring",
    container!="",
    image!=""
  }
) / 1024 / 1024
```

These queries make it possible to compare configured resource budgets with actual runtime consumption.

### Host-Level Monitoring

The complete Kind node footprint can also be inspected from the Docker host:

```bash
docker stats --no-stream \
  devsecops-local-control-plane \
  devsecops-local-worker
```

This provides a useful host-level view because it includes Kubernetes system components running inside the Kind nodes.

### Local vs Cloud Environment

Resource constraints applied to the local environment are development-specific.

The future GCP environment will use separate configuration appropriate for GKE and cloud infrastructure.

The local profile prioritizes:

- low resource consumption
- reproducibility
- functional validation
- GitOps workflow testing
- incremental platform development

The cloud profile will instead focus on:

- scalability
- availability
- persistent storage
- production-like observability
- autoscaling
- cloud-native integrations
- security and operational resilience

## Prerequisites

The following tools must be installed before creating the local Kubernetes cluster:

* Docker
* Kind
* kubectl

Verify the installation:

```bash
docker version
kind version
kubectl version --client
```

Verify that Docker is working correctly:

```bash
docker run --rm hello-world
```

## Directory Structure

```text
local/
└── kind/
    ├── README.md
    └── cluster.yaml
```

`cluster.yaml` contains the declarative configuration of the local Kind cluster.

## Cluster Topology

The initial local cluster contains two Kubernetes nodes:

```text
devsecops-local
├── control-plane
└── worker
```

The control-plane node runs Kubernetes control-plane components.

The worker node is used for application workloads.

This topology provides a simple but more realistic environment than a single-node cluster and allows basic Kubernetes scheduling behaviour to be tested.

The cluster topology may be extended later if additional nodes are required for scheduling, autoscaling or failure-testing scenarios.

## Create the Cluster

From the infrastructure repository root:

```bash
kind create cluster \
  --config local/kind/cluster.yaml
```

Kind creates Docker containers that act as Kubernetes nodes.

After cluster creation, Kind automatically adds a new Kubernetes context to the local kubeconfig.

## Verify the Kubernetes Context

Always verify the active Kubernetes context before performing cluster operations:

```bash
kubectl config current-context
```

Expected context:

```text
kind-devsecops-local
```

This verification is particularly important before commands that modify or delete Kubernetes resources.

## Verify Cluster Nodes

Check the cluster nodes:

```bash
kubectl get nodes -o wide
```

Expected result:

```text
NAME                           STATUS   ROLES
devsecops-local-control-plane  Ready    control-plane
devsecops-local-worker         Ready    <none>
```

Both nodes should have the `Ready` status.

## Verify Kubernetes System Components

Check the Kubernetes system Pods:

```bash
kubectl get pods -n kube-system
```

Core Kubernetes components should be in the `Running` state.

Depending on the Kind and Kubernetes versions, this may include components such as:

* CoreDNS
* kube-proxy
* local-path provisioner

## Development Namespaces

The platform initially uses the following namespaces:

```text
online-boutique
argocd
monitoring
```

Their intended responsibilities are:

| Namespace         | Purpose                                          |
| ----------------- | ------------------------------------------------ |
| `online-boutique` | Online Boutique application workloads            |
| `argocd`          | Argo CD and GitOps components                    |
| `monitoring`      | Prometheus, Grafana and observability components |

During the initial cluster smoke test, namespaces may be created manually.

Later they should be managed declaratively through GitOps.

Create them manually if required:

```bash
kubectl create namespace online-boutique
kubectl create namespace argocd
kubectl create namespace monitoring
```

Verify:

```bash
kubectl get namespaces
```

## Cluster Smoke Test

A simple NGINX workload can be used to verify that the cluster can successfully schedule and expose workloads.

Create a test deployment:

```bash
kubectl create deployment nginx \
  --image=nginx \
  --namespace online-boutique
```

Verify the Pod:

```bash
kubectl get pods \
  --namespace online-boutique
```

The Pod should reach:

```text
Running
```

Expose the deployment:

```bash
kubectl expose deployment nginx \
  --port=80 \
  --namespace online-boutique
```

Verify the Service:

```bash
kubectl get services \
  --namespace online-boutique
```

## Test Local Connectivity

Forward the Kubernetes Service to the local workstation:

```bash
kubectl port-forward \
  --namespace online-boutique \
  service/nginx \
  8080:80
```

Open:

```text
http://localhost:8080
```

The NGINX welcome page confirms that:

```text
Docker
   ↓
Kind
   ↓
Kubernetes
   ↓
Deployment
   ↓
Pod
   ↓
Service
   ↓
Port Forward
```

are functioning correctly.

## Remove Smoke-Test Resources

After verification, remove the temporary NGINX resources:

```bash
kubectl delete deployment nginx \
  --namespace online-boutique
```

```bash
kubectl delete service nginx \
  --namespace online-boutique
```

Verify:

```bash
kubectl get all \
  --namespace online-boutique
```

No NGINX resources should remain.

## Inspect the Cluster

Useful commands:

Check all nodes:

```bash
kubectl get nodes -o wide
```

Check all namespaces:

```bash
kubectl get namespaces
```

Check resources in a namespace:

```bash
kubectl get all \
  --namespace online-boutique
```

Check cluster information:

```bash
kubectl cluster-info
```

Check Kubernetes contexts:

```bash
kubectl config get-contexts
```

Inspect a Pod:

```bash
kubectl describe pod <pod-name> \
  --namespace <namespace>
```

Inspect Pod logs:

```bash
kubectl logs <pod-name> \
  --namespace <namespace>
```

## Cluster Lifecycle

The local Kind cluster lifecycle is managed through the repository-level `Makefile`.

The `Makefile` provides a stable developer interface while the underlying Kind and Docker operations are implemented in: `scripts/kind-cluster.sh`

### Bootstrap

Create the local cluster: `make bootstrap`

If the cluster already exists but is stopped, the existing Kind node containers are started instead of creating a new cluster.

The command waits until all Kubernetes nodes report the `Ready` condition.

### Start

Start an existing stopped cluster: `make up`

Kind nodes are Docker containers, so stopping the local environment does not require deleting and recreating the cluster.

### Stop

Stop the cluster while preserving its state: `make down`

This stops the Kind node containers and releases most resources consumed by the local Kubernetes environment.

The cluster configuration and workloads remain available and can be restored with: `make up`

This is particularly useful when running resource-intensive local tooling such as SonarQube or JFrog Container Registry.

### Status

Display Kind container and Kubernetes node status: `make status`

### Delete

Delete the local cluster completely: `make cluster-delete`

Unlike `make down`, this operation removes the Kind cluster and should only be used when a full environment recreation is required.

### Direct Script Usage

The lifecycle script can also be executed directly:

```bash
./scripts/kind-cluster.sh create
./scripts/kind-cluster.sh start
./scripts/kind-cluster.sh stop
./scripts/kind-cluster.sh status
./scripts/kind-cluster.sh delete
```

The Makefile remains the recommended developer-facing interface.

### Resource-Constrained Workflow

The local environment is designed for a workstation with limited memory.

A typical workflow is:

```text
Kubernetes development
        ↓
     make up

Tooling development
        ↓
    make down
        |
        +--> SonarQube
        +--> JFrog Container Registry

Return to Kubernetes
        ↓
     make up
```

Stopping the Kind cluster instead of deleting it allows the environment to be resumed without rebuilding the entire platform.

The long-term target workflow is:

```text
cluster.yaml
      ↓
Kind
      ↓
Argo CD
      ↓
GitOps Repository
      ↓
Helm
      ↓
Platform + Online Boutique
```

## Local vs GCP Environment

The local Kind cluster is intended for daily development and integration testing.

The final cloud environment will use Google Kubernetes Engine.

```text
LOCAL

Kind
├── Online Boutique
├── Helm
├── Argo CD
└── Observability


CLOUD

GKE
├── Online Boutique
├── Helm
├── Argo CD
└── Observability
```

Where possible, both environments should use the same:

* application containers
* Helm charts
* GitOps structure
* Kubernetes manifests
* security configuration
* observability configuration

Cloud-specific functionality such as GCP IAM, Workload Identity Federation, Cloud NAT, Cloud Armor and Secret Manager will be introduced during the GCP integration phase.

## Security Principles

The local environment should follow the same security principles intended for GKE where technically possible.

These include:

* workloads running as non-root
* least-privilege RBAC
* NetworkPolicies
* no credentials committed to Git
* immutable container image versions
* resource requests and limits
* readiness and liveness probes
* vulnerability scanning
* declarative configuration

## Planned Extensions

This environment will be expanded incrementally with:

1. Online Boutique Helm chart
2. Argo CD
3. GitOps deployment
4. Prometheus
5. Grafana
6. Loki
7. OpenTelemetry Collector
8. Jaeger
9. NetworkPolicies
10. RBAC
11. HPA
12. failure scenarios
13. local CI/CD integration

Each component should be validated locally before its equivalent is deployed to GKE.
