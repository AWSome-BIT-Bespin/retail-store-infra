# 기존 리소스 주소와 태그를 보존합니다. 이름 정리는 별도 plan으로 진행하세요.
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = var.subnet_cidrs.public_a
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "retail_infra-dev-subnet-public-a"
    Tier                     = "public"
    ManagedBy                = "Terraform"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = var.subnet_cidrs.public_b
  availability_zone       = local.azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "retail_infra-public-b"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private-app-a" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = var.subnet_cidrs.app_a
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-app-a"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private-app-b" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = var.subnet_cidrs.app_b
  availability_zone       = local.azs[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-app-b"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private-db-a" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = var.subnet_cidrs.db_a
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-db-a"
    Tier    = "private"
    Purpose = "db"
  }
}

resource "aws_subnet" "private-db-b" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = var.subnet_cidrs.db_b
  availability_zone       = local.azs[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-db-b"
    Tier    = "private"
    Purpose = "db"
  }
}
