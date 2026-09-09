# variable "cluster_name" {
#   type = string
# }

# variable "name_prefix" {
#   type = string
# }

# variable "workloads" {
#   type = map(object({
#     namespace       = string
#     service_account = string
#     policy_json     = string
#   }))
# }

# resource "aws_iam_role" "this" {
#   for_each = var.workloads

#   name = "${var.name_prefix}-${each.key}"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"

#     Statement = [{
#       Effect = "Allow"

#       Principal = {
#         Service = "pods.eks.amazonaws.com"
#       }

#       Action = [
#         "sts:AssumeRole",
#         "sts:TagSession",
#       ]
#     }]
#   })

#   tags = {
#     Project   = "retail-infra"
#     ManagedBy = "Terraform"
#   }
# }

# resource "aws_iam_role_policy" "this" {
#   for_each = var.workloads

#   name   = "${var.name_prefix}-${each.key}"
#   role   = aws_iam_role.this[each.key].id
#   policy = each.value.policy_json
# }

# resource "aws_eks_pod_identity_association" "this" {
#   for_each = var.workloads

#   cluster_name    = var.cluster_name
#   namespace       = each.value.namespace
#   service_account = each.value.service_account
#   role_arn        = aws_iam_role.this[each.key].arn

#   depends_on = [
#     aws_iam_role_policy.this,
#   ]
# }

# output "role_arns" {
#   value = {
#     for name, role in aws_iam_role.this :
#     name => role.arn
#   }
# }