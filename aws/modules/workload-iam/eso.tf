resource "aws_iam_role" "retail-eso-role" {
  name = var.eso_role

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
          "aws:RequestTag/kubernetes-namespace"       = var.eso_namespace
          "aws:RequestTag/kubernetes-service-account" = var.eso_service_account
        }
      }
    }]
  })
}

resource "aws_iam_policy" "retail-eso-policy" {
  name =  var.eso_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOrdersSecret"
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]

        Resource = var.eso_secret_arns
      },
      {
        Sid      = "ReadApplicationParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = var.eso_parameter_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "retail-eso-policy" {
  role       = aws_iam_role.retail-eso-role.name
  policy_arn = aws_iam_policy.retail-eso-policy.arn
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = var.cluster_name
  namespace       = var.eso_namespace
  service_account = var.eso_service_account
  role_arn        = aws_iam_role.retail-eso-role.arn

  disable_session_tags = false

  depends_on = [
    aws_iam_role_policy_attachment.retail-eso-policy,
  ]
}