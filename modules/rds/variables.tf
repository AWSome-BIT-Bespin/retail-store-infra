variable "identifier" {
  description = "RDS 인스턴스 / subnet group / security group 이름."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL 버전."
  type        = string
}

variable "instance_class" {
  description = "DB 인스턴스 유형."
  type        = string
}

variable "allocated_storage" {
  description = "gp3 저장 공간 GiB."
  type        = number
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536 && floor(var.allocated_storage) == var.allocated_storage
    error_message = "20~65536 GiB 정수를 지정하세요."
  }
}

variable "database_name" {
  description = "최초 생성할 DB 이름. 기존 retail 값을 보존합니다."
  type        = string
}

variable "master_username" {
  description = "관리자 이름. 앱에는 별도 최소 권한 SQL 계정을 사용하세요."
  type        = string
}

variable "multi_az" {
  description = "대기 DB 생성 여부."
  type        = bool
}

variable "backup_retention_period" {
  description = "자동 백업 보관일. 0이면 자동 백업 해제."
  type        = number
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35 && floor(var.backup_retention_period) == var.backup_retention_period
    error_message = "0~35일 정수를 지정하세요."
  }
}

variable "deletion_protection" {
  description = "DB 삭제 보호."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "DB 삭제 시 최종 스냅샷 생략."
  type        = bool
}

variable "final_snapshot_identifier" {
  description = "최종 스냅샷 이름. skip_final_snapshot=false이면 필수."
  type        = string
  validation {
    condition     = var.skip_final_snapshot || try(length(trimspace(var.final_snapshot_identifier)) > 0, false)
    error_message = "최종 스냅샷을 생성할 때는 이름을 지정하세요."
  }
}

variable "client_security_group_ids" {
  description = "DB 5432 접근을 허용할 실제 앱 ENI 보안 그룹 ID. 빈 집합이면 앱 접근 규칙 없음."
  type        = set(string)
  validation {
    condition     = alltrue([for id in var.client_security_group_ids : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "실제 sg-... ID를 지정하세요."
  }
}

variable "tags" {
  description = "RDS 태그."
  type        = map(string)
}

variable "vpc_id" {
  description = "DB 서브넷이 속한 VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "서로 다른 AZ의 DB private 서브넷 ID."
  type        = list(string)
  validation {
    condition     = length(toset(var.subnet_ids)) >= 2
    error_message = "서로 다른 AZ의 서브넷 ID 두 개 이상이 필요합니다."
  }
}
