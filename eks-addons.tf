# bootstrap_self_managed_addons is false, so install the system add-ons explicitly.
# CNI and kube-proxy must not depend on the node group becoming Ready.
resource "aws_eks_addon" "retail_vpc_cni" {
  cluster_name = aws_eks_cluster.retail_cluster.name
  addon_name   = "vpc-cni"

  depends_on = [aws_iam_role_policy_attachment.retail_cni_policy]
}

resource "aws_eks_addon" "retail_kube_proxy" {
  cluster_name = aws_eks_cluster.retail_cluster.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "retail_coredns" {
  cluster_name = aws_eks_cluster.retail_cluster.name
  addon_name   = "coredns"

  depends_on = [
    aws_eks_node_group.retail_ng,
    aws_eks_addon.retail_kube_proxy,
  ]
}

# On first creation, EKS selects the default compatible add-on version.
