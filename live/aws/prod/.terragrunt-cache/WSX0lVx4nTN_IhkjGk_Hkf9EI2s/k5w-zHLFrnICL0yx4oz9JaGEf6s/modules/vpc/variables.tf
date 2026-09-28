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
