include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
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

  bastion_role_name        = "retail-prod-bastion-role"
  autoscaler_policy_name  = "RetailProdClusterAutoscalerPolicy"
  cart_dynamo_policy_name = "RetailProdCartDynamoDBPolicy"
  eso_policy_name         = "RetailProdESOReadPolicy"
  eso_role                = "retail-prod-eso-role"
  alb_role                = "retail-prod-alb-controller-role"
  cart_dynamo_role         = "retail-prod-cart-dynamo-role"
  autoscaler_role          = "retail-prod-cluster-autoscaler-role"

  alb_controller_namespace       = "kube-system"
  alb_controller_service_account = "aws-load-balancer-controller-sa"
  alb_controller_policy_arn      = "arn:aws:iam::350606136784:policy/AWSLoadBalancerControllerIAMPolicy"

  autoscaler_namespace       = "kube-system"
  autoscaler_service_account = "cluster-autoscaler-sa"

  cart_namespace       = "retail-store"
  cart_service_account = "carts-dynamo-sa"
  cart_table_arn       = "arn:aws:dynamodb:ap-northeast-2:350606136784:table/retail-store-cart"

  eso_namespace       = "external-secrets"
  eso_service_account = "external-secrets-sa"
  eso_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:350606136784:secret:retail-store/orders-pLUtwV",
  ]
  eso_parameter_arns = [
    "arn:aws:ssm:ap-northeast-2:350606136784:parameter/retail-store/orders/endpoint",
    "arn:aws:ssm:ap-northeast-2:350606136784:parameter/retail-store/redis/url",
  ]

  eks_cluster_name = "retail-prod-eks"

  eks_cluster_version = "1.36"

  eks_cluster_role_name = "retail-prod-eks-cluster-role"

  eks_node_role_name = "retail-prod-eks-node-role"

  eks_admin_principal_arn = "arn:aws:iam::350606136784:user/kdn15"

  eks_public_access_cidrs = ["0.0.0.0/0"]

  eks_node_group_name = "retail-prod-ng"

  eks_node_scaling_app = {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  eks_node_scaling_mgmt = {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  eks_node_instance_types_app  = ["t3.large"]
  eks_node_instance_types_mgmt = ["t3.medium"]

  eks_node_labels = {
    workload = "app"
  }

  eks_node_labels_mgmt = {
    workload = "mgmt"
  }

  eks_endpoint_public_access = false


  eks_cluster_tags = { Name = "retail-prod-eks", Project = "retail-infra", Environment = "prod", ManagedBy = "Terraform" }

  eks_addon_versions = {}

  rds_identifier = "retail-prod-postgres"

  rds_engine_version = "16"

  rds_instance_class = "db.t4g.micro"

  rds_allocated_storage = 20

  rds_database_name = "orders" #<-- orders로 변경할껏 !!

  rds_master_username = "dbadmin"

  rds_multi_az = false

  rds_backup_retention_period = 7

  rds_deletion_protection = false

  rds_skip_final_snapshot = true

  rds_final_snapshot_identifier = null

  rds_client_security_group_ids = {}
  rds_tags                      = { Name = "retail-prod-postgres", Project = "retail-infra", ManagedBy = "Terraform", Environment = "prod" }


  bastion_admin_cidr = "0.0.0.0/0"   # 예시: 내 PC 공인 IP로 변경
  bastion_key_name   = "code-server" # 기존 EC2 키 페어 이름

}