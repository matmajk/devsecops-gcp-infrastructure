.PHONY: help fmt validate

help:
	@echo "Available targets:"
	@echo "  fmt       Format Terraform files"
	@echo "  validate  Validate Terraform configuration"

fmt:
	terraform fmt -recursive terraform/

validate:
	@echo "Terraform validation will be enabled after environment bootstrap."
