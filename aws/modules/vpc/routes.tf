# 기존 리소스 주소와 태그를 보존합니다. 이름 정리는 별도 plan으로 진행하세요.
resource "aws_default_route_table" "public" {
  default_route_table_id = aws_vpc.retail_infra_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.retail_infra-igw.id
  }
}

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
