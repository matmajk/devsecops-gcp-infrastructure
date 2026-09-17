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
* [Temporary Default Node Pool](#temporary-default-node-pool)
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

## Cluster Model

The cluster uses GKE Standard rather than Autopilot.

This keeps infrastructure decisions visible and configurable, including worker machine type, disk profile, node topology, identity and upgrade behavior.

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

## Private Networking

Worker nodes are configured as private and do not receive public external IP addresses.

Outbound Internet connectivity is provided through the separate [NAT module](../nat/README.md).

## Control Plane Access

The GKE API endpoint remains publicly reachable while access is restricted through Master Authorized Networks.

The developer workstation public address is supplied through local `terraform.tfvars` as a `/32` CIDR and is not committed to Git.

## VPC-Native Networking

The cluster uses VPC-native networking and explicit secondary subnet ranges.

Current portfolio address plan:

| Purpose           | CIDR            |
| ----------------- | --------------- |
| Nodes             | `10.10.0.0/20`  |
| Pods              | `10.20.0.0/16`  |
| Services          | `10.30.0.0/20`  |
| GKE control plane | `172.16.0.0/28` |

## Dataplane V2

The cluster uses GKE Dataplane V2:

```hcl
datapath_provider = "ADVANCED_DATAPATH"
```

Dataplane V2 provides the Kubernetes networking dataplane and NetworkPolicy enforcement foundation.

## Workload Identity

The cluster enables GKE Workload Identity:

```text
<PROJECT_ID>.svc.id.goog
```

This provides the foundation for workloads to authenticate to Google Cloud without long-lived service account keys.

## Temporary Default Node Pool

GKE Standard requires an initial node pool during cluster creation.

Terraform therefore cannot completely avoid creating a default node pool, even when the cluster configuration contains:

```hcl
remove_default_node_pool = true
```

The creation sequence is:

```text
           create GKE cluster
                   │
                   ▼
  create temporary default node pool
                   │
                   ▼
      cluster becomes operational
                   │
                   ▼
   remove temporary default node pool
                   │
                   ▼
create Terraform-managed primary node pool
```

For a regional cluster, `initial_node_count = 1` results in an initial node being provisioned in each configured zone.

The temporary pool must therefore be explicitly sized even though it is removed immediately afterward.

Without an explicit `node_config`, GKE defaults can consume significantly more quota than the final portfolio node pool.

The module configures the temporary pool with the same machine and disk profile as the final node pool:

```hcl
node_config {
  machine_type = var.machine_type

  disk_type    = var.node_disk_type
  disk_size_gb = var.node_disk_size_gb
}
```

This prevents the temporary pool from unexpectedly consuming default 100 GiB boot disks during cluster creation.

The temporary configuration is ignored after creation because the default pool is deleted:

```hcl
lifecycle {
  ignore_changes = [
    node_config,
  ]
}
```

This behavior is particularly important in quota-constrained environments such as the Google Cloud Free Trial.

## Node Pool

The default GKE node pool is replaced with a separately managed Terraform node pool.

The primary node pool uses configurable:

```text
machine type
boot disk type
boot disk size
```

as well as:

* Container-Optimized OS with containerd
* dedicated node service account
* Shielded GKE Nodes
* automatic repair
* automatic upgrades

Persistent application data should not rely on node boot disks.

## Node Identity

Worker nodes use the dedicated service account created by the IAM module:

```text
devsecops-portfolio-gke-nodes
```

The node pool does not use the default Compute Engine service account.

No service account keys are created.

## Free Trial Deployment Profile

The production-oriented architecture and the temporary Free Trial deployment profile are intentionally separated.

Current cost-conscious profile:

```text
Regional GKE Standard
3 availability zones
1 node per zone
3 worker nodes total

machine type:
e2-medium

boot disk:
pd-standard
30 GiB per node
```

`pd-standard` is intentionally used for the Free Trial profile.

The portfolio does not currently require SSD-backed node boot disks, while Standard Persistent Disk provides substantially more available quota in the Free Trial project.

A higher-capacity profile can later use:

```hcl
machine_type   = "e2-standard-2"
node_disk_type = "pd-balanced"
```

without changing the module architecture.

Capacity and storage performance should be increased based on measured workload requirements rather than permanently overprovisioned.

## Inputs

| Name                            | Type           | Description                                        |
| ------------------------------- | -------------- | -------------------------------------------------- |
| `project_id`                    | `string`       | Google Cloud project ID                            |
| `region`                        | `string`       | Region hosting the GKE control plane               |
| `name_prefix`                   | `string`       | Common prefix used for GKE resources               |
| `network_id`                    | `string`       | VPC network ID                                     |
| `subnetwork_id`                 | `string`       | Regional subnet ID                                 |
| `pods_secondary_range_name`     | `string`       | Secondary subnet range used by Pods                |
| `services_secondary_range_name` | `string`       | Secondary subnet range used by Kubernetes Services |
| `node_service_account_email`    | `string`       | Service account used by worker nodes               |
| `node_locations`                | `list(string)` | Zones used by the worker node pool                 |
| `machine_type`                  | `string`       | Compute Engine machine type used by nodes          |
| `node_disk_type`                | `string`       | Persistent Disk type used by node boot disks       |
| `node_disk_size_gb`             | `number`       | Boot disk size for each node                       |
| `master_ipv4_cidr`              | `string`       | CIDR reserved for the GKE control plane            |
| `control_plane_authorized_cidr` | `string`       | CIDR authorized to access the GKE API endpoint     |

## Outputs

| Name               | Description                          |
| ------------------ | ------------------------------------ |
| `cluster_name`     | GKE cluster name                     |
| `cluster_location` | Region hosting the GKE control plane |
| `endpoint`         | Public GKE API endpoint              |
| `node_pool_name`   | Name of the primary node pool        |

## Usage

```hcl
module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  network_id    = module.network.network_id
  subnetwork_id = module.network.subnetwork_id

  pods_secondary_range_name     = module.network.pods_secondary_range_name
  services_secondary_range_name = module.network.services_secondary_range_name

  node_service_account_email = module.iam.gke_node_service_account_email

  node_locations    = var.gke_config.node_locations
  machine_type      = var.gke_config.machine_type
  node_disk_type    = var.gke_config.node_disk_type
  node_disk_size_gb = var.gke_config.node_disk_size_gb

  master_ipv4_cidr              = var.gke_config.master_ipv4_cidr
  control_plane_authorized_cidr = var.gke_config.control_plane_authorized_cidr

  depends_on = [
    module.nat,
    module.project_services,
  ]
}
```

## Lifecycle

The GKE platform belongs to the disposable portfolio environment.

Normal cleanup is performed through:

```bash
make gcp-destroy
```

The destroy workflow removes the GKE cluster, worker nodes, node boot disks and other disposable portfolio resources.

The GCP project, enabled APIs and Terraform state bucket remain outside the normal disposable lifecycle.

## Cost Considerations

The primary GKE cost drivers are:

* cluster management
* worker machine type
* worker count
* worker boot disk type and size
* Cloud NAT
* observability usage

The Free Trial profile intentionally favors `pd-standard` and smaller worker sizing.

Concrete estimates are maintained centrally in [GCP Cost Model](../../../docs/architecture/gcp-cost-model.md).

## Current Status

The module currently provides:

* regional GKE Standard
* private worker nodes
* restricted public control-plane access
* VPC-native networking
* Dataplane V2
* Workload Identity
* explicit temporary default-pool sizing
* configurable node boot disk type and size
* dedicated worker identity
* Shielded GKE Nodes
* automatic node repair and upgrades
* multi-zone worker placement

Not yet implemented:

* cluster autoscaling strategy
* dedicated workload node pools
* Spot CI runner node pool
* application NetworkPolicies
* GitOps bootstrap
* ingress / Gateway
* Backup for GKE
* Binary Authorization

## Related Documentation

* [Terraform Documentation](../../README.md)
* [Portfolio Environment](../../environments/portfolio/README.md)
* [Network Module](../network/README.md)
* [NAT Module](../nat/README.md)
* [IAM Module](../iam/README.md)
* [Project Services Module](../project-services/README.md)
* [GCP Cost Model](../../../docs/architecture/gcp-cost-model.md)
* [GCP Environment Lifecycle](../../../docs/runbooks/gcp-environment-lifecycle.md)
