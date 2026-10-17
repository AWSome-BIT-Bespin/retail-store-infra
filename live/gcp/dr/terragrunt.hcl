terraform_binary = "terraform"

terraform {
  source = "${get_terragrunt_dir()}/../../../gcp"

  extra_arguments "dr_backend" {
    commands = ["init"]

    arguments = [
      "-backend-config=prefix=retail-store/gcp/dr",
    ]
  }
}
# Single DR environment. These are the values from the existing GCP code,
# not the obsolete examples retained in gcp/legacy.tfvars.
inputs = {
  project_id = "kdt4-3"
  region     = "asia-northeast3"
  zone       = "asia-northeast3-a"

  gke_subnet_cidr    = "10.20.0.0/20"
  gke_pod_cidr       = "10.90.0.0/17"
  gke_pod_range_name = "gke-retail-dr-gke-pods-89de90ed"

  private_services_address       = "10.40.0.0"
  private_services_prefix_length = 16

  gke_node_count        = 2
  gke_node_machine_type = "n2d-standard-2"
  gke_node_disk_size_gb = 50
  bastion_machine_type  = "e2-medium"
}
