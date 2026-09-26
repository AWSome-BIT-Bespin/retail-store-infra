terraform_binary = "terraform"

terraform {
  source = "${get_repo_root()}/aws"

  extra_arguments "environment_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=key=infra/${path_relative_to_include()}/terraform.tfstate",
    ]
  }
}