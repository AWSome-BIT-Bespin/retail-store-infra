module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  subnet_cidrs       = var.subnet_cidrs
}

#모듈이 받는 이름 
module "eks" {
  source              = "./modules/eks"
  subnet_ids          = module.vpc.private_app_subnet_ids
  cluster_name        = var.eks_cluster_name
  cluster_version     = var.eks_cluster_version
  cluster_role_name   = var.eks_cluster_role_name
  node_role_name      = var.eks_node_role_name
  admin_principal_arn = var.eks_admin_principal_arn
  public_access_cidrs = var.eks_public_access_cidrs
  node_group_name     = var.eks_node_group_name
  node_scaling        = var.eks_node_scaling
  node_instance_types = var.eks_node_instance_types
  node_labels         = var.eks_node_labels
  cluster_tags        = var.eks_cluster_tags
  addon_versions      = var.eks_addon_versions
}

module "rds" {
  source                    = "./modules/rds"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_db_subnet_ids
  identifier                = var.rds_identifier
  engine_version            = var.rds_engine_version
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage
  database_name             = var.rds_database_name
  master_username           = var.rds_master_username
  multi_az                  = var.rds_multi_az
  backup_retention_period   = var.rds_backup_retention_period
  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_final_snapshot_identifier
  client_security_group_ids = var.rds_client_security_group_ids
  tags                      = var.rds_tags
}



data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
variable "bastion_admin_cidr" {
  description = "SSH 접속을 허용할 PC 공인 IPv4/32"
  type        = string
}

variable "bastion_key_name" {
  description = "서울 리전에 등록된 기존 EC2 키 페어 이름"
  type        = string
}

data "aws_ssm_parameter" "bastion_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# 1. Bastion 전용 보안 그룹
resource "aws_security_group" "bastion" {
  name        = "retail-bastion-sg"
  description = "Security group for bastion"
  vpc_id      = module.vpc.vpc_id
}

# 2. 내 PC에서 들어오는 SSH만 허용
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id

  cidr_ipv4   = var.bastion_admin_cidr
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}


resource "aws_vpc_security_group_ingress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion.id

  cidr_ipv4   = var.bastion_admin_cidr
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# 3. 기본 예시: 외부 및 VPC 내부로 나가는 통신 허용
resource "aws_vpc_security_group_egress_rule" "bastion_outbound" {
  security_group_id = aws_security_group.bastion.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# 4. Public A에 관리용 EC2 생성
resource "aws_instance" "bastion" {
  ami           = data.aws_ssm_parameter.bastion_ami.value
  instance_type = "t3.large"

  subnet_id                   = module.vpc.public_subnet_ids[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.bastion_key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name      = "retail-bastion"
    ManagedBy = "Terraform"
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}