#!/usr/bin/env bash
set -euo pipefail
# Run only inside this initialized configuration directory with the intended state.
# This writes Terraform state. It does not apply infrastructure changes.
terraform import 'google_compute_network.retail' 'projects/kdt4-3/global/networks/retail-dr-vpc'
terraform import 'google_compute_subnetwork.admin' 'projects/kdt4-3/regions/asia-northeast3/subnetworks/retail-dr-admin-subnet'
terraform import 'google_compute_subnetwork.gke' 'projects/kdt4-3/regions/asia-northeast3/subnetworks/retail-dr-gke-subnet'
terraform import 'google_compute_router.nat' 'projects/kdt4-3/regions/asia-northeast3/routers/retail-dr-router-real'
terraform import 'google_compute_router_nat.retail' 'projects/kdt4-3/regions/asia-northeast3/routers/retail-dr-router-real/retail-dr-nat'
terraform import 'google_compute_firewall.iap_ssh' 'projects/kdt4-3/global/firewalls/allow-iap-ssh'
terraform import 'google_compute_firewall.bastion_ssh_existing' 'projects/kdt4-3/global/firewalls/allow-iap-ssh-bastion'
terraform import 'google_compute_global_address.private_services' 'projects/kdt4-3/global/addresses/google-managed-services-retail-dr-vpc'
terraform import 'google_service_networking_connection.private_services' 'projects/kdt4-3/global/networks/retail-dr-vpc:servicenetworking.googleapis.com'
terraform import 'google_compute_network_peering_routes_config.private_services' 'projects/kdt4-3/global/networks/retail-dr-vpc/networkPeerings/servicenetworking-googleapis-com'
terraform import 'google_service_account.gke_node' 'projects/kdt4-3/serviceAccounts/retail-dr-gke-node@kdt4-3.iam.gserviceaccount.com'
terraform import 'google_project_iam_member.gke_node' 'kdt4-3 roles/container.defaultNodeServiceAccount serviceAccount:retail-dr-gke-node@kdt4-3.iam.gserviceaccount.com'
terraform import 'google_service_account.ops' 'projects/kdt4-3/serviceAccounts/retail-dr-ops@kdt4-3.iam.gserviceaccount.com'
terraform import 'google_project_iam_member.ops' 'kdt4-3 roles/container.developer serviceAccount:retail-dr-ops@kdt4-3.iam.gserviceaccount.com'
terraform import 'google_container_cluster.retail' 'projects/kdt4-3/locations/asia-northeast3-a/clusters/retail-dr-gke'
terraform import 'google_container_node_pool.retail' 'kdt4-3/asia-northeast3-a/retail-dr-gke/retail-dr-pool'
terraform import 'google_compute_instance.bastion' 'projects/kdt4-3/zones/asia-northeast3-a/instances/retail-dr-bastion'
terraform import 'google_compute_disk_resource_policy_attachment.bastion' 'projects/kdt4-3/zones/asia-northeast3-a/disks/retail-dr-bastion/default-schedule-1'
terraform plan
