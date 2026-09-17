# Cloud NAT

Terraform module responsible for outbound Internet connectivity from private workloads in the DevSecOps GCP environment.

The module attaches Cloud NAT to the existing regional Cloud Router created by the network module.

## Table of Contents

* [Purpose](#purpose)
* [Architecture](#architecture)
* [Private Workload Connectivity](#private-workload-connectivity)
* [IP Allocation](#ip-allocation)
* [Subnet Scope](#subnet-scope)
* [Logging](#logging)
* [Inputs](#inputs)
* [Outputs](#outputs)
* [Usage](#usage)
* [Lifecycle](#lifecycle)
* [Cost Considerations](#cost-considerations)
* [Current Status](#current-status)
* [Related Documentation](#related-documentation)

## Purpose

The module provides outbound Internet access for workloads that do not have public external IP addresses.

Its initial consumer is the private GKE node pool.

Private worker nodes require outbound connectivity for operations such as:

* pulling container images
* accessing public package repositories
* reaching external APIs
* downloading runtime dependencies

Cloud NAT provides this connectivity without exposing the worker nodes directly to the Internet.

## Architecture

```text
Private GKE node
        │
        │ private IP
        ▼
 Regional subnet
        │
        ▼
  Cloud Router
        │
        ▼
    Cloud NAT
        │
        ▼
    Internet
```

Inbound Internet connectivity is not provided by this module.

The NAT path is used only for outbound connections initiated by workloads inside the VPC.

## Private Workload Connectivity

GKE worker nodes are created without external IP addresses.

Cloud NAT performs source network address translation for traffic leaving the configured subnet.

This preserves the network model:

```text
Internet
   │
   │ no direct inbound path
   X
Private GKE nodes

Private GKE nodes
   │
   │ outbound connection
   ▼
Cloud NAT
   │
   ▼
Internet
```

Public application ingress is introduced separately through the future edge architecture.

## IP Allocation

The module currently uses:

```hcl
nat_ip_allocate_option = "AUTO_ONLY"
```

Google Cloud therefore manages the external NAT IP allocation automatically.

This avoids creating and managing dedicated static NAT addresses before the architecture requires them.

A manually managed NAT address can be introduced later if the platform requires:

* stable outbound source addresses
* external allow-list integration
* explicit IP lifecycle control

## Subnet Scope

The module uses:

```hcl
source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
```

rather than automatically applying NAT to every subnet in the VPC.

The portfolio subnet is explicitly configured:

```hcl
subnetwork {
  ...
  source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
}
```

This keeps the NAT boundary explicit.

The configuration covers the primary and secondary IP ranges associated with the selected subnet, including the GKE networking ranges used by the environment.

Additional subnets should be added intentionally rather than automatically inheriting outbound NAT.

## Logging

Cloud NAT logging is enabled with:

```hcl
log_config {
  enable = true
  filter = "ERRORS_ONLY"
}
```

Only error events are collected.

This provides diagnostic visibility for failed NAT translations while avoiding unnecessary logging volume during normal successful traffic.

If deeper network analysis is required temporarily, logging can be expanded during troubleshooting.

Normal production of successful NAT flows is intentionally not logged by this module.

## Inputs

| Name            | Type     | Description                                              |
| --------------- | -------- | -------------------------------------------------------- |
| `project_id`    | `string` | Google Cloud project ID                                  |
| `region`        | `string` | Region containing the Cloud Router and NAT configuration |
| `name_prefix`   | `string` | Common prefix used for NAT naming                        |
| `router_name`   | `string` | Name of the existing Cloud Router                        |
| `subnetwork_id` | `string` | Subnetwork whose address ranges use Cloud NAT            |

## Outputs

| Name   | Description                         |
| ------ | ----------------------------------- |
| `name` | Name of the Cloud NAT configuration |

## Usage

Example:

```hcl
module "nat" {
  source = "../../modules/nat"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix

  router_name   = module.network.router_name
  subnetwork_id = module.network.subnetwork_id
}
```

The existing Cloud Router is created by the network module.

The NAT module therefore owns only the NAT configuration and does not duplicate router ownership.

## Lifecycle

The normal dependency chain is:

```text
    VPC
     │
     ▼
   Subnet
     │
     ▼
Cloud Router
     │
     ▼
 Cloud NAT
     │
     ▼
 Private GKE
```

Cloud NAT belongs to the disposable portfolio environment.

It is removed during:

```bash
make gcp-destroy
```

The Cloud Router and subnet are also removed as part of the normal portfolio Terraform lifecycle.

No NAT infrastructure is intentionally retained after a complete portfolio destroy.

## Cost Considerations

Cloud Router itself does not introduce meaningful fixed runtime cost, but Cloud NAT is billable.

Its cost depends primarily on:

* number of VM instances using NAT
* NAT gateway operation
* processed traffic volume
* Internet data transfer
* allocated external addresses

The portfolio uses Cloud NAT only while private cloud workloads are running.

NAT logging can additionally contribute to Cloud Logging ingestion volume.

Using:

```text
ERRORS_ONLY
```

limits unnecessary telemetry cost.

Concrete pricing assumptions are maintained centrally in:

[GCP Cost Model](../../../docs/architecture/gcp-cost-model.md)

## Current Status

The module currently provides:

* regional Cloud NAT
* automatic external NAT IP allocation
* explicit portfolio subnet selection
* translation for subnet IP ranges
* error-only NAT logging
* outbound connectivity for private GKE nodes

Not currently implemented:

* manually allocated static NAT addresses
* multiple NAT gateways
* custom port allocation
* endpoint-independent mapping customization
* additional NAT subnet mappings

These capabilities should only be introduced when required by measurable platform needs.

## Related Documentation

* [Terraform Documentation](../../README.md)
* [Portfolio Environment](../../environments/portfolio/README.md)
* [Network Module](../network/README.md)
* [GKE Module](../gke/README.md)
* [GCP Cost Model](../../../docs/architecture/gcp-cost-model.md)
* [GCP Environment Lifecycle](../../../docs/runbooks/gcp-environment-lifecycle.md)
