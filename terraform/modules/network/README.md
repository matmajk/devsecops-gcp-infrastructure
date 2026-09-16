# Network Module

Reusable Terraform module responsible for the foundational Google Cloud networking used by the portfolio environment.

## Table of Contents

* [Purpose](#purpose)
* [Architecture](#architecture)
* [Resources](#resources)
* [IP Addressing](#ip-addressing)
* [Private Google Access](#private-google-access)
* [Cloud Router](#cloud-router)
* [Inputs](#inputs)
* [Outputs](#outputs)
* [Usage](#usage)
* [Cost Impact](#cost-impact)
* [Current Status](#current-status)
* [Related Documentation](#related-documentation)

## Purpose

The network module creates the foundational VPC resources required by the GCP portfolio environment.

It provides:

* a custom-mode VPC network
* a regional IPv4 subnet
* a secondary IP range for GKE Pods
* a secondary IP range for Kubernetes Services
* Private Google Access
* a regional Cloud Router

Cloud NAT is intentionally not created by this module at the current stage.

It will be introduced when private GKE nodes require outbound internet connectivity.

## Architecture

```text
                        Custom VPC
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       Regional Subnet               Cloud Router
              │                           │
     ┌────────┼────────┐                  │
     │        │        │                  ▼
     ▼        ▼        ▼              Future NAT
   Nodes     Pods   Services
 primary  secondary secondary
  range     range     range
```

## Resources

The module manages:

```text
google_compute_network
google_compute_subnetwork
google_compute_router
```

The VPC uses custom subnet mode rather than automatically generated regional subnets.

The network currently uses regional dynamic routing because the portfolio environment is deployed in a single GCP region.

## IP Addressing

The default portfolio address plan is:

| Purpose                      | CIDR           |
| ---------------------------- | -------------- |
| Nodes and regional resources | `10.10.0.0/20` |
| GKE Pods                     | `10.20.0.0/16` |
| Kubernetes Services          | `10.30.0.0/20` |

The primary subnet range is used by GKE nodes and other regional resources attached directly to the subnet.

The Pod and Service ranges are secondary subnet ranges intended for a VPC-native GKE cluster.

The ranges are configurable by the portfolio environment and are not hardcoded inside the reusable module.

## Private Google Access

Private Google Access is enabled on the regional subnet.

This allows resources without external IPv4 addresses to access supported Google APIs and services without requiring public addresses.

This capability will later support private GKE nodes and private Compute Engine tooling hosts.

## Cloud Router

The module creates a regional Cloud Router.

At this stage the router does not provide NAT.

The router is created as part of the network foundation so Cloud NAT can be attached later when private GKE nodes require controlled outbound internet connectivity.

## Inputs

| Input           | Description                                      |
| --------------- | ------------------------------------------------ |
| `project_id`    | Google Cloud project ID                          |
| `region`        | GCP region for regional network resources        |
| `name_prefix`   | Prefix used for network resource names           |
| `subnet_cidr`   | Primary subnet CIDR                              |
| `pods_cidr`     | Secondary range reserved for GKE Pods            |
| `services_cidr` | Secondary range reserved for Kubernetes Services |

## Outputs

The module exposes:

* VPC ID
* VPC name
* subnet ID
* subnet name
* subnet CIDR
* Pod secondary-range name
* Service secondary-range name
* Cloud Router name

These outputs allow later modules, especially GKE, to consume the network without duplicating or hardcoding resource names.

## Usage

The portfolio environment consumes the module as:

```hcl
module "network" {
  source = "../../modules/network"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  subnet_cidr   = var.network_cidrs.subnet
  pods_cidr     = var.network_cidrs.pods
  services_cidr = var.network_cidrs.services
}
```

The root environment remains responsible for selecting environment-specific address ranges.

## Cost Impact

The current module defines resources that have no meaningful fixed hourly infrastructure cost by themselves.

```text
Creation:   $0 during the current offline stage
Runtime:    ~$0 fixed infrastructure cost
Destroyed:  ~$0
Residual:   $0
```

Network traffic can generate usage-based charges after workloads are deployed.

Cloud NAT is not part of the module at the current stage and therefore introduces no NAT processing or address charges.

## Current Status

The module is implemented as part of the target GCP architecture but has not yet been applied to a real Google Cloud project.

It can currently be initialized, formatted and validated locally.

Real infrastructure provisioning will begin after the GCP account, billing account and project are created.

## Related Documentation

For the main Terraform structure, see [Terraform documentation](../../README.md).

For the environment composition root, see [Portfolio Environment](../../environments/portfolio/README.md).

For the Terraform state bootstrap layer, see [Terraform Bootstrap](../../bootstrap/README.md).

For infrastructure architecture documentation, see [Architecture Documentation](../../../docs/architecture/README.md).
