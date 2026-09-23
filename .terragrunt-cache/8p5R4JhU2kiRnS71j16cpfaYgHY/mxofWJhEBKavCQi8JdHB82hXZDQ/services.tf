module "workload_iam" {
  source = "./modules/workload-iam"

  cluster_name = module.eks.pod_identity_cluster_name
  cluster_arn  = module.eks.cluster_arn

  role_name   = "retail-cart-dynamo-role"
  policy_name = "RetailCartDynamoDBPolicy"

  namespace       = "retail-store"
  service_account = "carts-dynamo-sa"

  dynamodb_table_arn = "arn:aws:dynamodb:ap-northeast-2:350606136784:table/retail-store-cart"
}