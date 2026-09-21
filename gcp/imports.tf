import {
  to = google_compute_network.retail
  id = "projects/kdt4-3/global/networks/retail-dr-vpc"
}
import {
  to = google_compute_subnetwork.gke
  id = "projects/kdt4-3/regions/asia-northeast3/subnetworks/retail-dr-gke-subnet"
}
import {
  to = google_compute_router.nat
  id = "projects/kdt4-3/regions/asia-northeast3/routers/retail-dr-router-real"
}
import {
  to = google_compute_router_nat.retail
  id = "projects/kdt4-3/regions/asia-northeast3/routers/retail-dr-router-real/retail-dr-nat"
}
import {
  to = google_compute_firewall.iap_ssh
  id = "projects/kdt4-3/global/firewalls/allow-iap-ssh"
}
import {
  to = google_compute_firewall.bastion_ssh_existing
  id = "projects/kdt4-3/global/firewalls/allow-iap-ssh-bastion"
}
import {
  to = google_compute_global_address.private_services
  id = "projects/kdt4-3/global/addresses/google-managed-services-retail-dr-vpc"
}
import {
  to = google_service_networking_connection.private_services
  id = "projects/kdt4-3/global/networks/retail-dr-vpc:servicenetworking.googleapis.com"
}
import {
  to = google_compute_network_peering_routes_config.private_services
  id = "projects/kdt4-3/global/networks/retail-dr-vpc/networkPeerings/servicenetworking-googleapis-com"
}
import {
  to = google_service_account.gke_node
  id = "projects/kdt4-3/serviceAccounts/retail-dr-gke-node@kdt4-3.iam.gserviceaccount.com"
}
import {
  to = google_project_iam_member.gke_node
  id = "kdt4-3 roles/container.defaultNodeServiceAccount serviceAccount:retail-dr-gke-node@kdt4-3.iam.gserviceaccount.com"
}
import {
  to = google_service_account.ops
  id = "projects/kdt4-3/serviceAccounts/retail-dr-ops@kdt4-3.iam.gserviceaccount.com"
}
import {
  to = google_project_iam_member.ops
  id = "kdt4-3 roles/container.developer serviceAccount:retail-dr-ops@kdt4-3.iam.gserviceaccount.com"
}
import {
  to = google_container_cluster.retail
  id = "projects/kdt4-3/locations/asia-northeast3-a/clusters/retail-dr-gke"
}
import {
  to = google_container_node_pool.retail
  id = "kdt4-3/asia-northeast3-a/retail-dr-gke/retail-dr-pool"
}
import {
  to = google_compute_instance.bastion
  id = "projects/kdt4-3/zones/asia-northeast3-a/instances/retail-dr-bastion"
}
import {
  to = google_compute_disk_resource_policy_attachment.bastion
  id = "projects/kdt4-3/zones/asia-northeast3-a/disks/retail-dr-bastion/default-schedule-1"
}
