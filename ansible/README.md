# Ansible

Ansible configuration used to bootstrap and configure platform components after infrastructure provisioning.

For the GCP environment, Terraform provisions the GKE infrastructure and required Google Cloud backing services. Ansible then prepares platform prerequisites and performs the initial bootstrap required before Argo CD can take over workload reconciliation.

## Table of Contents

* [Architecture](#architecture)
* [Directory Structure](#directory-structure)
* [Requirements](#requirements)
* [Inventory](#inventory)
* [GKE Platform Bootstrap](#gke-platform-bootstrap)
* [JFrog Bootstrap Role](#jfrog-bootstrap-role)
* [Argo CD Role](#argo-cd-role)
* [Configuration](#configuration)
* [Usage](#usage)
* [Validation](#validation)
* [Related Documentation](#related-documentation)

## Architecture

The GCP platform follows this ownership model:

```text
Terraform
    ↓
GCP infrastructure
    ↓
   GKE
    ↓
 Ansible
    ├── JFrog prerequisites
    └── Argo CD bootstrap
                ↓
       GitOps root Application
                ↓
        Argo CD workloads
```

Responsibilities are intentionally separated:

* **Terraform** provisions GCP infrastructure and managed backing services.
* **Ansible** prepares platform prerequisites and bootstraps components required before GitOps can operate.
* **Argo CD** reconciles Kubernetes workloads from the GitOps repository.
* **CI pipelines** build, test, scan and promote artifacts but do not deploy directly to Kubernetes.

The local development environment does not use this Ansible bootstrap flow.

## Directory Structure

```text
ansible/
├── README.md
├── ansible.cfg
├── requirements.txt
├── requirements.yml
├── inventories/
│   └── portfolio/
│       ├── group_vars/
│       │   └── all.yaml
│       ├── gcp.yaml
│       └── hosts.yaml.example
├── playbooks/
│   ├── tooling.yml
│   └── gke-bootstrap.yaml
└── roles/
    ├── argocd/
    │   ├── defaults/
    │   │   └── main.yaml
    │   └── tasks/
    │       └── main.yaml
    ├── jfrog_bootstrap/
    │   ├── defaults/
    │   │   └── main.yaml
    │   └── tasks/
    │       └── main.yaml
    ├── artifactory/
    ├── common/
    ├── docker/
    ├── github-runner/
    └── sonarqube/
```

The existing tooling roles remain separate from the GKE platform bootstrap flow.

## Requirements

The GKE bootstrap uses:

* Ansible Core
* `kubernetes.core` Ansible collection
* Python Kubernetes client
* Google Cloud CLI
* OpenSSL
* access to the target GKE cluster through the current kubeconfig
* authenticated access to the target Google Cloud project
* a local checkout of the GitOps repository

Python dependencies are defined in:

```text
ansible/requirements.txt
```

Ansible collections are defined in:

```text
ansible/requirements.yml
```

The recommended setup is managed through the repository Makefile:

```bash
make ansible-setup
```

This creates an isolated Ansible virtual environment under:

```text
ansible/.venv
```

The virtual environment avoids modifying the system Python installation and ensures that the Python dependencies required by the Kubernetes Ansible modules are available.

The Google Cloud CLI must also be authenticated for the target project.

Verify the active account and project before running the bootstrap:

```bash
gcloud auth list
gcloud config get-value project
```

## Inventory

The portfolio environment separates local GKE bootstrap from VM-oriented tooling inventory.

### GKE Inventory

The GKE bootstrap uses:

```text
ansible/inventories/portfolio/gcp.yaml
```

It defines `localhost` as the Ansible execution target:

```yaml
---
all:
  hosts:
    localhost:
      ansible_connection: local
```

Ansible therefore runs the bootstrap from the local control machine and communicates with GKE through the Kubernetes API.

Environment-specific variables are stored under:

```text
ansible/inventories/portfolio/group_vars/all.yaml
```

These include values such as:

```text
GCP project ID
JFrog database password Secret Manager ID
JFrog master key Secret Manager ID
JFrog join key Secret Manager ID
```

No secret values are stored in the inventory.

### Tooling Inventory

The existing:

```text
ansible/inventories/portfolio/hosts.yaml.example
```

is a template for VM-oriented tooling automation.

It is intentionally separate from `gcp.yaml` because the GKE bootstrap does not connect to Kubernetes worker nodes or tooling VMs over SSH.

## GKE Platform Bootstrap

The GKE bootstrap entrypoint is:

```text
ansible/playbooks/gke-bootstrap.yaml
```

The playbook runs locally and uses the active Kubernetes context.

The high-level bootstrap sequence is:

```text
    Verify local prerequisites
                ↓
   JFrog bootstrap prerequisites
                ↓
    Verify GKE API connectivity
                ↓
Validate GitOps bootstrap manifests
                ↓
     Create Argo CD namespace
                ↓
  Install pinned Argo CD version
                ↓
   Wait for Argo CD readiness
                ↓
  Apply GCP bootstrap AppProject
                ↓
    Apply GCP root Application
                ↓
    Verify bootstrap resources
```

The JFrog bootstrap role executes before Argo CD so that the required namespace and Kubernetes Secrets exist before a future JFrog Application is reconciled.

Ansible stops after the initial platform prerequisites and GitOps root Application have been created.

Application workloads such as Online Boutique and JFrog itself are not deployed directly by Ansible.

They are reconciled by Argo CD from the GitOps repository.

## JFrog Bootstrap Role

The JFrog prerequisite bootstrap is implemented in:

```text
ansible/roles/jfrog_bootstrap/
```

Its purpose is to prepare secret material and Kubernetes prerequisites before JFrog is deployed through GitOps.

### Ownership Model

The JFrog bootstrap follows this ownership boundary:

```text
Terraform
    ↓
creates Secret Manager resources
    ├── database password
    ├── master key container
    └── join key container
         ↓
      Ansible
         ├── validates Secret Manager resources
         ├── reads database password
         ├── generates master key when missing
         ├── generates join key when missing
         ├── stores generated secret versions
         ├── creates jfrog namespace
         └── creates Kubernetes Secrets
               ↓
            Argo CD
               ↓
   deploys JFrog through Helm
```

Terraform remains the owner of the Secret Manager resources themselves.

Ansible does not create Secret Manager containers.

### Database Password

The database password is generated and stored by Terraform.

Ansible reads the latest version from Secret Manager and keeps the value only in memory during execution.

The password is not printed in Ansible output because secret-handling tasks use `no_log: true`.

The Kubernetes representation required by the JFrog Helm deployment is intentionally deferred until the exact Helm chart version and external database configuration are pinned.

### Master and Join Keys

Terraform creates empty Secret Manager containers for:

```text
JFrog master key
JFrog join key
```

During bootstrap, Ansible checks whether an enabled secret version already exists.

If no version exists:

```text
         Ansible
            ↓
   openssl rand -hex 32
            ↓
gcloud secrets versions add
```

If a version already exists, it is reused.

This ensures that master and join keys survive GKE recreation and are not rotated on every bootstrap run.

The values are then synchronized into Kubernetes Secrets:

```text
jfrog-master-key
jfrog-join-key
```

in the:

```text
jfrog
```

namespace.

### Idempotency

The role is designed to be safely executed repeatedly.

First execution:

```text
Secret Manager container exists
             ↓
   no enabled key version
             ↓
       generate key
             ↓
      store version 1
             ↓
 create Kubernetes Secret
```

Subsequent execution:

```text
Secret Manager container exists
             ↓
 enabled key version exists
             ↓
    reuse existing key
             ↓
 reconcile Kubernetes Secret
```

A repeated:

```bash
make gcp-bootstrap
```

must not create new master or join key versions unless the existing versions have been explicitly removed or disabled.

## Argo CD Role

The Argo CD bootstrap logic is implemented in:

```text
ansible/roles/argocd/
```

The role owns only the initial Argo CD installation and GitOps bootstrap.

Its main responsibilities are:

1. verify access to the Kubernetes API
2. verify that the required GitOps manifests exist
3. create the `argocd` namespace
4. install the configured Argo CD version
5. wait for Argo CD pods to become ready
6. apply the GCP bootstrap `AppProject`
7. apply the GCP root `Application`
8. verify that the bootstrap resources exist

The role does not own workload deployment after bootstrap.

## Configuration

### Argo CD

Role defaults are defined in:

```text
ansible/roles/argocd/defaults/main.yaml
```

The Argo CD version is pinned through:

```yaml
argocd_version: "v.x.y.z"
```

The installation manifest URL is derived from that version:

```yaml
argocd_install_manifest_url: >-
  https://raw.githubusercontent.com/argoproj/argo-cd/{{ argocd_version }}/manifests/install.yaml
```

The GitOps repository location is supplied to the GKE bootstrap through:

```yaml
gitops_repo_path
```

The role resolves the required bootstrap manifests relative to that repository:

```text
argocd/bootstrap/platform-bootstrap-gcp-project.yaml
argocd/bootstrap/platform-root-gcp.yaml
```

The GitOps repository therefore remains the source of truth for Argo CD Applications and AppProjects.

### JFrog

Role defaults are defined in:

```text
ansible/roles/jfrog_bootstrap/defaults/main.yaml
```

They define Kubernetes-level defaults such as:

```text
JFrog namespace
master key Kubernetes Secret name
join key Kubernetes Secret name
```

Environment-specific Google Cloud resource identifiers are provided through:

```text
ansible/inventories/portfolio/group_vars/all.yaml
```

Secret values themselves are never stored in Git.

## Usage

### Prepare Ansible

Prepare the Ansible environment when the virtual environment or dependencies are missing:

```bash
make ansible-setup
```

### Validate the Playbook

Run syntax validation:

```bash
make ansible-check
```

### Refresh GKE Credentials

After recreating the GKE cluster, refresh the local kubeconfig before running the bootstrap:

```bash
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region=europe-central2 \
  --project=devsecops-portfolio-matmajk
```

This is important after an infrastructure destroy/apply cycle because the recreated GKE control plane may use a different API endpoint.

### Verify GKE Connectivity

Verify that the current kubeconfig can reach the cluster:

```bash
kubectl cluster-info
kubectl get nodes -L topology.kubernetes.io/zone
```

Both commands must succeed before running Ansible.

### Bootstrap the GCP Platform

Run:

```bash
make gcp-bootstrap
```

The Make target executes:

```text
ansible/playbooks/gke-bootstrap.yaml
```

using:

```text
ansible/inventories/portfolio/gcp.yaml
```

and the repository Ansible configuration and virtual environment.

The expected ownership flow is:

```text
GKE
 ↓
Ansible
 ├── JFrog prerequisites
 └── Argo CD
        ↓
platform-bootstrap-gcp
        ↓
platform-root-gcp
        ↓
    argocd/gcp
```

## Validation

### Ansible Configuration

Verify that the playbook passes syntax validation:

```bash
make ansible-check
```

### Inventory

Verify that the GCP inventory and portfolio variables are loaded:

```bash
ANSIBLE_CONFIG="$PWD/ansible/ansible.cfg" \
ansible/.venv/bin/ansible-inventory \
  -i ansible/inventories/portfolio/gcp.yaml \
  --host localhost
```

The output should include the portfolio GCP and JFrog configuration variables.

### Kubernetes Connectivity

Verify access to the GKE API:

```bash
kubectl get nodes
```

### JFrog Namespace

Verify that the namespace exists:

```bash
kubectl get namespace jfrog
```

### JFrog Kubernetes Secrets

List JFrog secrets:

```bash
kubectl get secrets -n jfrog
```

Expected bootstrap Secrets include:

```text
jfrog-master-key
jfrog-join-key
```

Verify the Secret keys without printing their values:

```bash
kubectl get secret jfrog-master-key \
  -n jfrog \
  -o jsonpath='{.data}' | jq 'keys'
```

Expected:

```json
[
  "master-key"
]
```

Verify the join key:

```bash
kubectl get secret jfrog-join-key \
  -n jfrog \
  -o jsonpath='{.data}' | jq 'keys'
```

Expected:

```json
[
  "join-key"
]
```

### Secret Manager

Verify the master key versions:

```bash
gcloud secrets versions list \
  devsecops-portfolio-jfrog-master-key \
  --project=devsecops-portfolio-matmajk
```

Verify the join key versions:

```bash
gcloud secrets versions list \
  devsecops-portfolio-jfrog-join-key \
  --project=devsecops-portfolio-matmajk
```

After the initial bootstrap, each key should have an enabled secret version.

### Idempotency

Run the bootstrap a second time:

```bash
make gcp-bootstrap
```

The key generation and Secret Manager version creation tasks should be skipped.

The second execution must reuse the existing master and join keys rather than create new versions.

### Argo CD

Inspect the Argo CD namespace:

```bash
kubectl get pods -n argocd
```

Inspect AppProjects:

```bash
kubectl get appprojects -n argocd
```

Inspect Applications:

```bash
kubectl get applications -n argocd
```

The bootstrap is expected to create:

```text
AppProject:
platform-bootstrap-gcp

Application:
platform-root-gcp
```

Additional Applications and AppProjects are created by the GitOps root Application from the `argocd/gcp` desired state.

Full workload health, self-healing and AppProject policy tests are validated as part of the GCP end-to-end GitOps flow.

## Related Documentation

### Project Documentation

* [Infrastructure repository documentation](../README.md)
* [Terraform configuration](../terraform/)
* [GitOps repository](https://github.com/matmajk/devsecops-gitops)
* [GitOps repository documentation](https://github.com/matmajk/devsecops-gitops/blob/master/README.md)
* [Argo CD GitOps documentation](https://github.com/matmajk/devsecops-gitops/blob/master/argocd/README.md)
* [GCP GitOps environment](https://github.com/matmajk/devsecops-gitops/blob/master/argocd/gcp/README.md)
* [GCP bootstrap manifests](https://github.com/matmajk/devsecops-gitops/tree/master/argocd/bootstrap)

### External Documentation

* [Ansible Documentation](https://docs.ansible.com/)
* [Ansible `kubernetes.core` Collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/index.html)
* [Ansible `kubernetes.core.k8s` Module](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html)
* [Ansible `kubernetes.core.k8s_info` Module](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_info_module.html)
* [Argo CD Documentation](https://argo-cd.readthedocs.io/)
* [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
* [Argo CD AppProject Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
* [Argo CD Automated Sync Policy](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
* [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
* [Google Cloud Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
* [Google Cloud Secret Manager - Add a Secret Version](https://cloud.google.com/secret-manager/docs/add-secret-version)
* [Google Cloud CLI Secret Manager Reference](https://cloud.google.com/sdk/gcloud/reference/secrets)
* [Kubernetes Python Client](https://github.com/kubernetes-client/python)
