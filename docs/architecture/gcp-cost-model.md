# GCP Cost Model

Central cost model for the target GCP architecture of the DevSecOps platform.

This document is the single source of truth for infrastructure cost assumptions used throughout the project.

Cost values are estimates and must be reviewed before major infrastructure changes or whenever the GCP architecture changes.

## Table of Contents

* [Purpose](#purpose)
* [Current Status](#current-status)
* [Pricing Assumptions](#pricing-assumptions)
* [Cost Principles](#cost-principles)
* [Terraform State](#terraform-state)
* [Network Foundation](#network-foundation)
* [GKE Platform](#gke-platform)
* [DevSecOps Tooling](#devsecops-tooling)
* [Cloud SQL](#cloud-sql)
* [CI Runners](#ci-runners)
* [Public Edge](#public-edge)
* [Security Services](#security-services)
* [Observability](#observability)
* [VPC Flow Logs](#vpc-flow-logs)
* [Backup for GKE](#backup-for-gke)
* [Network Traffic](#network-traffic)
* [Cumulative Migration Cost](#cumulative-migration-cost)
* [Final E2E Cost](#final-e2e-cost)
* [Development Session Cost](#development-session-cost)
* [Destroy Cost Model](#destroy-cost-model)
* [Primary Cost Risks](#primary-cost-risks)
* [Cost Optimization Strategy](#cost-optimization-strategy)
* [Review Policy](#review-policy)
* [Pricing References](#pricing-references)

## Purpose

The goal of this document is to keep infrastructure cost visible before resources are introduced into the GCP environment.

The project prioritizes:

1. predictable infrastructure cost
2. fast infrastructure destruction
3. minimal residual cost after destroy
4. usage-based resources where appropriate
5. avoiding unnecessary high-availability or enterprise features
6. avoiding commercial SonarQube and JFrog licenses

Cost information should not be duplicated across component README files.

Component documentation may describe general cost characteristics, but concrete estimates belong here.

## Current Status

The GCP environment has not yet been created.

The currently implemented Terraform work covers:

* Terraform project foundation
* remote-state bootstrap configuration
* reusable network foundation
* GCP lifecycle and cost-control automation

No billable GCP infrastructure exists yet.

Current GCP cost:

```text
Runtime:    $0/h
Daily:      $0/day
Monthly:    $0/month
```

The first meaningful runtime cost will appear when the GKE platform is created.

## Pricing Assumptions

Unless explicitly stated otherwise, estimates use the following assumptions:

| Parameter                    | Value                      |
| ---------------------------- | -------------------------- |
| Pricing review date          | September 16, 2026         |
| Region                       | `europe-central2` — Warsaw |
| Pricing model                | on-demand / pay-as-you-go  |
| Currency                     | USD                        |
| Monthly hours                | 730                        |
| Daily hours                  | 24                         |
| Committed Use Discounts      | not included               |
| VAT                          | not included               |
| Free Trial credits           | not included               |
| Commercial software licenses | not included               |
| SonarQube license            | $0 — Community             |
| JFrog license                | $0 — free edition only     |

The cost model intentionally avoids relying on temporary Free Trial credits.

If credits are available, they reduce the actual bill but should not affect architecture decisions.

## Cost Principles

The portfolio environment is designed to be disposable.

The normal lifecycle is:

```text
Create
  │
  ▼
Validate
  │
  ▼
Use
  │
  ▼
Destroy
  │
  ▼
Verify cleanup
```

The target after a complete portfolio destroy is:

```text
Runtime compute cost:     $0
GKE cost:                 $0
Cloud SQL cost:           $0
Tooling VM cost:          $0
Load balancer cost:       $0
Cloud NAT cost:           $0
```

The intentionally retained resource is the Terraform remote-state bucket.

Infrastructure should not remain active merely because it may be needed again later.

Terraform is expected to recreate disposable infrastructure when required.

## Terraform State

The Terraform bootstrap layer will create a Google Cloud Storage bucket used as the persistent remote state backend.

Expected storage volume is very small because the bucket stores Terraform state and state history rather than application data.

Expected cost:

```text
Runtime:    negligible
Monthly:    cents
```

This resource intentionally survives normal:

```bash
make gcp-destroy
```

The bootstrap bucket has a separate lifecycle from the disposable portfolio environment.

## Network Foundation

The network foundation includes:

* custom VPC
* regional subnet
* secondary Pod range
* secondary Service range
* Private Google Access
* Cloud Router

These resources do not introduce meaningful fixed hourly infrastructure cost.

```text
VPC:                 ~$0 fixed
Subnet:              ~$0 fixed
Secondary ranges:    ~$0 fixed
Cloud Router:        $0
```

Traffic, network telemetry and Cloud NAT are billed separately.

## GKE Platform

### Reference Architecture

The target cluster is:

```text
Regional GKE Standard
        │
        ├── 3 zones
        ├── minimum 3 worker nodes
        ├── private nodes
        ├── VPC-native networking
        ├── Dataplane V2
        └── Cloud NAT
```

Reference worker:

```text
e2-standard-2
2 vCPU
8 GiB RAM
```

Current Warsaw reference price:

```text
~$0.0811/h per node
```

### Cluster Management

GKE cluster management:

```text
$0.10/h
```

### Worker Nodes

Three workers:

```text
3 × $0.0811/h
= $0.2433/h
```

### Worker Disks

Assumption:

```text
3 × 50 GiB pd-balanced
= 150 GiB
```

Reference Warsaw `pd-balanced` pricing:

```text
~$0.13/GiB/month
```

Therefore:

```text
150 × $0.13
= $19.50/month
≈ $0.0267/h
```

### Cloud NAT Base Cost

For three worker VMs:

```text
3 × $0.0014/h
= $0.0042/h
```

One external NAT IP:

```text
$0.005/h
```

Fixed NAT base:

```text
$0.0092/h
```

NAT traffic processing is calculated separately.

### GKE Baseline Total

```text
GKE control plane     $0.1000/h
3 worker nodes        $0.2433/h
worker disks          $0.0267/h
Cloud NAT base        $0.0092/h
--------------------------------
TOTAL                 ~$0.3792/h
```

Equivalent:

```text
~$9.10/day
~$276.82/month
```

### Autoscaling

Each additional `e2-standard-2` worker adds approximately:

```text
Compute              ~$0.0811/h
Disk                  additional storage
NAT assignment        ~$0.0014/h
```

A practical estimate is:

```text
~$0.09/h per additional node
```

Autoscaling therefore represents one of the primary cost variables of the GKE environment.

## DevSecOps Tooling

SonarQube and JFrog are hosted outside the GKE cluster.

Target:

```text
VPC
 │
 ├── GKE
 │
 ├── SonarQube VM
 │
 └── JFrog VM
```

Assumption:

```text
2 × e2-standard-2
```

VM compute:

```text
2 × $0.0811/h
= $0.1622/h
```

Assumed total persistent disk capacity:

```text
250 GiB pd-balanced
```

Disk:

```text
250 × $0.13/month
= $32.50/month
≈ $0.0445/h
```

Additional NAT assignments:

```text
2 × $0.0014/h
= $0.0028/h
```

Total tooling compute layer:

```text
VM compute            $0.1622/h
persistent disks      $0.0445/h
NAT assignment        $0.0028/h
--------------------------------
TOTAL                 ~$0.2095/h
```

Equivalent:

```text
~$5.03/day
~$152.95/month
```

SonarQube and JFrog software licensing cost:

```text
$0
```

No commercial editions are planned.

## Cloud SQL

SonarQube and JFrog use dedicated PostgreSQL database instances.

Reference database:

```text
2 vCPU
8 GiB RAM
Cloud SQL Enterprise
General Purpose
```

Two database instances are assumed.

Current Warsaw on-demand pricing:

```text
vCPU       $0.054/vCPU-h
Memory     $0.009/GiB-h
```

One database:

```text
2 × $0.054
+
8 × $0.009

= $0.180/h
```

Two databases:

```text
$0.360/h
```

### Storage

Assumption:

```text
100 GiB SSD total
```

Current reference price:

```text
$0.000465753/GiB-h
```

Cost:

```text
~$0.0466/h
```

### Backups

Assumption:

```text
40 GiB backup storage
```

Reference price:

```text
$0.000109589/GiB-h
```

Cost:

```text
~$0.0044/h
```

### Cloud SQL Total

```text
Database compute      $0.3600/h
SSD storage           $0.0466/h
backup storage        $0.0044/h
--------------------------------
TOTAL                 ~$0.4110/h
```

Equivalent:

```text
~$9.86/day
~$300/month
```

### HA Decision

High-availability Cloud SQL is not part of the initial portfolio target.

The tooling databases belong to the delivery plane rather than the customer request path.

The current design therefore favors:

```text
zonal database
+
backup
+
documented recovery
```

over paying approximately twice the compute and memory rate for HA database instances.

This decision can be revisited if the project later introduces explicit availability requirements for the delivery platform.

## CI Runners

The target CI architecture uses ephemeral self-hosted GitHub Actions runners rather than a permanently running VM.

Target:

```text
GitHub Actions
      │
      ▼
ephemeral runner
      │
      ▼
job
      │
      ▼
runner removed
```

The preferred implementation uses a Spot-backed GKE runner node pool with:

```text
min nodes = 0
```

Reference Spot `e2-standard-2` compute cost in Warsaw is approximately:

```text
~$0.03/h
```

Including disk and networking overhead, the project uses a conservative working estimate of:

```text
~$0.04 per runner-hour
```

Idle compute cost:

```text
$0
```

Example:

```text
100 runner-hours/month
≈ $4/month
```

CI runner cost is usage-based and is not included in the fixed final environment total.

## Public Edge

The target public edge includes:

```text
Cloud DNS
    │
    ▼
External HTTPS Load Balancer / Gateway
    │
    ▼
Cloud Armor Standard
    │
    ▼
GKE
```

### Load Balancer

First five forwarding rules:

```text
$0.025/h
```

### Cloud Armor Standard

One security policy:

```text
$0.006849315/h
≈ $5/month
```

Cloud Armor Standard request processing:

```text
$0.75 / 1 million global-policy requests
```

Cloud Armor Enterprise data-processing charges are not included because the architecture uses Cloud Armor Standard.

### Cloud DNS

One zone:

```text
~$0.20/month
```

DNS queries:

```text
$0.40 / 1 million queries
```

### Fixed Edge Cost

Excluding requests and traffic:

```text
Load Balancer          $0.0250/h
Cloud Armor policy     $0.00685/h
Cloud DNS zone         ~$0.00027/h
---------------------------------
TOTAL                  ~$0.0321/h
```

Equivalent:

```text
~$0.77/day
~$23.45/month
```

## Security Services

The security architecture includes:

* Workload Identity Federation
* Secret Manager
* Cloud KMS where required
* Binary Authorization

### Workload Identity Federation

Expected direct service cost:

```text
~$0
```

The architecture intentionally avoids service-account JSON keys.

### Secret Manager

Example assumption:

```text
12 active secret versions
100,000 access operations/month
```

Free allowance:

```text
6 active versions
10,000 accesses/month
```

Estimated monthly cost:

```text
6 paid versions         ~$0.36
90,000 paid accesses    ~$0.27
--------------------------------
TOTAL                   ~$0.63/month
```

### Cloud KMS

Assumption:

```text
2 active software key versions
```

At:

```text
$0.06/month per active software key version
```

Estimated:

```text
~$0.12/month
```

### Binary Authorization

GKE enforcement:

```text
$0.01613/cluster-h
```

Google currently provides:

```text
$12/month credit per billing account
```

which covers approximately one continuously running cluster.

Expected effective cost for this project:

```text
~$0/month
```

### Security Layer Total

Reference low-volume usage:

```text
~$0.75/month
≈ $0.001/h
```

## Observability

The cloud target does not reproduce the complete local observability stack 1:1.

Target services include:

```text
OpenTelemetry
     │
     ├── Managed Service for Prometheus
     ├── Cloud Logging
     └── Cloud Trace
```

### Managed Prometheus

Reference assumption:

```text
5,000 active time series
30-second scrape interval
```

Samples per month:

```text
5,000
× 2 samples/min
× 60
× 24
× 30

= 432 million samples/month
```

Reference price:

```text
$0.06 / million samples
```

Cost:

```text
432 × $0.06
= $25.92/month
```

### Cloud Logging

Assumption:

```text
60 GiB/month non-vended application/platform logs
```

Free allowance:

```text
50 GiB/project/month
```

Billable:

```text
10 GiB × $0.50
= $5/month
```

### Cloud Trace

Assumption:

```text
3 million spans/month
```

Free allowance:

```text
2.5 million spans/month
```

Billable:

```text
0.5 million × $0.20/million
= $0.10/month
```

### Observability Total

```text
Managed Prometheus     $25.92/month
Cloud Logging           $5.00/month
Cloud Trace             $0.10/month
------------------------------------
TOTAL                   ~$31.02/month
```

Equivalent:

```text
~$0.0425/h
~$1.02/day
```

This value is usage-based and can change significantly with:

* metric cardinality
* scrape interval
* log verbosity
* tracing sampling rate

## VPC Flow Logs

The network foundation enables VPC Flow Logs for security visibility, troubleshooting and network analysis.

Current configuration uses reduced logging volume rather than maximum-detail collection.

VPC Flow Logs are **not free**.

Google charges separately for:

1. network telemetry log generation
2. storage of vended network logs in Cloud Logging

Reference rates for the first pricing tier:

```text
Network telemetry generation    $0.25/GiB
Vended log storage              $0.25/GiB
```

Therefore, if generated logs are stored in Cloud Logging, a useful reference is:

```text
~$0.50/GiB
```

before extended retention or external export costs.

Examples:

```text
10 GiB/month    ≈ $5/month
25 GiB/month    ≈ $12.50/month
50 GiB/month    ≈ $25/month
```

This cost is intentionally **not included** in the final E2E estimate because no real GCP traffic measurements exist yet.

After the first GCP deployment, actual Flow Logs volume must be measured.

If required, cost can be reduced through:

* longer aggregation intervals
* lower secondary sampling rate
* selective filtering
* reduced metadata
* avoiding unnecessary long retention

The security and operational value of Flow Logs should be balanced against ingestion volume.

## Backup for GKE

Reference assumption:

```text
3 protected non-system namespaces
20 GiB backup data
```

Current pricing model:

```text
$9 / namespace-month
$0.045 / GiB-month
```

Management:

```text
3 × $9
= $27/month
```

Storage:

```text
20 × $0.045
= $0.90/month
```

Total:

```text
~$27.90/month
≈ $0.0382/h
≈ $0.92/day
```

Backup is considered useful only if restore procedures are also validated.

## Network Traffic

Traffic costs are inherently usage-based.

For a reference estimate the cost model assumes:

```text
100,000 HTTP requests/day
5 GiB public response traffic/day
1 million DNS queries/month
30 GiB additional NAT outbound traffic/month
```

### Public Application Traffic

Approximately:

```text
150 GiB/month
```

Premium Tier transfer to Europe:

```text
first 1 GiB/month        free
next tier                $0.12/GiB
```

Reference application egress:

```text
149 × $0.12
= ~$17.88/month
```

### Load Balancer Processing

```text
150 GiB × $0.008
= ~$1.20/month
```

### Cloud Armor Requests

```text
3 million requests
× $0.75/million
= ~$2.25/month
```

### DNS Queries

```text
1 million queries
≈ $0.40/month
```

### NAT Processing

Assumption:

```text
30 GiB/month
```

Processing:

```text
30 × $0.045
= ~$1.35/month
```

Reference outbound transfer:

```text
30 × $0.12
= ~$3.60/month
```

### Reference Network Usage Total

```text
Application egress       $17.88
LB processing             $1.20
Cloud Armor requests      $2.25
DNS queries               $0.40
NAT processing            $1.35
NAT outbound transfer     $3.60
--------------------------------
TOTAL                    ~$26.68/month
```

Equivalent average:

```text
~$0.0365/h
```

This value is only a reference scenario.

Actual traffic may be substantially lower during portfolio development.

## Cumulative Migration Cost

The following table shows the expected running cost as architecture layers are introduced.

The values represent the current reference architecture, not mandatory spend during implementation.

| Stage                     |                   Incremental | Approx. cumulative |
| ------------------------- | ----------------------------: | -----------------: |
| Terraform foundation      |                            $0 |                 $0 |
| Terraform state bootstrap |                    negligible |         negligible |
| Network foundation        |                     ~$0 fixed |         negligible |
| IAM / APIs                |                           ~$0 |         negligible |
| Regional GKE baseline     |                    +~$0.379/h |          ~$0.379/h |
| GitOps / Online Boutique  | ~$0 if capacity is sufficient |          ~$0.379/h |
| Cloud SQL tooling DBs     |                    +~$0.411/h |          ~$0.790/h |
| SonarQube + JFrog VMs     |                    +~$0.210/h |          ~$1.000/h |
| Ephemeral CI              |                   usage-based |    ~$1.000/h fixed |
| Public edge               |                    +~$0.032/h |          ~$1.032/h |
| Managed observability     |                    +~$0.043/h |          ~$1.074/h |
| Security services         |                    +~$0.001/h |          ~$1.075/h |
| Backup for GKE            |                    +~$0.038/h |          ~$1.114/h |
| Reference traffic         |            +~$0.037/h average |       **~$1.15/h** |

VPC Flow Logs and ephemeral runner usage are not included in the final cumulative value because their cost depends on measured usage.

## Final E2E Cost

### Fixed and Reference Usage Model

Current target estimate:

```text
GKE                       ~$276.82/month
Tooling VMs               ~$152.95/month
Cloud SQL                 ~$300.00/month
Public edge                ~$23.45/month
Observability              ~$31.02/month
Security services           ~$0.75/month
Backup for GKE             ~$27.90/month
Reference traffic          ~$26.68/month
------------------------------------------------
TOTAL                      ~$839.57/month
```

Equivalent average:

```text
~$1.15/h
~$27.60/day
~$840/month
```

The estimate excludes:

* commercial JFrog licenses
* commercial SonarQube licenses
* VPC Flow Log volume
* ephemeral CI runner usage
* domain registration
* taxes
* temporary Free Trial credits
* Committed Use Discounts
* unexpected autoscaling
* unusual data transfer volumes

## Development Session Cost

The complete environment is **not intended to run continuously during development**.

Using the reference full-environment cost:

```text
~$1.15/h
```

an eight-hour full-stack session is approximately:

```text
8 × $1.15
≈ $9.20
```

In practice, many development sessions should cost less because:

* Cloud SQL may not yet exist
* tooling may not be enabled
* public ingress may be disabled
* Backup for GKE may not yet be active
* CI runners scale to zero
* traffic will be low

The environment should be destroyed after validation when it is no longer needed.

## Destroy Cost Model

Normal cleanup:

```bash
make gcp-destroy
```

is expected to remove the disposable portfolio infrastructure.

Target result:

```text
GKE                       removed
worker nodes              removed
node disks                removed
Cloud SQL                 removed
SonarQube VM              removed
JFrog VM                  removed
tooling disks             removed
Cloud NAT                 removed
load balancer             removed
environment IPs           removed
```

Intentionally retained:

```text
Terraform GCS state bucket
```

Target residual runtime cost after successful destruction:

```text
≈ $0/h
```

Persistent residual cost:

```text
Terraform state storage only
≈ cents/month
```

After every major infrastructure destroy, remaining resources should be verified rather than assuming that Terraform cleanup removed every billable dependency.

## Primary Cost Risks

The highest cost risks in the architecture are:

### GKE Autoscaling

Every additional node adds compute, disk and networking cost.

Unexpected pending Pods or incorrect resource requests can cause unnecessary scale-out.

### Cloud SQL

The two tooling databases represent the largest single fixed infrastructure layer.

Adding HA would approximately double their CPU and memory cost.

### Forgotten Tooling VMs

SonarQube and JFrog VMs generate compute cost for every hour they remain active.

They should not remain running unless required.

### Observability Cardinality

Prometheus cost scales with samples.

High-cardinality labels or unnecessarily short scrape intervals can materially increase monitoring cost.

### Logging

Verbose application logs can exceed the free Cloud Logging allowance.

VPC Flow Logs are additionally billed as network telemetry and vended network logs.

### Network Traffic

Internet egress and NAT processing are usage-based.

Large image transfers or repeated artifact downloads can increase cost.

### Persistent Storage

Persistent disks continue generating storage charges while they exist even if their VM is stopped.

Stopping a VM does not eliminate disk cost.

### Residual Resources

Unexpected surviving resources can include:

* disks
* snapshots
* static external IPs
* backup data
* load-balancer components

Destroy verification is therefore part of the infrastructure lifecycle.

## Cost Optimization Strategy

The project follows these optimization principles:

### Destroy Instead of Idle

Prefer:

```text
terraform destroy
```

over maintaining an unused environment.

### Scale CI to Zero

Ephemeral CI runner infrastructure should have:

```text
min nodes = 0
```

where technically possible.

### No Unnecessary HA

High availability should be introduced based on explicit availability requirements rather than automatically enabled for every service.

### Right-Size Before Scaling

Resource requests, VM sizes and Cloud SQL sizing should be based on observed consumption.

### Control Telemetry

Monitor:

* Prometheus series count
* scrape interval
* log ingestion
* VPC Flow Log volume
* trace sampling

### Review Terraform Plans

Every GCP infrastructure change should follow:

```text
plan
  │
  ▼
review
  │
  ▼
apply
```

Cost-impacting resources should be identifiable during plan review.

### Verify Destroy

Infrastructure destruction is not considered complete until remaining billable resources have been checked.

## Review Policy

This document should be updated when:

* a new billable GCP service is introduced
* instance sizing changes
* node pool sizing changes
* Cloud SQL sizing changes
* observability assumptions change
* traffic becomes measurable
* GCP pricing materially changes
* the deployment topology changes

Concrete cost values should not be copied into multiple component README files.

This document remains the central cost reference.

The pricing model should be reviewed again immediately before the first real GCP deployment.

## Pricing References

The current model was reviewed against the pricing information available on September 16, 2026 for:

* Google Kubernetes Engine pricing
* Compute Engine general-purpose VM pricing
* Compute Engine Persistent Disk pricing
* Cloud NAT pricing
* Cloud Load Balancing pricing
* Cloud Armor pricing
* Cloud DNS pricing
* Cloud SQL pricing
* Secret Manager pricing
* Cloud KMS pricing
* Binary Authorization pricing
* Google Cloud Observability pricing
* VPC network telemetry pricing
* Backup for GKE pricing

Regional prices use `europe-central2` where regional pricing applies.
