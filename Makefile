.PHONY: help fmt validate

help:
	@echo "Available targets:"
	@echo "  fmt       Format Terraform files"
	@echo "  validate  Validate Terraform configuration"

fmt:
	terraform fmt -recursive terraform/

validate:
	@echo "Terraform validation will be enabled after environment bootstrap."

KIND_CLUSTER_NAME ?= devsecops-local
KIND_CONFIG ?= local/kind/cluster.yaml

export KIND_CLUSTER_NAME
export KIND_CONFIG

.PHONY: \
	bootstrap \
	up \
	down \
	status \
	cluster-create \
	cluster-start \
	cluster-stop \
	cluster-delete \
	cluster-status \
	cluster-wait

bootstrap: cluster-create
	@echo
	@echo "Local Kubernetes infrastructure is ready."

up: cluster-start

down: cluster-stop

status: cluster-status

cluster-create:
	./scripts/kind-cluster.sh create

cluster-start:
	./scripts/kind-cluster.sh start

cluster-stop:
	./scripts/kind-cluster.sh stop

cluster-delete:
	./scripts/kind-cluster.sh delete

cluster-status:
	./scripts/kind-cluster.sh status

cluster-wait:
	./scripts/kind-cluster.sh wait