terraform_binary = "terraform"

terraform {
  source = "${get_terragrunt_dir()}/../../aws"
  extra_arguments "stg_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=key=infra/stg/terraform.tfstate",
    ]
  }
}