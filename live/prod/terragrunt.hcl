terraform_binary = "terraform"

terraform {
  source = "${get_terragrunt_dir()}/../../aws"
  extra_arguments "prod_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=key=infra/prod/terraform.tfstate",
    ]
  }
}