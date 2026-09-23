terraform_binary = "terraform"

terraform {
  source = "${get_terragrunt_dir()}/../../aws"
  extra_arguments "dev_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=key=infra/dev/terraform.tfstate",
    ]
  }
}