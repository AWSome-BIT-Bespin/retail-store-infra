locals {
  alb_controller_namespace       = "kube-system"
  alb_controller_service_account = "aws-load-balancer-controller-sa"

  cart_namespace       = "retail-store"
  cart_service_account = "carts-dynamo-sa"
  cart_table_arn       = "arn:aws:dynamodb:ap-northeast-2:350606136784:table/retail-store-cart"

  autoscaler_namespace       = "kube-system"
  autoscaler_service_account = "cluster-autoscaler-sa"

  eso_namespace       = "external-secrets"
  eso_service_account = "external-secrets-sa"

  eso_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:350606136784:secret:retail-store/orders-pLUtwV",
  ]
  
  eso_parameter_arns = [
    "arn:aws:ssm:ap-northeast-2:350606136784:parameter/retail-store/orders/endpoint",
    "arn:aws:ssm:ap-northeast-2:350606136784:parameter/retail-store/redis/url",
  ]
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = aws_eks_cluster.retail_cluster.name
  namespace       = local.alb_controller_namespace
  service_account = local.alb_controller_service_account
  role_arn        = aws_iam_role.retail-alb-controller-role.arn

  disable_session_tags = false

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.retail-alb-controller-policy,
  ]
}


resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = aws_eks_cluster.retail_cluster.name
  namespace       = local.eso_namespace
  service_account = local.eso_service_account
  role_arn        = aws_iam_role.retail-eso-role.arn

  disable_session_tags = false

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.retail-eso-policy,
  ]
}