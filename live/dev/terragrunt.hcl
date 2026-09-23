terraform_binary = "terraform"

terraform {
  extra_arguments "dev_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=key=infra/dev/terraform.tfstate",
    ]
  }
}