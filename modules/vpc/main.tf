# 기존 리소스 주소와 태그를 보존합니다. 이름 정리는 별도 plan으로 진행하세요.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability_zones) == 0 ? slice(data.aws_availability_zones.available.names, 0, 2) : var.availability_zones
}

resource "aws_vpc" "retail_infra_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "retail_infra-vpc"
  }
}
