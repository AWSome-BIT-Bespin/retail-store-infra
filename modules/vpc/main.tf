data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "retail_infra_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "retail_infra-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
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
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "retail_infra-public-b"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private-app-a" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-app-a"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private-app-b" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-app-b"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private-db-a" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-db-a"
    Tier    = "private"
    Purpose = "db"
  }
}

resource "aws_subnet" "private-db-b" {
  vpc_id                  = aws_vpc.retail_infra_vpc.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "retail_infra-private-db-b"
    Tier    = "private"
    Purpose = "db"
  }
}

resource "aws_internet_gateway" "retail_infra-igw" {
  vpc_id = aws_vpc.retail_infra_vpc.id

  tags = {
    Name = "retail_infra-IGW"
    Tier = "IGW"
  }
}

# public-a/b는 기존 VPC의 기본 라우팅 테이블을 암묵적으로 사용한다.
# 기존 테이블은 import로 연결한다. 별도 public 연결 리소스는 만들지 않는다.
resource "aws_default_route_table" "public" {
  default_route_table_id = aws_vpc.retail_infra_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.retail_infra-igw.id
  }
}

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "retail-infra-nat-eip-${count.index + 1}"
  }
}

# 두 AZ에 EIP를 하나씩 지정하는 Regional NAT (manual mode).
resource "aws_nat_gateway" "public" {
  vpc_id            = aws_vpc.retail_infra_vpc.id
  availability_mode = "regional"

  # IGW가 VPC에 연결된 뒤 NAT 생성을 시작한다.
  depends_on = [aws_internet_gateway.retail_infra-igw]


  availability_zone_address {
    allocation_ids    = [aws_eip.nat[0].id]
    availability_zone = data.aws_availability_zones.available.names[0]
  }
  availability_zone_address {
    allocation_ids    = [aws_eip.nat[1].id]
    availability_zone = data.aws_availability_zones.available.names[1]
  }
}
# 두 APP 서브넷은 기존 NAT 하나를 공통으로 사용한다.
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.retail_infra_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public.id
  }

  tags = {
    Name = "retail_infra-Nat-rt"
    Tier = "RT"
  }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private-app-a.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private-app-b.id
  route_table_id = aws_route_table.private_app.id
}

# DB 서브넷에는 인터넷 기본 경로를 두지 않는다.
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.retail_infra_vpc.id

  tags = {
    Name      = "retail_infra-private-db-rt"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table_association" "private_db_a" {
  subnet_id      = aws_subnet.private-db-a.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_route_table_association" "private_db_b" {
  subnet_id      = aws_subnet.private-db-b.id
  route_table_id = aws_route_table.private_db.id
}

# resource "aws_security_group" "allow_tls" {
#   name = "allow_tls"
  
#   tags = {
#     Name = "allow_tls"
#   }
# }

output "private_app_subnet_ids" {
  value = [
    aws_subnet.private-app-a.id,
    aws_subnet.private-app-b.id,
  ]
}