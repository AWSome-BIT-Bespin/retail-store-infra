# GCP 현재 구성: 파일별 복사·붙여넣기

README.md의 인수 순서를 먼저 확인하세요. 현재 프로젝트의 기존 리소스를 import하기 위한 독립 구성입니다. 기존 module 기반 gcp 코드에 추가로 합쳐 넣지 마세요. 실제 plan은 아직 실행하지 않았습니다.

## versions.tf

```hcl
terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.3.0"
    }
  }
}

provider "google" {
  project = "kdt4-3"
  region  = "asia-northeast3"
  zone    = "asia-northeast3-a"

  # Import existing resources without introducing a Terraform attribution label.
  add_terraform_attribution_label = false
}
```

## network.tf

```hcl
# 2026-09-18 GCP console snapshot. Import the existing resources first.
resource "google_compute_network" "retail" {
  name                    = "retail-dr-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  mtu                     = 1460

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_subnetwork" "admin" {
  name                     = "retail-dr-admin-subnet"
  region                   = "asia-northeast3"
  network                  = google_compute_network.retail.id
  ip_cidr_range            = "10.10.0.0/20"
  stack_type               = "IPV4_ONLY"
  private_ip_google_access = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_subnetwork" "gke" {
  name                     = "retail-dr-gke-subnet"
  region                   = "asia-northeast3"
  network                  = google_compute_network.retail.id
  ip_cidr_range            = "10.20.0.0/20"
  stack_type               = "IPV4_ONLY"
  private_ip_google_access = true

  # Existing GKE-created range. This is the range the current cluster uses.
  secondary_ip_range {
    range_name              = "gke-retail-dr-gke-pods-89de90ed"
    ip_cidr_range           = "10.90.0.0/17"
    reserved_internal_range = "networkconnectivity.googleapis.com/projects/kdt4-3/locations/global/internalRanges/gke-retail-dr-gke-pods-89de90ed"
  }

  # These two ranges exist but are not used by the current cluster.
  secondary_ip_range {
    range_name    = "retail-dr-pods"
    ip_cidr_range = "10.24.0.0/16"
  }

  secondary_ip_range {
    range_name    = "retail-dr-services"
    ip_cidr_range = "10.25.0.0/20"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_router" "nat" {
  name    = "retail-dr-router-real"
  region  = "asia-northeast3"
  network = google_compute_network.retail.id
}

resource "google_compute_router_nat" "retail" {
  name                                = "retail-dr-nat"
  region                              = "asia-northeast3"
  router                              = google_compute_router.nat.name
  nat_ip_allocate_option              = "AUTO_ONLY"
  auto_network_tier                   = "PREMIUM"
  source_subnetwork_ip_ranges_to_nat  = "LIST_OF_SUBNETWORKS"
  enable_dynamic_port_allocation      = false
  enable_endpoint_independent_mapping = false

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = false
    filter = "ALL"
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.retail.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  # Current rule applies to every VM in this VPC.
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "bastion_ssh_existing" {
  name      = "allow-iap-ssh-bastion"
  network   = google_compute_network.retail.id
  direction = "INGRESS"
  priority  = 1000

  # Exact existing configuration; this is NOT limited to IAP despite its name.
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["retail-dr-bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

## private-services.tf

```hcl
resource "google_compute_global_address" "private_services" {
  name          = "google-managed-services-retail-dr-vpc"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  address       = "10.40.0.0"
  prefix_length = 16
  network       = google_compute_network.retail.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.retail.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_network_peering_routes_config" "private_services" {
  network                             = google_compute_network.retail.name
  peering                             = google_service_networking_connection.private_services.peering
  import_custom_routes                = true
  export_custom_routes                = true
  import_subnet_routes_with_public_ip = false
  export_subnet_routes_with_public_ip = false
}
```

## iam.tf

```hcl
resource "google_service_account" "gke_node" {
  account_id   = "retail-dr-gke-node"
  display_name = "retail-dr-gke-node"
}

resource "google_project_iam_member" "gke_node" {
  project = "kdt4-3"
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_service_account" "ops" {
  account_id   = "retail-dr-ops"
  display_name = "retail-dr-ops"
}

resource "google_project_iam_member" "ops" {
  project = "kdt4-3"
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.ops.email}"
}
```

## gke.tf

```hcl
resource "google_container_cluster" "retail" {
  name                      = "retail-dr-gke"
  location                  = "asia-northeast3-a"
  network                   = google_compute_network.retail.id
  subnetwork                = google_compute_subnetwork.gke.id
  networking_mode           = "VPC_NATIVE"
  datapath_provider         = "LEGACY_DATAPATH"
  default_max_pods_per_node = 110
  enable_shielded_nodes     = true
  deletion_protection       = true

  # Manage the existing pool separately. This count is only for creation.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name = "gke-retail-dr-gke-pods-89de90ed"
    stack_type                   = "IPV4"

    # Existing Service CIDR: 34.118.224.0/20 (GKE-managed).
    # Do not assign the unused "retail-dr-services" range here.
  }

  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false

    master_global_access_config {
      enabled = false
    }
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = false
    }
    ip_endpoints_config {
      enabled = true
    }
  }

  # Current configuration has no authorized-networks restriction,
  # no Workload Identity pool, and no node auto-provisioning.
  cluster_autoscaling {
    enabled             = false
    autoscaling_profile = "BALANCED"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    dns_cache_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    network_policy_config {
      disabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS", "STORAGE", "HPA", "POD", "DAEMONSET",
      "DEPLOYMENT", "STATEFULSET", "CADVISOR", "KUBELET", "DCGM", "JOBSET",
    ]
    managed_prometheus {
      enabled = true
      auto_monitoring_config {
        scope = "NONE"
      }
    }
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_DISABLED"
  }

  lifecycle {
    prevent_destroy = true
    # The API does not retain the bootstrap/default-pool count on import.
    ignore_changes = [initial_node_count]
  }
}

resource "google_container_node_pool" "retail" {
  name              = "retail-dr-pool"
  location          = "asia-northeast3-a"
  cluster           = google_container_cluster.retail.name
  node_locations    = ["asia-northeast3-a"]
  node_count        = 1
  max_pods_per_node = 110

  # No autoscaling block: the observed node pool has autoscaling disabled.
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Existing setting: an extra node may run during an upgrade.
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  network_config {
    enable_private_nodes = false
    create_pod_range     = false
    pod_range            = "gke-retail-dr-gke-pods-89de90ed"
  }

  node_config {
    machine_type    = "n2d-standard-2"
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/userinfo.email",
    ]

    metadata = {
      "disable-legacy-endpoints" = "true"
    }

    resource_labels = {
      "goog-gke-node-pool-provisioning-model" = "on-demand"
    }

    confidential_nodes {
      enabled                    = true
      confidential_instance_type = "SEV"
    }

    shielded_instance_config {
      enable_secure_boot          = false
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_iam_member.gke_node]

  lifecycle {
    prevent_destroy = true
  }
}
```

## compute.tf

```hcl
resource "google_compute_instance" "bastion" {
  name                = "retail-dr-bastion"
  zone                = "asia-northeast3-a"
  machine_type        = "e2-medium"
  deletion_protection = false

  # Exact current spelling. See README before correcting this tag.
  tags = ["retail-dr-basion"]
  labels = {
    "goog-ops-agent-policy" = "v2-template-1-7-0"
  }

  boot_disk {
    auto_delete = true
    device_name = "retail-dr-bastion"
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-13-trixie-v20260908"
      type  = "pd-balanced"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gke.id
    stack_type = "IPV4_ONLY"
    # No access_config: no external IP.
  }

  service_account {
    email  = google_service_account.ops.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    "enable-osconfig" = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    provisioning_model  = "STANDARD"
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  depends_on = [google_project_iam_member.ops]

  lifecycle {
    prevent_destroy = true
    # Console browser-SSH writes short-lived public keys to this single key.
    ignore_changes = [metadata["ssh-keys"]]
  }
}

resource "google_compute_instance" "admin" {
  name                = "retail-dr-admin"
  zone                = "asia-northeast3-a"
  machine_type        = "e2-micro"
  deletion_protection = false

  boot_disk {
    auto_delete = true
    device_name = "retail-dr-admin"
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-v20260908"
      type  = "pd-standard"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.admin.id
    stack_type = "IPV4_ONLY"
    access_config {
      network_tier = "PREMIUM"
      # Existing external address is ephemeral; do not declare it as static.
    }
  }

  # Existing shared Compute Engine service account; do not manage its IAM here.
  service_account {
    email = "314387807668-compute@developer.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/pubsub",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    provisioning_model  = "STANDARD"
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [metadata["ssh-keys"]]
  }
}

# This policy is shared with code-server. Read it without taking ownership.
data "google_compute_resource_policy" "shared_snapshot" {
  name   = "default-schedule-1"
  region = "asia-northeast3"
}

resource "google_compute_disk_resource_policy_attachment" "bastion" {
  name = data.google_compute_resource_policy.shared_snapshot.name
  disk = google_compute_instance.bastion.name
  zone = "asia-northeast3-a"
}
```

## outputs.tf

```hcl
output "cluster_name" {
  value = google_container_cluster.retail.name
}

output "bastion_internal_ip" {
  value = google_compute_instance.bastion.network_interface[0].network_ip
}

output "admin_external_ip" {
  value = google_compute_instance.admin.network_interface[0].access_config[0].nat_ip
}

output "bastion_ssh_command" {
  value = "gcloud compute ssh retail-dr-bastion --project=kdt4-3 --zone=asia-northeast3-a --tunnel-through-iap"
}

output "gke_credentials_from_bastion" {
  value = "gcloud container clusters get-credentials retail-dr-gke --project=kdt4-3 --zone=asia-northeast3-a --internal-ip"
}
```

## imports.tf

```hcl
import {
  to = google_compute_network.retail
  id = "projects/kdt4-3/global/networks/retail-dr-vpc"
}
import {
  to = google_compute_subnetwork.admin
  id = "projects/kdt4-3/regions/asia-northeast3/subnetworks/retail-dr-admin-subnet"
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
  to = google_compute_instance.admin
  id = "projects/kdt4-3/zones/asia-northeast3-a/instances/retail-dr-admin"
}
import {
  to = google_compute_disk_resource_policy_attachment.bastion
  id = "projects/kdt4-3/zones/asia-northeast3-a/disks/retail-dr-bastion/default-schedule-1"
}
```
