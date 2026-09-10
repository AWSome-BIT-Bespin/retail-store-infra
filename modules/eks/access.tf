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


//bastion arn 받아오게되면 추가될 access entry
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.retail_cluster.name
  principal_arn = var.bastion_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = aws_eks_access_entry.bastion.cluster_name
  principal_arn = aws_eks_access_entry.bastion.principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
