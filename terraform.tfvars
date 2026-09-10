# 현재 WSL 코드의 값을 보존합니다. 비밀번호/Access Key는 이 파일에 넣지 않습니다.
aws_region = "ap-northeast-2"

vpc_cidr = "10.0.0.0/16"

availability_zones = []

subnet_cidrs = {
  public_a = "10.0.1.0/24"
  public_b = "10.0.2.0/24"
  app_a    = "10.0.3.0/24"
  app_b    = "10.0.4.0/24"
  db_a     = "10.0.5.0/24"
  db_b     = "10.0.6.0/24"
}

eks_cluster_name = "retail-infra-eks"

eks_cluster_version = "1.36"

eks_cluster_role_name = "retail-infra-eks-cluster-role"

eks_node_role_name = "retail-eks-node-role"

eks_admin_principal_arn = "arn:aws:iam::350606136784:user/kdn15"

eks_public_access_cidrs = ["0.0.0.0/0"]

eks_node_group_name = "retail-ng"

eks_node_scaling = { desired_size = 2, min_size = 2, max_size = 2 }

eks_node_instance_types = null

eks_node_labels = { worldload = "retail" }

eks_cluster_tags = { Name = "retail-infra-eks", Project = "retail-infra", Environment = "prod", ManagedBy = "Terraform" }

eks_addon_versions = {}

rds_identifier = "retail-infra-postgres"

rds_engine_version = "17.11"

rds_instance_class = "db.t4g.micro"

rds_allocated_storage = 20

rds_database_name = "retail"

rds_master_username = "dbadmin"

rds_multi_az = false

rds_backup_retention_period = 7

rds_deletion_protection = false

rds_skip_final_snapshot = true

rds_final_snapshot_identifier = null

rds_client_security_group_ids = []

rds_tags = { Name = "retail-infra-postgres", Project = "retail-infra", ManagedBy = "Terraform" }


bastion_admin_cidr = "0.0.0.0/0" # 예시: 내 PC 공인 IP로 변경
bastion_key_name   = "code-server"     # 기존 EC2 키 페어 이름
