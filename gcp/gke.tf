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

  dns_config {
  cluster_dns = "KUBE_DNS"
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
    prevent_destroy = false
    ignore_changes  = [initial_node_count, remove_default_node_pool]
  }
}

resource "google_container_node_pool" "retail" {
  name              = "retail-dr-pool"
  location          = "asia-northeast3-a"
  cluster           = google_container_cluster.retail.name
  node_locations    = ["asia-northeast3-a"]
  node_count        = 2
  max_pods_per_node = 110

  # No autoscaling block: the observed node pool has autoscaling disabled.
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  queued_provisioning {
    enabled = false
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

  advanced_machine_features {
    enable_nested_virtualization = false
    threads_per_core             = 0
    }

  ephemeral_storage_local_ssd_config {
    local_ssd_count  = 0
    data_cache_count = 0
    }

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
    prevent_destroy = false
    # Imported API returns an empty policy with type=null. Terraform requires
    # a real type if configured; leave only this unused policy unmanaged.
    ignore_changes = [placement_policy]
  }
}
