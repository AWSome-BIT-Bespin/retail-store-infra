# 지정된 관리자 IAM 주체는 이 클러스터를 관리한다.
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.retail_cluster.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_access_entry.admin.cluster_name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# 이 EC2 역할을 사용하는 사용자와 프로세스가 같은 관리 권한을 사용한다.
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.retail_cluster.name
  principal_arn = var.bastion_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = aws_eks_access_entry.bastion.cluster_name
  principal_arn = aws_eks_access_entry.bastion.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
