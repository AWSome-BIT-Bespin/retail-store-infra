.PHONY: fmt check validate init plan
fmt:
	terraform fmt -recursive
check:
	terraform fmt -check -recursive
	terraform validate
validate:
	terraform validate
init:
	terraform init -lockfile=readonly -backend-config=backend-infra.hcl
plan:
	terraform plan
