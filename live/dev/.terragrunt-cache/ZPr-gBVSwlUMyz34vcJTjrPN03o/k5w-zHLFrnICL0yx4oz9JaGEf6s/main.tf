module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  subnet_cidrs       = var.subnet_cidrs
}

module "bastion" {
  source           = "./modules/bastion"
  bastion_role_name = "retail-bastion-role"
  vpc_id           = module.vpc.vpc_id
  bastion_key_name  = var.bastion_key_name
  bastion_admin_cidr  = var.bastion_admin_cidr
  private_app_subnet_ids = module.vpc.private_app_subnet_ids

}

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
  node_scaling_app  = var.eks_node_scaling_app
  node_scaling_mgmt = var.eks_node_scaling_mgmt

  node_instance_types_app  = var.eks_node_instance_types_app
  node_instance_types_mgmt = var.eks_node_instance_types_mgmt

  node_labels      = var.eks_node_labels
  node_labels_mgmt = var.eks_node_labels_mgmt

  endpoint_public_access = var.eks_endpoint_public_access
  cluster_tags        = var.eks_cluster_tags
  addon_versions      = var.eks_addon_versions
  vpc_id = module.vpc.vpc_id
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
  client_security_group_ids = merge(
  var.rds_client_security_group_ids,
  {
    eks_nodes = module.eks.cluster_security_group_id
  }
)
  tags                      = var.rds_tags
}
