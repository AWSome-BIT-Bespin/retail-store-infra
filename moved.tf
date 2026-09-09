# 같은 S3 state에서 기존 루트 리소스를 모듈로 이동합니다. 전체 환경 전환이 끝나도 이력을 유지하세요.
moved {
  from = aws_iam_role.cluster_role
  to   = module.eks.aws_iam_role.cluster_role
}

moved {
  from = aws_iam_role_policy_attachment.eks_cluster_attach_role
  to   = module.eks.aws_iam_role_policy_attachment.eks_cluster_attach_role
}

moved {
  from = aws_eks_cluster.retail_cluster
  to   = module.eks.aws_eks_cluster.retail_cluster
}

moved {
  from = aws_eks_access_entry.admin
  to   = module.eks.aws_eks_access_entry.admin
}

moved {
  from = aws_eks_access_policy_association.admin
  to   = module.eks.aws_eks_access_policy_association.admin
}

moved {
  from = aws_iam_role.retail_nodes
  to   = module.eks.aws_iam_role.retail_nodes
}

moved {
  from = aws_iam_role_policy_attachment.retail_worker_policy
  to   = module.eks.aws_iam_role_policy_attachment.retail_worker_policy
}

moved {
  from = aws_iam_role_policy_attachment.retail_ecr_policy
  to   = module.eks.aws_iam_role_policy_attachment.retail_ecr_policy
}

moved {
  from = aws_iam_role_policy_attachment.retail_cni_policy
  to   = module.eks.aws_iam_role_policy_attachment.retail_cni_policy
}

moved {
  from = aws_eks_node_group.retail_ng
  to   = module.eks.aws_eks_node_group.retail_ng
}

moved {
  from = aws_eks_addon.retail_vpc_cni
  to   = module.eks.aws_eks_addon.retail_vpc_cni
}

moved {
  from = aws_eks_addon.retail_kube_proxy
  to   = module.eks.aws_eks_addon.retail_kube_proxy
}

moved {
  from = aws_eks_addon.retail_coredns
  to   = module.eks.aws_eks_addon.retail_coredns
}

moved {
  from = aws_db_subnet_group.postgres
  to   = module.rds.aws_db_subnet_group.postgres
}

moved {
  from = aws_security_group.postgres
  to   = module.rds.aws_security_group.postgres
}

moved {
  from = aws_db_instance.postgres
  to   = module.rds.aws_db_instance.postgres
}
