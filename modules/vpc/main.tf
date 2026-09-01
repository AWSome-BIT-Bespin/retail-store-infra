data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "rs_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "rs-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.rs_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "rs-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.rs_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "rs-public-b"
    Tier = "public"
  }
}

resource "aws_subnet" "private_app_a" {
  vpc_id                  = aws_vpc.rs_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-app-a"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private_app_b" {
  vpc_id                  = aws_vpc.rs_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-app-b"
    Tier    = "private"
    Purpose = "app"
  }
}

resource "aws_subnet" "private_db_a" {
  vpc_id                  = aws_vpc.rs_vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-db-a"
    Tier    = "private"
    Purpose = "db"
  }
}

resource "aws_subnet" "private_db_b" {
  vpc_id                  = aws_vpc.rs_vpc.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name    = "rs-private-db-b"
    Tier    = "private"
    Purpose = "db"
  }
}