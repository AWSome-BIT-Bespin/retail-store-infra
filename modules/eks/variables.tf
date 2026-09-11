variable "cluster_name" {
  description = "EKS 클러스터 이름."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes 버전. 변경 시 지원 여부를 별도로 확인하세요."
  type        = string
}

variable "cluster_role_name" {
  description = "EKS 서비스 IAM 역할 이름."
  type        = string
}

variable "node_role_name" {
  description = "노드 EC2 IAM 역할 이름."
  type        = string
}

variable "admin_principal_arn" {
  description = "EKS 관리자 IAM 사용자 또는 역할 ARN."
  type        = string
}

variable "public_access_cidrs" {
  description = "API 공개 엔드포인트 접근 CIDR. 현재 값 보존; 팀 관리망 CIDR로 별도 제한하세요."
  type        = list(string)
  validation {
    condition     = length(var.public_access_cidrs) > 0 && alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "유효한 CIDR을 하나 이상 지정하세요."
  }
}

variable "node_group_name" {
  description = "Managed Node Group 이름."
  type        = string
}

variable "node_scaling" {
  description = "노드 수. Autoscaler 도입 시 desired_size 관리 주체를 먼저 정하세요."
  type        = object({ desired_size = number, min_size = number, max_size = number })
  validation {
    condition     = var.node_scaling.min_size >= 0 && var.node_scaling.max_size > 0 && var.node_scaling.min_size <= var.node_scaling.desired_size && var.node_scaling.desired_size <= var.node_scaling.max_size && alltrue([for n in values(var.node_scaling) : floor(n) == n])
    error_message = "정수 노드 수이며 min <= desired <= max 이어야 합니다."
  }
}

variable "node_instance_types" {
  description = "null이면 기존처럼 AWS 기본 선택을 유지합니다. 기존 노드 유형 확인 후 고정하세요."
  type        = list(string)
}

variable "node_labels" {
  description = "기존 worldload 키도 보존합니다. selector 사용 여부 확인 후 수정하세요."
  type        = map(string)
}

variable "cluster_tags" {
  description = "기존 EKS 태그."
  type        = map(string)
}

variable "addon_versions" {
  description = "명시적으로 고정할 애드온 버전. 빈 map이면 기존 동작을 유지합니다."
  type        = map(string)
  validation {
    condition     = alltrue([for k in keys(var.addon_versions) : contains(["vpc-cni", "kube-proxy", "coredns"], k)])
    error_message = "vpc-cni, kube-proxy, coredns만 지정할 수 있습니다."
  }
}

variable "subnet_ids" {
  description = "서로 다른 AZ의 앱용 private 서브넷 ID."
  type        = list(string)
}

variable "bastion_principal_arn" {
  description = "EKS 접근을 허용할 Bastion IAM 역할 ARN"
  type        = string
}

variable "vpc_id" {
  
  type        = string
}

# variable "cp_sg.id" {
#   type        = string
# }