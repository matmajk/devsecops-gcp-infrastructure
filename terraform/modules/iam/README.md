# IAM

Terraform module responsible for platform identities and IAM bindings used by the DevSecOps portfolio infrastructure.

The current implementation establishes a dedicated least-privilege identity for GKE worker nodes.

## Table of Contents

* [Purpose](#purpose)
* [Security Model](#security-model)
* [GKE Node Identity](#gke-node-identity)
* [IAM Management](#iam-management)
* [Service Account Keys](#service-account-keys)
* [Inputs](#inputs)
* [Outputs](#outputs)
* [Usage](#usage)
* [Lifecycle](#lifecycle)
* [Cost Considerations](#cost-considerations)
* [Planned Extensions](#planned-extensions)
* [Current Status](#current-status)
* [Related Documentation](#related-documentation)

## Purpose

The module centralizes GCP identities and IAM bindings that belong to the portfolio platform.

Its primary goals are:

* least-privilege access
* dedicated identities for infrastructure workloads
* avoidance of broad basic roles
* avoidance of long-lived service account keys
* explicit IAM ownership through Terraform

IAM configuration is introduced incrementally together with the infrastructure that requires it.

## Security Model

The project follows the principle:

```text
      workload
         │
         ▼
 dedicated identity
         │
         ▼
minimum required role
         │
         ▼
Google Cloud resource
```

The module does not use broad project-level roles such as:

```text
roles/owner
roles/editor
```

unless an explicit future requirement justifies them.

Different platform responsibilities should use separate identities rather than sharing one highly privileged service account.

## GKE Node Identity

The current module creates a dedicated service account for GKE worker nodes:

```text
devsecops-<environment>-gke-nodes
```

For the portfolio environment:

```text
devsecops-portfolio-gke-nodes
```

The service account receives:

```text
roles/container.defaultNodeServiceAccount
```

This provides the permissions required by GKE nodes without using the default Compute Engine service account.

The future GKE module will reference this service account explicitly when creating node pools.

Architecture:

```text
            GKE node pool
                  │
                  ▼
    devsecops-portfolio-gke-nodes
                  │
                  ▼
roles/container.defaultNodeServiceAccount
```

## IAM Management

Project role assignments use `google_project_iam_member`.

This resource type manages an individual member-role relationship without taking authoritative ownership of the complete role binding.

This is important because the project can contain IAM principals managed by:

* Google Cloud
* the project owner
* Terraform
* future Workload Identity Federation configuration
* other platform components

The IAM module should not remove unrelated members while managing its own bindings.

## Service Account Keys

The module does not create service account keys.

The project intentionally avoids:

```text
google_service_account_key
service-account.json
GCP_SA_KEY
long-lived private keys
```

Local Terraform access currently uses Application Default Credentials associated with the developer account.

Future GitHub Actions authentication will use:

```text
        GitHub Actions
             │
             ▼
            OIDC
             │
             ▼
Workload Identity Federation
             │
             ▼
    GCP service account
```

This avoids storing permanent Google Cloud credentials in GitHub.

## Inputs

| Name          | Type     | Description                                          |
| ------------- | -------- | ---------------------------------------------------- |
| `project_id`  | `string` | Google Cloud project where IAM resources are created |
| `name_prefix` | `string` | Common prefix used for IAM resource names            |

## Outputs

| Name                              | Description                                               |
| --------------------------------- | --------------------------------------------------------- |
| `gke_node_service_account_email`  | Email address of the dedicated GKE node service account   |
| `gke_node_service_account_member` | IAM member representation of the GKE node service account |

## Usage

Example:

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  name_prefix = local.name_prefix

  depends_on = [
    module.project_services
  ]
}
```

The GKE module can later consume:

```hcl
module.iam.gke_node_service_account_email
```

when configuring the node pool identity.

## Lifecycle

The IAM resources belong to the disposable portfolio environment.

Normal destruction removes:

```text
GKE node IAM binding
GKE node service account
```

The GCP project and developer identity remain outside the portfolio Terraform lifecycle.

The Terraform state bucket is also managed separately by the bootstrap root module.

## Cost Considerations

Google Cloud service accounts and IAM role bindings do not introduce meaningful direct runtime infrastructure cost.

They can, however, grant access to resources that generate cost.

Least-privilege IAM therefore contributes indirectly to cost control by limiting which identities can create or modify billable infrastructure.

Concrete infrastructure cost assumptions are maintained in [GCP Cost Model](../../../docs/architecture/gcp-cost-model.md).

## Planned Extensions

The IAM module will evolve as additional platform identities are required.

Planned areas include:

* GitHub Actions Workload Identity Federation
* CI deployment or artifact-management identities
* workload-specific GKE identities
* Secret Manager access
* Artifact Registry or JFrog integration where required
* Binary Authorization-related permissions

New identities should be introduced only when their required permissions are understood.

## Current Status

Currently implemented:

* dedicated GKE node service account
* least-privilege GKE node role
* Terraform-managed project IAM membership
* keyless local Terraform authentication through ADC

Not yet implemented:

* GitHub Workload Identity Federation
* GitHub-specific service account
* application workload identities
* Secret Manager IAM
* Cloud SQL-specific IAM
* Binary Authorization IAM

## Related Documentation

* [Terraform Documentation](../../README.md)
* [Portfolio Environment](../../environments/portfolio/README.md)
* [Project Services Module](../project-services/README.md)
* [Network Module](../network/README.md)
* [GCP Cost Model](../../../docs/architecture/gcp-cost-model.md)
* [GCP Environment Lifecycle](../../../docs/runbooks/gcp-environment-lifecycle.md)
