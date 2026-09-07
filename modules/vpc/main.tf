data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "retail_vpc_test2" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {  
    Name = "retail-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.retail_vpc_test2.id
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
  vpc_id                  = aws_vpc.retail_vpc_test2.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "rs-public-b"
    Tier = "public"
  }
}

resource "aws_subnet" "private-app-a" {
  vpc_id                  = aws_vpc.retail_vpc_test2.id
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
  vpc_id                  = aws_vpc.retail_vpc_test2.id
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
  vpc_id                  = aws_vpc.retail_vpc_test2.id
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
  vpc_id                  = aws_vpc.retail_vpc_test2.id
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
  vpc_id = aws_vpc.retail_vpc_test2.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.retail_vpc_test2.id

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
  vpc_id      = aws_vpc.retail_vpc_test2.id
  availability_mode = "regional"
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.retail-igw]
  

  tags = {
    Name     = "retail-regional-nat"
  }
}

# APP Private Route Table
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.retail_vpc_test2.id


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
  vpc_id = aws_vpc.retail_vpc_test2.id

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

resource "aws_eks_cluster" "retail-cluster" {
  name     = "retail-cluster"
  role_arn = aws_iam_role.retail_cluster.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private-app-a.id,
      aws_subnet.private-app-b.id,
    ]

    endpoint_private_access = true
    endpoint_public_access  = true # 초기 kubectl 접속용
  }

  depends_on = [
    aws_iam_role_policy_attachment.retail_cluster,
  ]
}

resource "aws_iam_role" "retail_cluster" {
  name = "retail-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "retail_cluster" {
  role       = aws_iam_role.retail_cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_node_group" "retail_ng" {
  cluster_name    = aws_eks_cluster.retail-cluster.name
  node_group_name = "retail-ng"
  node_role_arn   = aws_iam_role.retail_nodes.arn

  subnet_ids = [
    aws_subnet.private-app-a.id,
    aws_subnet.private-app-b.id,
  ]

  version = aws_eks_cluster.retail-cluster.version 
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.retail_node_instance_type]
  capacity_type  = "ON_DEMAND"
  disk_size      = 30

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "retail"
  }

  tags = local.retail_node_tags

  depends_on = [aws_iam_role_policy_attachment.retail_nodes]
}


resource "aws_iam_role" "retail_nodes" {
  name = "retail-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.retail_node_tags
}

data "aws_partition" "current" {}

resource "aws_iam_role_policy_attachment" "retail_nodes" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEC2ContainerRegistryPullOnly",
    "AmazonEKS_CNI_Policy",
  ])

  role       = aws_iam_role.retail_nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

locals {
  retail_node_tags = {
    Name        = "retail-ng"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Workload    = "retail"
  }
}

variable "retail_node_instance_type" {
  description = "EC2 instance type for the retail EKS managed node group."
  type        = string
  default     = "t3.medium"
}

