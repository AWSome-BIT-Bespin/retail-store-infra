output "network" {
  description = "다른 담당자가 사용할 네트워크 식별자."
  value = {
    vpc_id             = module.vpc.vpc_id
    availability_zones = module.vpc.availability_zones
    public_subnet_ids  = module.vpc.public_subnet_ids
    app_subnet_ids     = module.vpc.private_app_subnet_ids
    db_subnet_ids      = module.vpc.private_db_subnet_ids
  }
}
output "eks" {
  description = "Kubernetes 담당자에게 전달할 클러스터 정보."
  value = {
    name                      = module.eks.cluster_name
    region                    = var.aws_region
    endpoint                  = module.eks.cluster_endpoint
    cluster_security_group_id = module.eks.cluster_security_group_id
    node_role_arn             = module.eks.node_role_arn
  }
}
output "postgres" {
  description = "앱 DB 설정. admin_secret_arn은 관리자 전용이며 앱에 직접 전달하지 않습니다."
  value = {
    host              = module.rds.address
    port              = module.rds.port
    database          = module.rds.database_name
    security_group_id = module.rds.security_group_id
    admin_secret_arn  = module.rds.admin_secret_arn
  }
}
