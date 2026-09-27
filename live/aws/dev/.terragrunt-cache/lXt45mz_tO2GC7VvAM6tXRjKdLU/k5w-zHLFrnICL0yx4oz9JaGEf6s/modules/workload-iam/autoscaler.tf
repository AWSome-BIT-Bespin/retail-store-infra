resource "aws_iam_role" "retail-cluster-autoscaler-role" {
  name = "retail-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]

      Condition = {
        StringEquals = {
          "aws:RequestTag/eks-cluster-arn"            = var.cluster_arn
          "aws:RequestTag/kubernetes-namespace"       = var.autoscaler_namespace
          "aws:RequestTag/kubernetes-service-account" = var.autoscaler_service_account
        }
      }
    }]
  })
}

resource "aws_iam_policy" "retail-cluster-autoscaler-policy" {
  name = "RetailClusterAutoscalerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ScaleOwnCluster"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      },
      {
        Sid    = "ReadScalingInformation"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "retail-cluster-autoscaler-policy" {
  role       = aws_iam_role.retail-cluster-autoscaler-role.name
  policy_arn = aws_iam_policy.retail-cluster-autoscaler-policy.arn
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = var.cluster_name
  namespace       = var.autoscaler_namespace
  service_account = var.autoscaler_service_account
  role_arn        = aws_iam_role.retail-cluster-autoscaler-role.arn

  disable_session_tags = false

  depends_on = [
    aws_iam_role_policy_attachment.retail-cluster-autoscaler-policy,
  ]


}