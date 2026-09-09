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
