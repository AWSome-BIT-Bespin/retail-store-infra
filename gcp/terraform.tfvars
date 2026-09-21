project_id = "REPLACE_WITH_YOUR_PROJECT_ID"
name       = "retail-dr"

region     = "asia-northeast3"
node_zones = ["asia-northeast3-a"]

network_cidrs = {
  nodes    = "10.20.0.0/24"
  pods     = "10.21.0.0/20"
  services = "10.22.0.0/24"
  master   = "172.16.0.0/28"
}

# Kubernetes API는 사설 주소로 접근합니다.
private_endpoint_only = true
admin_cidrs           = {}

# 노드 용량은 초기 예시이며, 앱 자원 요구량에 맞춰 조정합니다.
node_machine_type = "e2-standard-2"

node_limits = {
  min = 1
  max = 3
}

# 사설 Kubernetes API에 접근할 관리 VM
create_bastion = true

bastion_project_roles = [
  "roles/container.developer",
]