# 기존 리소스 주소와 태그를 보존합니다. 이름 정리는 별도 plan으로 진행하세요.
resource "aws_internet_gateway" "retail_infra-igw" {
  vpc_id = aws_vpc.retail_infra_vpc.id

  tags = {
    Name = "retail_infra-IGW"
    Tier = "IGW"
  }
}

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "retail-infra-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "public" {
  vpc_id            = aws_vpc.retail_infra_vpc.id
  availability_mode = "regional"

  # IGW가 VPC에 연결된 뒤 NAT 생성을 시작한다.
  depends_on = [aws_internet_gateway.retail_infra-igw]


  availability_zone_address {
    allocation_ids    = [aws_eip.nat[0].id]
    availability_zone = local.azs[0]
  }
  availability_zone_address {
    allocation_ids    = [aws_eip.nat[1].id]
    availability_zone = local.azs[1]
  }
}
