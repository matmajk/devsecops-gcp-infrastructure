.PHONY: 
	help \
	fmt \
	validate \

	bootstrap \
	up \
	down \
	status \
	cluster-create \
	cluster-start \
	cluster-stop \
	cluster-delete \
	cluster-status \
	cluster-wait \

	tooling-status \
	tooling-down \
	tooling-sonar-up \
	tooling-sonar-down \
	tooling-sonar-status \
	tooling-sonar-wait \
	tooling-sonar-logs \
	tooling-jcr-up \
	tooling-jcr-down \
	tooling-jcr-status \
	tooling-jcr-wait \
	tooling-jcr-logs \

	docker-status \
	docker-clean \
	docker-clean-cache \
	docker-clean-volumes

help:
	@echo "Available targets:"
	@echo "  fmt       Format Terraform files"
	@echo "  validate  Validate Terraform configuration"

fmt:
	terraform fmt -recursive terraform/

validate:
	@echo "Terraform validation will be enabled after environment bootstrap."

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
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


bootstrap: cluster-create
	@echo
	@echo "Local Kubernetes infrastructure is ready."

up: cluster-start

down: cluster-stop

status: cluster-status

cluster-create:
	@$(CLUSTER_SCRIPT) create

cluster-start:
	@$(CLUSTER_SCRIPT) start

cluster-stop:
	@$(CLUSTER_SCRIPT) stop

cluster-delete:
	@$(CLUSTER_SCRIPT) delete

cluster-status:
	@$(CLUSTER_SCRIPT) status

cluster-wait:
	@$(CLUSTER_SCRIPT) wait


tooling-status:
	@$(TOOLING_SCRIPT) status

tooling-down:
	@$(TOOLING_SCRIPT) down-all

tooling-sonar-up:
	@$(TOOLING_SCRIPT) up sonarqube

tooling-sonar-down:
	@$(TOOLING_SCRIPT) down sonarqube

tooling-sonar-status:
	@$(TOOLING_SCRIPT) status sonarqube

tooling-sonar-wait:
	@$(TOOLING_SCRIPT) wait sonarqube

tooling-sonar-logs:
	@$(TOOLING_SCRIPT) logs sonarqube

tooling-jcr-up:
	@$(TOOLING_SCRIPT) up jcr

tooling-jcr-down:
	@$(TOOLING_SCRIPT) down jcr

tooling-jcr-status:
	@$(TOOLING_SCRIPT) status jcr

tooling-jcr-wait:
	@$(TOOLING_SCRIPT) wait jcr

tooling-jcr-logs:
	@$(TOOLING_SCRIPT) logs jcr


docker-status:
	@DOCKER_BUILD_CACHE_KEEP_STORAGE="$(DOCKER_BUILD_CACHE_KEEP_STORAGE)" \
		"$(DOCKER_CLEANUP_SCRIPT)" status

docker-clean-cache:
	@DOCKER_BUILD_CACHE_KEEP_STORAGE="$(DOCKER_BUILD_CACHE_KEEP_STORAGE)" \
		"$(DOCKER_CLEANUP_SCRIPT)" cache

docker-clean-volumes:
	@"$(DOCKER_CLEANUP_SCRIPT)" volumes

docker-clean:
	@DOCKER_BUILD_CACHE_KEEP_STORAGE="$(DOCKER_BUILD_CACHE_KEEP_STORAGE)" \
		"$(DOCKER_CLEANUP_SCRIPT)" clean
