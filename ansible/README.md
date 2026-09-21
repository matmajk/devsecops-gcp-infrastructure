# Ansible

Ansible configuration used to bootstrap and configure platform components after infrastructure provisioning.

For the GCP environment, Terraform provisions the GKE infrastructure and Ansible performs the initial platform bootstrap required before Argo CD can take over workload reconciliation.

## Table of Contents

* [Architecture](#architecture)
* [Directory Structure](#directory-structure)
* [Requirements](#requirements)
* [GKE Platform Bootstrap](#gke-platform-bootstrap)
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
         GKE
          ↓
       Ansible
          ↓
  Argo CD bootstrap
          ↓
GitOps root Application
          ↓
  Argo CD workloads
```

Responsibilities are intentionally separated:

* **Terraform** provisions GCP infrastructure.
* **Ansible** bootstraps platform components required before GitOps can operate.
* **Argo CD** reconciles Kubernetes workloads from the GitOps repository.
* **CI pipelines** build, test and promote artifacts but do not deploy directly to Kubernetes.

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
│       │   └── all.yml
│       └── hosts.yml.example
├── playbooks/
│   ├── tooling.yml
│   └── gke-bootstrap.yaml
└── roles/
    ├── argocd/
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

The existing tooling roles are kept separate from the GKE bootstrap flow.

## Requirements

The GKE bootstrap uses:

* Ansible Core
* `kubernetes.core` Ansible collection
* Python Kubernetes client
* access to the target GKE cluster through the current kubeconfig
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

The virtual environment is used to avoid modifying the system Python installation and ensures that the Kubernetes Python client is available to Ansible modules.

## GKE Platform Bootstrap

The GKE bootstrap entrypoint is:

```text
ansible/playbooks/gke-bootstrap.yaml
```

The playbook runs locally and uses the active Kubernetes context:

```yaml
hosts: localhost
connection: local
```

It does not connect directly to GKE worker nodes over SSH.

The bootstrap sequence is:

```text
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

Ansible stops after the GitOps root Application has been created.

Application workloads such as Online Boutique are not deployed directly by Ansible.

They are reconciled by Argo CD from the GitOps repository.

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

The GitOps repository location is supplied by the GKE bootstrap playbook through:

```yaml
gitops_repo_path
```

The role then resolves the required manifests relative to that repository:

```text
argocd/bootstrap/platform-bootstrap-gcp-project.yaml
argocd/bootstrap/platform-root-gcp.yaml
```

The GitOps repository therefore remains the source of truth for the Argo CD bootstrap Applications and AppProjects.

## Usage

### Prepare Ansible

The Ansible environment only needs to be prepared when the virtual environment or dependencies are missing:

```bash
make ansible-setup
```

### Validate the Playbook

Run the Ansible syntax validation:

```bash
make ansible-check
```

### Verify GKE Connectivity

Before bootstrapping Argo CD, verify that the current kubeconfig can access the cluster:

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

The command must succeed before running the Ansible bootstrap.

### Bootstrap the GCP Platform

Run:

```bash
make gcp-bootstrap
```

This executes:

```text
ansible/playbooks/gke-bootstrap.yaml
```

using the repository Ansible configuration and virtual environment.

The expected ownership flow is:

```text
         GKE
          ↓
       Ansible
          ↓
       Argo CD
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

### Kubernetes Connectivity

Verify access to the GKE API:

```bash
kubectl get nodes
```

### Argo CD

After bootstrap, inspect the Argo CD namespace:

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

* Repository infrastructure documentation: [Root Infrastucture](../README.md)
* Terraform configuration: [Terraform](../terraform/)
* GitOps repository: `devsecops-gitops`
* GCP GitOps bootstrap manifests: `argocd/bootstrap/`
* GCP Argo CD desired state: `argocd/gcp/`



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
* [Kubernetes Python Client](https://github.com/kubernetes-client/python)
