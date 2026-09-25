# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

TERRAFORM ?= terraform
TERRAFORM_BOOTSTRAP_DIR ?= terraform/bootstrap
TERRAFORM_PORTFOLIO_DIR ?= terraform/environments/portfolio
TERRAFORM_FOUNDATION_DIR := terraform/foundation

TERRAFORM_BACKEND_CONFIG ?= backend.hcl
TERRAFORM_VAR_FILE ?= terraform.tfvars
TERRAFORM_PLAN_FILE ?= tfplan
TERRAFORM_DESTROY_PLAN_FILE ?= destroy.tfplan
TERRAFORM_LOCK_TIMEOUT ?= 60s

ANSIBLE_DIR := ansible
ANSIBLE_VENV := $(ANSIBLE_DIR)/.venv
ANSIBLE_PLAYBOOK := $(ANSIBLE_VENV)/bin/ansible-playbook
ANSIBLE_GALAXY := $(ANSIBLE_VENV)/bin/ansible-galaxy

KIND_CLUSTER_NAME ?= devsecops-local
KIND_CONFIG ?= local/kind/cluster.yaml

CLUSTER_SCRIPT := $(ROOT_DIR)/scripts/kind-cluster.sh
TOOLING_SCRIPT := $(ROOT_DIR)/scripts/tooling.sh
DOCKER_CLEANUP_SCRIPT := $(ROOT_DIR)/scripts/docker-cleanup.sh

TOOLING_ALLOW_CONCURRENT ?= 0
TOOLING_RETRY_INTERVAL ?= 5
SONARQUBE_READY_TIMEOUT ?= 180
JCR_READY_TIMEOUT ?= 600
DOCKER_BUILD_CACHE_KEEP_STORAGE ?= 5GB

export KIND_CLUSTER_NAME
export KIND_CONFIG
export TOOLING_ALLOW_CONCURRENT
export TOOLING_RETRY_INTERVAL
export SONARQUBE_READY_TIMEOUT
export JCR_READY_TIMEOUT


# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

.PHONY: help
help:
	@echo "Available targets:"
	@echo
	@echo "Terraform:"
	@echo "  terraform-fmt          Format Terraform files"
	@echo "  terraform-fmt-check    Check Terraform formatting"
	@echo "  terraform-init-local   Initialize Terraform roots without remote backend"
	@echo "  terraform-validate     Validate all Terraform root configurations"
	@echo
	@echo "Ansible:"
	@echo "  ansible-setup          Prepare the Ansible environment required for GCP platform bootstrap"
	@echo "  ansible-check          Validate the GCP platform bootstrap Ansible playbook"
	@echo "  gcp-bootstrap          Bootstrap Argo CD and GitOps on the GKE cluster"
	@echo "GCP lifecycle - Portfolio:"
	@echo "  gcp-preflight          Verify required local GCP configuration"
	@echo "  gcp-init               Initialize the portfolio GCS backend"
	@echo "  gcp-plan               Create and save a Terraform execution plan"
	@echo "  gcp-show-plan          Show the saved Terraform execution plan"
	@echo "  gcp-apply              Apply the previously saved Terraform plan"
	@echo "  gcp-destroy-plan       Create and save a Terraform destroy plan"
	@echo "  gcp-show-destroy-plan  Show the saved Terraform destroy plan"
	@echo "  gcp-destroy            Destroy the complete portfolio environment"
	@echo "  gcp-clean-plans        Remove saved Terraform plan files"
	@echo
	@echo "GCP Lifecycle - Persistent Foundation:"
	@echo "  gcp-foundation-preflight   Verify persistent foundation configuration"
	@echo "  gcp-foundation-init        Initialize the persistent foundation backend"
	@echo "  gcp-foundation-plan        Create and save a foundation Terraform plan"
	@echo "  gcp-foundation-show-plan   Show the saved foundation Terraform plan"
	@echo "  gcp-foundation-apply       Apply the saved foundation Terraform plan"
	@echo "  gcp-foundation-clean-plan  Remove the saved foundation Terraform plan"
	@echo
	@echo "Local Kubernetes:"
	@echo "  bootstrap              Create local Kubernetes infrastructure"
	@echo "  up                     Start local Kubernetes cluster"
	@echo "  down                   Stop local Kubernetes cluster"
	@echo "  status                 Show local Kubernetes cluster status"
	@echo "  cluster-create         Create Kind cluster"
	@echo "  cluster-start          Start Kind cluster"
	@echo "  cluster-stop           Stop Kind cluster"
	@echo "  cluster-delete         Delete Kind cluster"
	@echo "  cluster-status         Show Kind cluster status"
	@echo "  cluster-wait           Wait for Kind cluster readiness"
	@echo
	@echo "Local Tooling:"
	@echo "  tooling-status         Show tooling status"
	@echo "  tooling-down           Stop all local tooling"
	@echo "  tooling-sonar-up       Start SonarQube"
	@echo "  tooling-sonar-down     Stop SonarQube"
	@echo "  tooling-sonar-status   Show SonarQube status"
	@echo "  tooling-sonar-wait     Wait for SonarQube readiness"
	@echo "  tooling-sonar-logs     Show SonarQube logs"
	@echo "  tooling-jcr-up         Start JFrog Container Registry"
	@echo "  tooling-jcr-down       Stop JFrog Container Registry"
	@echo "  tooling-jcr-status     Show JFrog Container Registry status"
	@echo "  tooling-jcr-wait       Wait for JFrog Container Registry readiness"
	@echo "  tooling-jcr-logs       Show JFrog Container Registry logs"
	@echo
	@echo "Docker:"
	@echo "  docker-status          Show Docker resource usage"
	@echo "  docker-clean           Run Docker cleanup"
	@echo "  docker-clean-cache     Clean Docker build cache"
	@echo "  docker-clean-volumes   Clean unused Docker volumes"


# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------

.PHONY: terraform-fmt
terraform-fmt:
	$(TERRAFORM) fmt -recursive terraform

.PHONY: terraform-fmt-check
terraform-fmt-check:
	$(TERRAFORM) fmt -check -recursive terraform

.PHONY: terraform-init-local
terraform-init-local:
	$(TERRAFORM) -chdir=$(TERRAFORM_BOOTSTRAP_DIR) init \
		-backend=false \
		-input=false
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) init \
		-backend=false \
		-input=false

.PHONY: terraform-validate
terraform-validate: terraform-init-local
	$(TERRAFORM) -chdir=$(TERRAFORM_BOOTSTRAP_DIR) validate
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) validate


# -----------------------------------------------------------------------------
# Terraform Compatibility Aliases
# -----------------------------------------------------------------------------

.PHONY: fmt
fmt: terraform-fmt

.PHONY: validate
validate: terraform-validate

# -----------------------------------------------------------------------------
# Ansible - GCP PLATFORM BOOTSTRAP
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# GCP PLATFORM BOOTSTRAP
# -----------------------------------------------------------------------------

.PHONY: ansible-setup ansible-check gcp-bootstrap

ansible-setup:
	python3 -m venv $(ANSIBLE_VENV)
	$(ANSIBLE_VENV)/bin/python -m pip install --upgrade pip
	$(ANSIBLE_VENV)/bin/python -m pip install -r $(ANSIBLE_DIR)/requirements.txt
	$(ANSIBLE_GALAXY) collection install -r $(ANSIBLE_DIR)/requirements.yaml

ansible-check:
	@test -x "$(ANSIBLE_PLAYBOOK)" || \
		( echo "ERROR: Ansible virtual environment not found. Run 'make ansible-setup' first."; exit 1 )
	ANSIBLE_CONFIG="$(CURDIR)/$(ANSIBLE_DIR)/ansible.cfg" \
		$(ANSIBLE_PLAYBOOK) \
		-i $(ANSIBLE_DIR)/inventories/portfolio/gcp.yaml \
		$(ANSIBLE_DIR)/playbooks/gke-bootstrap.yaml \
		--syntax-check

gcp-bootstrap:
	@test -x "$(ANSIBLE_PLAYBOOK)" || \
		( echo "ERROR: Ansible virtual environment not found. Run 'make ansible-setup' first."; exit 1 )
	ANSIBLE_CONFIG="$(CURDIR)/$(ANSIBLE_DIR)/ansible.cfg" \
		$(ANSIBLE_PLAYBOOK) \
		-i $(ANSIBLE_DIR)/inventories/portfolio/gcp.yaml \
		$(ANSIBLE_DIR)/playbooks/gke-bootstrap.yaml

# -----------------------------------------------------------------------------
# GCP Lifecycle - portfolio
# -----------------------------------------------------------------------------

.PHONY: gcp-preflight
gcp-preflight:
	@test -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_BACKEND_CONFIG)" || { \
		echo "ERROR: Missing $(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_BACKEND_CONFIG)"; \
		echo "Create it from backend.hcl.example before using GCP lifecycle targets."; \
		exit 1; \
	}
	@test -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_VAR_FILE)" || { \
		echo "ERROR: Missing $(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_VAR_FILE)"; \
		echo "Create it from terraform.tfvars.example before using GCP lifecycle targets."; \
		exit 1; \
	}

.PHONY: gcp-init
gcp-init: gcp-preflight
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) init \
		-backend-config=$(TERRAFORM_BACKEND_CONFIG) \
		-input=false

.PHONY: gcp-plan
gcp-plan: gcp-init
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) plan \
		-input=false \
		-lock-timeout=$(TERRAFORM_LOCK_TIMEOUT) \
		-var-file=$(TERRAFORM_VAR_FILE) \
		-out=$(TERRAFORM_PLAN_FILE)

.PHONY: gcp-show-plan
gcp-show-plan:
	@test -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_PLAN_FILE)" || { \
		echo "ERROR: No saved Terraform plan found."; \
		echo "Run 'make gcp-plan' first."; \
		exit 1; \
	}
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) show \
		$(TERRAFORM_PLAN_FILE)

.PHONY: gcp-apply
gcp-apply:
	@test -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_PLAN_FILE)" || { \
		echo "ERROR: No saved Terraform plan found."; \
		echo "Run 'make gcp-plan' and review it before applying."; \
		exit 1; \
	}
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) apply \
		-input=false \
		-lock-timeout=$(TERRAFORM_LOCK_TIMEOUT) \
		$(TERRAFORM_PLAN_FILE)
	@rm -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_PLAN_FILE)"

.PHONY: gcp-destroy-plan
gcp-destroy-plan: gcp-init
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) plan \
		-destroy \
		-input=false \
		-lock-timeout=$(TERRAFORM_LOCK_TIMEOUT) \
		-var-file=$(TERRAFORM_VAR_FILE) \
		-out=$(TERRAFORM_DESTROY_PLAN_FILE)

.PHONY: gcp-show-destroy-plan
gcp-show-destroy-plan:
	@test -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_DESTROY_PLAN_FILE)" || { \
		echo "ERROR: No saved Terraform destroy plan found."; \
		echo "Run 'make gcp-destroy-plan' first."; \
		exit 1; \
	}
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) show \
		$(TERRAFORM_DESTROY_PLAN_FILE)

.PHONY: gcp-destroy
gcp-destroy: gcp-init
	@echo
	@echo "WARNING: This will destroy the ephemeral portfolio runtime environment."
	@echo "The Terraform bootstrap state bucket and persistent foundation are managed separately and will remain." remain."
	@echo
	$(TERRAFORM) -chdir=$(TERRAFORM_PORTFOLIO_DIR) destroy \
		-lock-timeout=$(TERRAFORM_LOCK_TIMEOUT) \
		-var-file=$(TERRAFORM_VAR_FILE)
	@rm -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_PLAN_FILE)"
	@rm -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_DESTROY_PLAN_FILE)"

.PHONY: gcp-clean-plans
gcp-clean-plans:
	@rm -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_PLAN_FILE)"
	@rm -f "$(TERRAFORM_PORTFOLIO_DIR)/$(TERRAFORM_DESTROY_PLAN_FILE)"

# -----------------------------------------------------------------------------
# GCP lifecycle - persistent foundation
# -----------------------------------------------------------------------------

.PHONY: gcp-foundation-preflight
gcp-foundation-preflight:
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { \
		echo "ERROR: Terraform is not available."; \
		exit 1; \
	}
	@test -f "$(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_BACKEND_CONFIG)" || { \
		echo "ERROR: Missing foundation backend configuration."; \
		echo "Expected: $(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_BACKEND_CONFIG)"; \
		exit 1; \
	}
	@test -f "$(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_VAR_FILE)" || { \
		echo "ERROR: Missing foundation Terraform variable file."; \
		echo "Expected: $(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_VAR_FILE)"; \
		exit 1; \
	}

.PHONY: gcp-foundation-init
gcp-foundation-init: gcp-foundation-preflight
	$(TERRAFORM) -chdir=$(TERRAFORM_FOUNDATION_DIR) init \
		-input=false \
		-backend-config=$(TERRAFORM_BACKEND_CONFIG)

.PHONY: gcp-foundation-plan
gcp-foundation-plan: gcp-foundation-init
	$(TERRAFORM) -chdir=$(TERRAFORM_FOUNDATION_DIR) plan \
		-input=false \
		-lock-timeout=$(TERRAFORM_LOCK_TIMEOUT) \
		-var-file=$(TERRAFORM_VAR_FILE) \
		-out=$(TERRAFORM_PLAN_FILE)

.PHONY: gcp-foundation-show-plan
gcp-foundation-show-plan:
	@test -f "$(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_PLAN_FILE)" || { \
		echo "ERROR: No saved foundation Terraform plan found."; \
		echo "Run 'make gcp-foundation-plan' first."; \
		exit 1; \
	}
	$(TERRAFORM) -chdir=$(TERRAFORM_FOUNDATION_DIR) show \
		$(TERRAFORM_PLAN_FILE)

.PHONY: gcp-foundation-apply
gcp-foundation-apply:
	@test -f "$(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_PLAN_FILE)" || { \
		echo "ERROR: No saved foundation Terraform plan found."; \
		echo "Run 'make gcp-foundation-plan' first."; \
		exit 1; \
	}
	$(TERRAFORM) -chdir=$(TERRAFORM_FOUNDATION_DIR) apply \
		-input=false \
		-lock-timeout=$(TERRAFORM_LOCK_TIMEOUT) \
		$(TERRAFORM_PLAN_FILE)
	@rm -f "$(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_PLAN_FILE)"

.PHONY: gcp-foundation-clean-plan
gcp-foundation-clean-plan:
	@rm -f "$(TERRAFORM_FOUNDATION_DIR)/$(TERRAFORM_PLAN_FILE)"

# -----------------------------------------------------------------------------
# Local Kubernetes Lifecycle
# -----------------------------------------------------------------------------

.PHONY: bootstrap
bootstrap: cluster-create
	@echo
	@echo "Local Kubernetes infrastructure is ready."

.PHONY: up
up: cluster-start

.PHONY: down
down: cluster-stop

.PHONY: status
status: cluster-status


# -----------------------------------------------------------------------------
# Kind Cluster
# -----------------------------------------------------------------------------

.PHONY: cluster-create
cluster-create:
	@$(CLUSTER_SCRIPT) create

.PHONY: cluster-start
cluster-start:
	@$(CLUSTER_SCRIPT) start

.PHONY: cluster-stop
cluster-stop:
	@$(CLUSTER_SCRIPT) stop

.PHONY: cluster-delete
cluster-delete:
	@$(CLUSTER_SCRIPT) delete

.PHONY: cluster-status
cluster-status:
	@$(CLUSTER_SCRIPT) status

.PHONY: cluster-wait
cluster-wait:
	@$(CLUSTER_SCRIPT) wait


# -----------------------------------------------------------------------------
# Local Tooling
# -----------------------------------------------------------------------------

.PHONY: tooling-status
tooling-status:
	@$(TOOLING_SCRIPT) status

.PHONY: tooling-down
tooling-down:
	@$(TOOLING_SCRIPT) down-all


# -----------------------------------------------------------------------------
# SonarQube
# -----------------------------------------------------------------------------

.PHONY: tooling-sonar-up
tooling-sonar-up:
	@$(TOOLING_SCRIPT) up sonarqube

.PHONY: tooling-sonar-down
tooling-sonar-down:
	@$(TOOLING_SCRIPT) down sonarqube

.PHONY: tooling-sonar-status
tooling-sonar-status:
	@$(TOOLING_SCRIPT) status sonarqube

.PHONY: tooling-sonar-wait
tooling-sonar-wait:
	@$(TOOLING_SCRIPT) wait sonarqube

.PHONY: tooling-sonar-logs
tooling-sonar-logs:
	@$(TOOLING_SCRIPT) logs sonarqube


# -----------------------------------------------------------------------------
# JFrog Container Registry
# -----------------------------------------------------------------------------

.PHONY: tooling-jcr-up
tooling-jcr-up:
	@$(TOOLING_SCRIPT) up jcr

.PHONY: tooling-jcr-down
tooling-jcr-down:
	@$(TOOLING_SCRIPT) down jcr

.PHONY: tooling-jcr-status
tooling-jcr-status:
	@$(TOOLING_SCRIPT) status jcr

.PHONY: tooling-jcr-wait
tooling-jcr-wait:
	@$(TOOLING_SCRIPT) wait jcr

.PHONY: tooling-jcr-logs
tooling-jcr-logs:
	@$(TOOLING_SCRIPT) logs jcr


# -----------------------------------------------------------------------------
# Docker Cleanup
# -----------------------------------------------------------------------------

.PHONY: docker-status
docker-status:
	@DOCKER_BUILD_CACHE_KEEP_STORAGE="$(DOCKER_BUILD_CACHE_KEEP_STORAGE)" \
		"$(DOCKER_CLEANUP_SCRIPT)" status

.PHONY: docker-clean-cache
docker-clean-cache:
	@DOCKER_BUILD_CACHE_KEEP_STORAGE="$(DOCKER_BUILD_CACHE_KEEP_STORAGE)" \
		"$(DOCKER_CLEANUP_SCRIPT)" cache

.PHONY: docker-clean-volumes
docker-clean-volumes:
	@"$(DOCKER_CLEANUP_SCRIPT)" volumes

.PHONY: docker-clean
docker-clean:
	@DOCKER_BUILD_CACHE_KEEP_STORAGE="$(DOCKER_BUILD_CACHE_KEEP_STORAGE)" \
		"$(DOCKER_CLEANUP_SCRIPT)" clean