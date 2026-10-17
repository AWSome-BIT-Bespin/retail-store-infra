#!/usr/bin/env bash
set -euo pipefail
# Registers existing resources in state, then runs plan. Does not apply changes.
# First initialize live/gcp/dr and inspect the actual resources and state.
# Requires Bash, Terragrunt, Terraform and Python 3.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "${script_dir}/../live/gcp/dr"

# Resolve the same configuration Terragrunt passes to Terraform. Never eval JSON.
input_values="$(terragrunt render --json | python3 -c '
import json
import os
import sys

inputs = json.load(sys.stdin)["inputs"]
for name in ("TF_CLI_ARGS", "TF_CLI_ARGS_init", "TF_CLI_ARGS_import", "TF_CLI_ARGS_plan"):
    if os.environ.get(name):
        raise ValueError(f"Unset {name} before running this helper; use reviewed individual commands for custom arguments")
for key in ("project_id", "region", "zone"):
    value = inputs[key]
    if not isinstance(value, str) or not value or "\n" in value or "\r" in value:
        raise ValueError(f"Invalid DR input: {key}")
    name = f"TF_VAR_{key}"
    if name in os.environ and os.environ[name] != value:
        raise ValueError(f"{name} conflicts with the DR inputs; clear the override before importing")
    sys.stdout.buffer.write((value + "\n").encode("utf-8"))
')"
mapfile -t dr_values <<< "${input_values}"
project_id="${dr_values[0]}"
region="${dr_values[1]}"
zone="${dr_values[2]}"

terragrunt run -- import 'google_compute_network.retail' "projects/${project_id}/global/networks/retail-dr-vpc"
terragrunt run -- import 'google_compute_subnetwork.gke' "projects/${project_id}/regions/${region}/subnetworks/retail-dr-gke-subnet"
terragrunt run -- import 'google_compute_router.nat' "projects/${project_id}/regions/${region}/routers/retail-dr-router-real"
terragrunt run -- import 'google_compute_router_nat.retail' "projects/${project_id}/regions/${region}/routers/retail-dr-router-real/retail-dr-nat"
terragrunt run -- import 'google_compute_firewall.iap_ssh' "projects/${project_id}/global/firewalls/allow-iap-ssh"
terragrunt run -- import 'google_compute_firewall.bastion_ssh_existing' "projects/${project_id}/global/firewalls/allow-iap-ssh-bastion"
terragrunt run -- import 'google_compute_global_address.private_services' "projects/${project_id}/global/addresses/google-managed-services-retail-dr-vpc"
terragrunt run -- import 'google_service_networking_connection.private_services' "projects/${project_id}/global/networks/retail-dr-vpc:servicenetworking.googleapis.com"
terragrunt run -- import 'google_compute_network_peering_routes_config.private_services' "projects/${project_id}/global/networks/retail-dr-vpc/networkPeerings/servicenetworking-googleapis-com"
terragrunt run -- import 'google_service_account.gke_node' "projects/${project_id}/serviceAccounts/retail-dr-gke-node@${project_id}.iam.gserviceaccount.com"
terragrunt run -- import 'google_project_iam_member.gke_node' "${project_id} roles/container.defaultNodeServiceAccount serviceAccount:retail-dr-gke-node@${project_id}.iam.gserviceaccount.com"
terragrunt run -- import 'google_service_account.ops' "projects/${project_id}/serviceAccounts/retail-dr-ops@${project_id}.iam.gserviceaccount.com"
terragrunt run -- import 'google_project_iam_member.ops' "${project_id} roles/container.developer serviceAccount:retail-dr-ops@${project_id}.iam.gserviceaccount.com"
terragrunt run -- import 'google_container_cluster.retail' "projects/${project_id}/locations/${zone}/clusters/retail-dr-gke"
terragrunt run -- import 'google_container_node_pool.retail' "${project_id}/${zone}/retail-dr-gke/retail-dr-pool"
terragrunt run -- import 'google_compute_instance.bastion' "projects/${project_id}/zones/${zone}/instances/retail-dr-bastion"
terragrunt run -- import 'google_compute_disk_resource_policy_attachment.bastion' "projects/${project_id}/zones/${zone}/disks/retail-dr-bastion/default-schedule-1"
terragrunt run -- plan
