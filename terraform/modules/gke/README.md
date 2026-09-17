# GKE

Terraform module responsible for provisioning the Google Kubernetes Engine platform used by the DevSecOps portfolio environment.

The module creates a private regional GKE Standard cluster with explicit networking, workload identity and a separately managed worker node pool.

## Table of Contents

* [Purpose](#purpose)
* [Architecture](#architecture)
* [Cluster Model](#cluster-model)
* [Private Networking](#private-networking)
* [Control Plane Access](#control-plane-access)
* [VPC-Native Networking](#vpc-native-networking)
* [Dataplane V2](#dataplane-v2)
* [Workload Identity](#workload-identity)
* [Node Pool](#node-pool)
* [Node Identity](#node-identity)
* [Free Trial Deployment Profile](#free-trial-deployment-profile)
* [Inputs](#inputs)
* [Outputs](#outputs)
* [Usage](#usage)
* [Lifecycle](#lifecycle)
* [Cost Considerations](#cost-considerations)
* [Current Status](#current-status)
* [Related Documentation](#related-documentation)

## Purpose

The module provides the Kubernetes compute platform for the cloud version of the DevSecOps portfolio.

Its responsibilities include:

* regional GKE Standard cluster provisioning
* private worker nodes
* VPC-native Pod and Service networking
* explicit control-plane access restrictions
* Dataplane V2
* Workload Identity
* dedicated worker node identity
* separately managed worker node pool
* automatic node repair and upgrades

Application deployment is intentionally outside the responsibility of this module.

Kubernetes workloads are delivered through GitOps and Argo CD rather than directly through Terraform.

## Architecture

```text
Developer workstation
        │
        │ authorized /32
        ▼
Public GKE API endpoint
        │
        ▼
Regional GKE control plane
europe-central2
        │
        ├────────────────────┐
        │                    │
        ▼                    ▼
Private worker nodes       Workload Identity
        │
        ▼
    Custom VPC
        │
        ├── Pod secondary range
        ├── Service secondary range
        │
        ▼
    Cloud NAT
        │
        ▼
    Internet
```

The cluster uses private worker nodes while retaining a restricted public control-plane endpoint for development access from the authorized workstation.

## Cluster Model

The cluster uses GKE Standard rather than Autopilot.

This keeps infrastructure decisions visible and configurable, including:

* worker machine type
* node pool topology
* disk sizing
* node service account
* upgrade behavior
* cluster networking
* scheduling capacity

The control plane is regional:

```text
europe-central2
```

Worker nodes are distributed across:

```text
europe-central2-a
europe-central2-b
europe-central2-c
```

This preserves a multi-zone worker topology while keeping the environment appropriate for a portfolio deployment.

## Private Networking

Worker nodes are configured as private:

```hcl
enable_private_nodes = true
```

They do not receive public external IP addresses.

Outbound Internet connectivity is provided through the separate [NAT module](../nat/README.md).

This enables private nodes to perform operations such as:

* downloading container images
* accessing public package repositories
* reaching external APIs

without assigning public IP addresses directly to the worker VMs.

## Control Plane Access

The GKE API endpoint remains publicly reachable:

```hcl
enable_private_endpoint = false
```

Access is restricted through Master Authorized Networks to an explicitly configured CIDR.

For the local development environment this is expected to be the developer workstation public IP:

```text
<YOUR_PUBLIC_IP>/32
```

The real address is provided through the local `terraform.tfvars` file and is not committed to Git.

This design allows direct cluster administration from WSL without introducing a VPN or bastion host at the current project stage.

A fully private control-plane endpoint can be considered later if a private administrative access path is introduced.

## VPC-Native Networking

The cluster uses:

```hcl
networking_mode = "VPC_NATIVE"
```

Pod and Kubernetes Service addresses are allocated from explicit secondary subnet ranges created by the network module.

Current portfolio address plan:

| Purpose           | CIDR            |
| ----------------- | --------------- |
| Nodes             | `10.10.0.0/20`  |
| Pods              | `10.20.0.0/16`  |
| Services          | `10.30.0.0/20`  |
| GKE control plane | `172.16.0.0/28` |

The GKE module consumes the existing secondary range names rather than creating additional network ranges.

## Dataplane V2

The cluster uses:

```hcl
datapath_provider = "ADVANCED_DATAPATH"
```

This enables GKE Dataplane V2.

Dataplane V2 provides the networking dataplane used by the cluster and supports Kubernetes NetworkPolicy enforcement.

NetworkPolicy configuration will be introduced together with application security controls rather than duplicated through a separate legacy network-policy provider.

## Workload Identity

The cluster enables GKE Workload Identity:

```text
<PROJECT_ID>.svc.id_
```
