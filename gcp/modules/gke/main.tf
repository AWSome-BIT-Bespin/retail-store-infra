resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = "${var.name}-gke"
  location = var.node_zones[0]

  network         = var.network_id
  subnetwork      = var.subnetwork_id
  networking_mode = "VPC_NATIVE"

  # 기본 노드 풀은 제거하고 아래 별도 노드 풀을 사용합니다.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = true

  release_channel {
    channel = "REGULAR"
  }

  # 네트워크 모듈에서 만든 Pod / Service IP 범위
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.service_range_name
  }

  # 노드는 외부 IP 없이 실행합니다.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.private_endpoint_only
    master_ipv4_cidr_block   = var.cidrs.master
  }

  # Kubernetes API 접근을 허용할 관리자 네트워크
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.admin_cidrs

      content {
        display_name = cidr_blocks.key
        cidr_block   = cidr_blocks.value
      }
    }
  }

  # Pod에서 Google Cloud 권한을 사용할 수 있는 기반 설정
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # 생성 중 잠시 사용하는 기본 노드 풀의 서비스 계정
  node_config {
    service_account = var.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_container_node_pool" "this" {
  project  = var.project_id
  name     = "${var.name}-nodes"
  location = var.node_zones[0]
  cluster  = google_container_cluster.this.name

  # 해당 존에서 노드 1개로 시작합니다.
  initial_node_count = 1

  # 전체 노드 수 기준 자동 확장 범위
  autoscaling {
    total_min_node_count = var.node_limits.min
    total_max_node_count = var.node_limits.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    service_account = var.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}