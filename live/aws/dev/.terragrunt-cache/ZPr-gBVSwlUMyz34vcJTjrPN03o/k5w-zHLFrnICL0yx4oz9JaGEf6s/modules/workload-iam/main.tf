resource "aws_iam_role" "retail-cart-dynamo-role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "pods.eks.amazonaws.com"
      }

      Action = [
        "sts:AssumeRole",
        "sts:TagSession",
      ]

      Condition = {
        StringEquals = {
          "aws:RequestTag/eks-cluster-arn" = var.cluster_arn

          "aws:RequestTag/kubernetes-namespace" = var.namespace

          "aws:RequestTag/kubernetes-service-account" = var.service_account
        }
      }
    }]
  })
}

# Cart 테이블과 고객 조회 인덱스 접근 권한
resource "aws_iam_policy" "retail-cart-dynamo-policy" {
  name = var.policy_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
        ]

        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:Query"]

        Resource = format(
          "%s/index/idx_global_customerId",
          var.dynamodb_table_arn
        )
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "retail-cart-dynamo-policy" {
  role       = aws_iam_role.retail-cart-dynamo-role.name
  policy_arn = aws_iam_policy.retail-cart-dynamo-policy.arn
}

resource "aws_eks_pod_identity_association" "cart" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.retail-cart-dynamo-role.arn

  disable_session_tags = false

  depends_on = [
    aws_iam_role_policy_attachment.retail-cart-dynamo-policy,
  ]
}