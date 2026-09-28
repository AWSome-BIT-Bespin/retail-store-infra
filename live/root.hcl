terraform_binary = "terraform"

locals {
  state_path = trimprefix(path_relative_to_include(), "aws/")
}

terraform {
  source = "${get_terragrunt_dir()}/../../../aws"

  extra_arguments "environment_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=key=${local.state_path}/terraform.tfstate",
    ]
  }
}