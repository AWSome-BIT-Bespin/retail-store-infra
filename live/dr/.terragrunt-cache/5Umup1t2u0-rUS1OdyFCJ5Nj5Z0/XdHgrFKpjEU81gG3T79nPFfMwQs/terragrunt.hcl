terraform_binary = "terraform"

terraform {
  source = "${get_terragrunt_dir()}/../../gcp"

  extra_arguments "dr_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=prefix=retail-store/gcp/dr",
    ]
  }
}