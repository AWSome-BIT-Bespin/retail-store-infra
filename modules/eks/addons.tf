resource "aws_eks_addon" "retail_vpc_cni" {
  cluster_name  = aws_eks_cluster.retail_cluster.name
  addon_name    = "vpc-cni"
  addon_version = lookup(var.addon_versions, "vpc-cni", null)

  depends_on = [aws_iam_role_policy_attachment.retail_cni_policy]
}

resource "aws_eks_addon" "retail_kube_proxy" {
  cluster_name  = aws_eks_cluster.retail_cluster.name
  addon_name    = "kube-proxy"
  addon_version = lookup(var.addon_versions, "kube-proxy", null)
}

resource "aws_eks_addon" "retail_coredns" {
  cluster_name  = aws_eks_cluster.retail_cluster.name
  addon_name    = "coredns"
  addon_version = lookup(var.addon_versions, "coredns", null)

  depends_on = [
    aws_eks_node_group.retail_ng,
    aws_eks_addon.retail_kube_proxy,
  ]
}
