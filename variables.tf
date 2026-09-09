variable "aws_region" {
  description = "AWS 리전."
  type        = string
}

variable "vpc_cidr" {
  description = "기존 VPC IPv4 CIDR."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "유효한 IPv4 CIDR을 입력하세요."
  }
}

variable "availability_zones" {
  description = "두 AZ 이름. 빈 목록이면 기존 코드처럼 available AZ 앞 두 개를 사용합니다."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 0 || (length(var.availability_zones) == 2 && length(toset(var.availability_zones)) == 2)
    error_message = "AZ는 비워두거나 서로 다른 두 개를 지정하세요."
  }
}

variable "subnet_cidrs" {
  description = "역할별 두 서브넷의 IPv4 CIDR."
  type        = object({ public_a = string, public_b = string, app_a = string, app_b = string, db_a = string, db_b = string })
  validation {
    condition     = alltrue([for cidr in values(var.subnet_cidrs) : can(cidrnetmask(cidr))])
    error_message = "모든 서브넷은 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "eks_cluster_name" {
  description = "EKS 클러스터 이름."
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes 버전. 변경 시 지원 여부를 별도로 확인하세요."
  type        = string
}

variable "eks_cluster_role_name" {
  description = "EKS 서비스 IAM 역할 이름."
  type        = string
}

variable "eks_node_role_name" {
  description = "노드 EC2 IAM 역할 이름."
  type        = string
}

variable "eks_admin_principal_arn" {
  description = "EKS 관리자 IAM 사용자 또는 역할 ARN."
  type        = string
}

variable "eks_public_access_cidrs" {
  description = "API 공개 엔드포인트 접근 CIDR. 현재 값 보존; 팀 관리망 CIDR로 별도 제한하세요."
  type        = list(string)
  validation {
    condition     = length(var.eks_public_access_cidrs) > 0 && alltrue([for cidr in var.eks_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "유효한 CIDR을 하나 이상 지정하세요."
  }
}

variable "eks_node_group_name" {
  description = "Managed Node Group 이름."
  type        = string
}

variable "eks_node_scaling" {
  description = "노드 수. Autoscaler 도입 시 desired_size 관리 주체를 먼저 정하세요."
  type        = object({ desired_size = number, min_size = number, max_size = number })
  validation {
    condition     = var.eks_node_scaling.min_size >= 0 && var.eks_node_scaling.max_size > 0 && var.eks_node_scaling.min_size <= var.eks_node_scaling.desired_size && var.eks_node_scaling.desired_size <= var.eks_node_scaling.max_size && alltrue([for n in values(var.eks_node_scaling) : floor(n) == n])
    error_message = "정수 노드 수이며 min <= desired <= max 이어야 합니다."
  }
}

variable "eks_node_instance_types" {
  description = "null이면 기존처럼 AWS 기본 선택을 유지합니다. 기존 노드 유형 확인 후 고정하세요."
  type        = list(string)
}

variable "eks_node_labels" {
  description = "기존 worldload 키도 보존합니다. selector 사용 여부 확인 후 수정하세요."
  type        = map(string)
}

variable "eks_cluster_tags" {
  description = "기존 EKS 태그."
  type        = map(string)
}

variable "eks_addon_versions" {
  description = "명시적으로 고정할 애드온 버전. 빈 map이면 기존 동작을 유지합니다."
  type        = map(string)
  validation {
    condition     = alltrue([for k in keys(var.eks_addon_versions) : contains(["vpc-cni", "kube-proxy", "coredns"], k)])
    error_message = "vpc-cni, kube-proxy, coredns만 지정할 수 있습니다."
  }
}

variable "rds_identifier" {
  description = "RDS 인스턴스 / subnet group / security group 이름."
  type        = string
}

variable "rds_engine_version" {
  description = "PostgreSQL 버전."
  type        = string
}

variable "rds_instance_class" {
  description = "DB 인스턴스 유형."
  type        = string
}

variable "rds_allocated_storage" {
  description = "gp3 저장 공간 GiB."
  type        = number
  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 65536 && floor(var.rds_allocated_storage) == var.rds_allocated_storage
    error_message = "20~65536 GiB 정수를 지정하세요."
  }
}

variable "rds_database_name" {
  description = "최초 생성할 DB 이름. 기존 retail 값을 보존합니다."
  type        = string
}

variable "rds_master_username" {
  description = "관리자 이름. 앱에는 별도 최소 권한 SQL 계정을 사용하세요."
  type        = string
}

variable "rds_multi_az" {
  description = "대기 DB 생성 여부."
  type        = bool
}

variable "rds_backup_retention_period" {
  description = "자동 백업 보관일. 0이면 자동 백업 해제."
  type        = number
  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35 && floor(var.rds_backup_retention_period) == var.rds_backup_retention_period
    error_message = "0~35일 정수를 지정하세요."
  }
}

variable "rds_deletion_protection" {
  description = "DB 삭제 보호."
  type        = bool
}

variable "rds_skip_final_snapshot" {
  description = "DB 삭제 시 최종 스냅샷 생략."
  type        = bool
}

variable "rds_final_snapshot_identifier" {
  description = "최종 스냅샷 이름. skip_final_snapshot=false이면 필수."
  type        = string
  validation {
    condition     = var.rds_skip_final_snapshot || try(length(trimspace(var.rds_final_snapshot_identifier)) > 0, false)
    error_message = "최종 스냅샷을 생성할 때는 이름을 지정하세요."
  }
}

variable "rds_client_security_group_ids" {
  description = "DB 5432 접근을 허용할 실제 앱 ENI 보안 그룹 ID. 빈 집합이면 앱 접근 규칙 없음."
  type        = set(string)
  validation {
    condition     = alltrue([for id in var.rds_client_security_group_ids : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "실제 sg-... ID를 지정하세요."
  }
}

variable "rds_tags" {
  description = "RDS 태그."
  type        = map(string)
}
