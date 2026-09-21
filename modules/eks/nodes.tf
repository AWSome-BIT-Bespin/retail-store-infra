resource "aws_eks_node_group" "retail_ng" {
  cluster_name    = aws_eks_cluster.retail_cluster.name
  node_group_name = "${var.node_group_name}-app"
  node_role_arn   = aws_iam_role.retail_nodes.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_scaling.desired_size
    max_size     = var.node_scaling.max_size
    min_size     = var.node_scaling.min_size
  }
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.retail_worker_policy,
    aws_iam_role_policy_attachment.retail_ecr_policy,
    aws_iam_role_policy_attachment.retail_cni_policy,
    aws_eks_addon.retail_vpc_cni,
    aws_eks_addon.retail_kube_proxy,
  ]

  labels = {
    workload = "app"
  } 

  tags = merge(var.cluster_tags, {
    Name     = "${var.node_group_name}-app"
    Workload = "app"
})
}


resource "aws_eks_node_group" "retail_mgmt_ng" {
  cluster_name    = aws_eks_cluster.retail_cluster.name
  node_group_name = "${var.node_group_name}-mgmt"
  node_role_arn   = aws_iam_role.retail_nodes.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_scaling.desired_size
    max_size     = var.node_scaling.max_size
    min_size     = var.node_scaling.min_size
  }
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.retail_worker_policy,
    aws_iam_role_policy_attachment.retail_ecr_policy,
    aws_iam_role_policy_attachment.retail_cni_policy,
    aws_eks_addon.retail_vpc_cni,
    aws_eks_addon.retail_kube_proxy,
  ]

  labels = var.node_labels_mgmt
  taint {
  key    = "dedicated"
  value  = "mgmt"
  effect = "NO_SCHEDULE"
}

  tags = merge(var.cluster_tags, {
    Name     = "${var.node_group_name}-mgmt"
    Workload = "mgmt"
})
}

