module "workload_iam" {
  source = "./modules/workload-iam"

  cluster_name = module.eks.pod_identity_cluster_name
  cluster_arn  = module.eks.cluster_arn

  role_name   = "retail-cart-dynamo-role"
  policy_name = "RetailCartDynamoDBPolicy"

  alb_controller_namespace       = var.alb_controller_namespace
  alb_controller_service_account = var.alb_controller_service_account
  alb_controller_policy_arn      = var.alb_controller_policy_arn
  autoscaler_namespace           = var.autoscaler_namespace
  autoscaler_service_account     = var.autoscaler_service_account
  namespace                      = var.cart_namespace
  service_account                = var.cart_service_account
  dynamodb_table_arn             = var.cart_table_arn
  eso_namespace                  = var.eso_namespace
  eso_service_account            = var.eso_service_account
  eso_secret_arns                = var.eso_secret_arns
  eso_parameter_arns             = var.eso_parameter_arns
}
