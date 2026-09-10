
resource "aws_iam_role" "bastion" {
  name = var.bastion_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "describe_eks" {
  name = "describe-target-eks"
  role = aws_iam_role.bastion.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = var.eks_cluster_arn
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.bastion_role_name}-profile"
  role = aws_iam_role.bastion.name
}

output "role_arn" {
  value = aws_iam_role.bastion.arn
}

output "role_name" {
  value = aws_iam_role.bastion.name
}