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

## Stop vs Delete

Kind nodes are Docker containers.

The recommended workflow for this project is to keep the cluster available while actively developing the platform.

To inspect the Kind containers:

```bash
docker ps
```

The cluster should only be deleted when it is no longer required or when a clean Kubernetes environment is needed.

## Delete the Cluster

Remove the complete local cluster:

```bash
kind delete cluster \
  --name devsecops-local
```

Verify:

```bash
kind get clusters
```

`devsecops-local` should no longer be present.

Deleting the Kind cluster removes the Kubernetes nodes and all resources stored inside the cluster.

The cluster can always be recreated from `cluster.yaml`.

## Recreate the Cluster

The local Kubernetes environment should be reproducible.

Recreate it with:

```bash
kind create cluster \
  --config local/kind/cluster.yaml
```

Platform components will later be restored declaratively through Helm and Argo CD.

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
