# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

TERRAFORM ?= terraform
TERRAFORM_PORTFOLIO_DIR ?= terraform/environments/portfolio
TERRAFORM_BOOTSTRAP_DIR ?= terraform/bootstrap

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