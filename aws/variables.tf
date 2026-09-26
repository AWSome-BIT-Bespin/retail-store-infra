variable "aws_region" {
  type        = string
}

variable "vpc_cidr" {
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "유효한 IPv4 CIDR을 입력하세요."
  }
}

variable "availability_zones" {
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) == 0 || (length(var.availability_zones) == 2 && length(toset(var.availability_zones)) == 2)
    error_message = "AZ는 비워두거나 서로 다른 두 개를 지정하세요."
  }
}

variable "subnet_cidrs" {
  type        = object({ public_a = string, public_b = string, app_a = string, app_b = string, db_a = string, db_b = string })
  validation {
    condition     = alltrue([for cidr in values(var.subnet_cidrs) : can(cidrnetmask(cidr))])
    error_message = "모든 서브넷은 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "eks_cluster_name" {
  type        = string
}

variable "eks_cluster_version" {
  type        = string
}

variable "eks_cluster_role_name" {
  type        = string
}

variable "eks_node_role_name" {
  type        = string
}

variable "eks_admin_principal_arn" {
  type        = string
}

variable "eks_public_access_cidrs" {
  type        = list(string)
  validation {
    condition     = length(var.eks_public_access_cidrs) > 0 && alltrue([for cidr in var.eks_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "유효한 CIDR을 하나 이상 지정하세요."
  }
}

variable "eks_node_group_name" {
  type        = string
}

variable "eks_node_scaling_app" {
  description = "APP 노드 그룹의 스케일 설정"

  type = object({
    desired_size = number
    min_size     = number
    max_size     = number
  })

  validation {
    condition = (
      var.eks_node_scaling_app.min_size >= 0 &&
      var.eks_node_scaling_app.max_size > 0 &&
      var.eks_node_scaling_app.min_size <= var.eks_node_scaling_app.desired_size &&
      var.eks_node_scaling_app.desired_size <= var.eks_node_scaling_app.max_size &&
      alltrue([
        for n in values(var.eks_node_scaling_app) : floor(n) == n
      ])
    )

    error_message = "APP 노드 수는 정수이며 0 <= min <= desired <= max, max >= 1이어야 합니다."
  }
}

variable "eks_node_scaling_mgmt" {
  description = "MGMT 노드 그룹의 스케일 설정"

  type = object({
    desired_size = number
    min_size     = number
    max_size     = number
  })

  validation {
    condition = (
      var.eks_node_scaling_mgmt.min_size >= 0 &&
      var.eks_node_scaling_mgmt.max_size > 0 &&
      var.eks_node_scaling_mgmt.min_size <= var.eks_node_scaling_mgmt.desired_size &&
      var.eks_node_scaling_mgmt.desired_size <= var.eks_node_scaling_mgmt.max_size &&
      alltrue([
        for n in values(var.eks_node_scaling_mgmt) : floor(n) == n
      ])
    )

    error_message = "MGMT 노드 수는 정수이며 0 <= min <= desired <= max, max >= 1이어야 합니다."
  }
}

variable "eks_node_instance_types_app" {
  description = "APP 노드 그룹의 EC2 인스턴스 유형"
  type        = list(string)
}

variable "eks_node_instance_types_mgmt" {
  description = "MGMT 노드 그룹의 EC2 인스턴스 유형"
  type        = list(string)
}

variable "eks_node_labels" {
  type        = map(string)
}

variable "eks_cluster_tags" {
  type        = map(string)
}

variable "eks_addon_versions" {
  type        = map(string)
  validation {
    condition     = alltrue([for k in keys(var.eks_addon_versions) : contains(["vpc-cni", "kube-proxy", "coredns"], k)])
    error_message = "vpc-cni, kube-proxy, coredns만 지정할 수 있습니다."
  }
}

variable "rds_identifier" {
  type        = string
}

variable "rds_engine_version" {
  type        = string
}

variable "rds_instance_class" {
  type        = string
}

variable "rds_allocated_storage" {
  type        = number
  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 65536 && floor(var.rds_allocated_storage) == var.rds_allocated_storage
    error_message = "20~65536 GiB 정수를 지정하세요."
  }
}

variable "rds_database_name" {
  type        = string
}

variable "rds_master_username" {
  type        = string
}

variable "rds_multi_az" {
  type        = bool
}

variable "rds_backup_retention_period" {
  type        = number
  validation {
    condition     = var.rds_backup_retention_period >= 0 && var.rds_backup_retention_period <= 35 && floor(var.rds_backup_retention_period) == var.rds_backup_retention_period
    error_message = "0~35일 정수를 지정하세요."
  }
}

variable "rds_deletion_protection" {
  type        = bool
}

variable "rds_skip_final_snapshot" {
  type        = bool
}

variable "rds_final_snapshot_identifier" {
  type        = string
  validation {
    condition     = var.rds_skip_final_snapshot || try(length(trimspace(var.rds_final_snapshot_identifier)) > 0, false)
    error_message = "최종 스냅샷을 생성할 때는 이름을 지정하세요."
  }
}

variable "rds_client_security_group_ids" {
  description = "기본 EKS 노드 외에 추가로 DB 접근을 허용할 보안 그룹"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for id in values(var.rds_client_security_group_ids) :
      can(regex("^sg-[0-9a-f]+$", id))
    ])

    error_message = "각 값에는 실제 sg-... 보안 그룹 ID를 지정하세요."
  }
}

variable "rds_tags" {
  type        = map(string)
}

variable "eks_node_labels_mgmt" {
  type        = map(string)

  default = {
    workload = "mgmt"
  }
}

variable "bastion_key_name" {
  type = string
}

variable "bastion_admin_cidr" {
  type = string
}

variable "eks_endpoint_public_access" {
  type        = bool
}

variable "bastion_role_name" {
  type        = string
}
