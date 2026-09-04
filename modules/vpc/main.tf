data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "retail_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {  
    Name = "retail-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.retail_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "retail-dev-subnet-public-a"
    Tier = "public"
    ManagedBy = "Terraform"
    
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.retail_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "rs-public-b"
    Tier = "public"
  }
}

resource "aws_subnet" "private-app-a" {
  vpc_id                  = aws_vpc.retail_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-app-a"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private-app-b" {
  vpc_id                  = aws_vpc.retail_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-app-b"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private-db-a" {
  vpc_id                  = aws_vpc.retail_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-db-a"
    Tier    = "private"
    Purpose = "db"
  }
}

resource "aws_subnet" "private-db-b" {
  vpc_id                  = aws_vpc.retail_vpc.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-db-b"
    Tier    = "private"
    Purpose = "db"
  }
}

resource "aws_internet_gateway" "retail-igw" {
  vpc_id = aws_vpc.retail_vpc.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.retail_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.retail-igw.id
  }

  tags = {
    Name = "retail-public-rt"
    # ManagedBy = "Terraform"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "regional" {
  vpc_id      = aws_vpc.retail_vpc.id
  availability_mode = "regional"
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.retail-igw]
  

  tags = {
    Name     = "retail-regional-nat"
  }
}

# APP Private Route Table
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.retail_vpc.id


  route {
    cidr_block    = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.regional.id
  }

  tags = {
    Name    = "retail-private-app-rt"
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

# DB Route Table - 인터넷 기본 경로 없음
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.retail_vpc.id

  tags = {
    Name      = "retail-private-db-rt"
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