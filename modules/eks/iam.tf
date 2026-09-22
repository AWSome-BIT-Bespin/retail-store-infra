resource "aws_iam_role" "cluster_role" {
  name = var.cluster_role_name

  # EKS 서비스가 이 역할을 사용할 수 있도록 허용합니다.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_attach_role" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "retail_nodes" {
  name = var.node_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"

      # EC2가 이 역할을 사용할 수 있도록 허용
      Principal = {   
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "retail_worker_policy" {
  role       = aws_iam_role.retail_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "retail_ecr_policy" {
  role       = aws_iam_role.retail_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "retail_cni_policy" {
  role       = aws_iam_role.retail_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


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
          "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.retail_cluster.arn
          "aws:RequestTag/kubernetes-namespace"       = local.alb_controller_namespace
          "aws:RequestTag/kubernetes-service-account" = local.alb_controller_service_account
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "retail-alb-controller-policy" {
  role       = aws_iam_role.retail-alb-controller-role.name
  policy_arn = "arn:aws:iam::350606136784:policy/AWSLoadBalancerControllerIAMPolicy"
}




# Cluster Autoscaler 전용 IAM 역할
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
          "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.retail_cluster.arn
          "aws:RequestTag/kubernetes-namespace"       = local.autoscaler_namespace
          "aws:RequestTag/kubernetes-service-account" = local.autoscaler_service_account
        }
      }
    }]
  })
}

# 노드 그룹 조회 및 증설·축소 권한
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
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${aws_eks_cluster.retail_cluster.name}" = "owned"
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

# 정책을 Autoscaler 역할에 연결
resource "aws_iam_role_policy_attachment" "retail-cluster-autoscaler-policy" {
  role       = aws_iam_role.retail-cluster-autoscaler-role.name
  policy_arn = aws_iam_policy.retail-cluster-autoscaler-policy.arn
}


resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = aws_eks_cluster.retail_cluster.name
  namespace       = local.autoscaler_namespace
  service_account = local.autoscaler_service_account
  role_arn        = aws_iam_role.retail-cluster-autoscaler-role.arn

  disable_session_tags = false

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_iam_role_policy_attachment.retail-cluster-autoscaler-policy,
  ]


}


# ESO 전용 IAM 역할
resource "aws_iam_role" "retail-eso-role" {
  name = "retail-eso-role"

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
          "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.retail_cluster.arn
          "aws:RequestTag/kubernetes-namespace"       = local.eso_namespace
          "aws:RequestTag/kubernetes-service-account" = local.eso_service_account
        }
      }
    }]
  })
}

# 지정한 Secret·파라미터 읽기 권한
resource "aws_iam_policy" "retail-eso-policy" {
  name = "RetailESOReadPolicy"

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

        Resource = local.eso_secret_arns
      },
      {
        Sid      = "ReadApplicationParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.eso_parameter_arns
      }
    ]
  })
}

# 역할에 정책 연결
resource "aws_iam_role_policy_attachment" "retail-eso-policy" {
  role       = aws_iam_role.retail-eso-role.name
  policy_arn = aws_iam_policy.retail-eso-policy.arn
}