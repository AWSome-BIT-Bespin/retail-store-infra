# Bastion이 해당 EKS의 정보를 조회할 수 있는 AWS 권한
resource "aws_iam_role_policy" "bastion_eks" {
  name = "admin-target-eks"
  role = module.bastion.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = module.eks.cluster_arn
    }]
  })
}

# Bastion IAM 역할을 EKS 접근 주체로 등록
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion.role_arn
  type          = "STANDARD"
}

# 등록된 역할에 기존 Kubernetes 관리자 권한 연결
resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = aws_eks_access_entry.bastion.cluster_name
  principal_arn = aws_eks_access_entry.bastion.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}