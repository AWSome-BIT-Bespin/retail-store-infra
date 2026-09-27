resource "aws_iam_role" "retail-alb-controller-role" {
  name = "retail-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowControllerPodIdentity"
      Effect = "Allow"
      Action = ["sts:AssumeRole", "sts:TagSession"]
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:RequestTag/eks-cluster-arn"            = var.cluster_arn
          "aws:RequestTag/kubernetes-namespace"       = var.alb_controller_namespace
          "aws:RequestTag/kubernetes-service-account" = var.alb_controller_service_account
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "retail-alb-controller-policy" {
  role       = aws_iam_role.retail-alb-controller-role.name
  policy_arn = var.alb_controller_policy_arn
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = var.cluster_name
  namespace       = var.alb_controller_namespace
  service_account = var.alb_controller_service_account
  role_arn        = aws_iam_role.retail-alb-controller-role.arn

  disable_session_tags = false

  depends_on = [
    aws_iam_role_policy_attachment.retail-alb-controller-policy,
  ]
}
