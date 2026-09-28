# variable "repository_names" {
#   type = set(string)
# }

# resource "aws_ecr_repository" "this" {
#   for_each = var.repository_names

#   name                 = each.value
#   image_tag_mutability = "IMMUTABLE"
#   force_delete         = false

#   encryption_configuration {
#     encryption_type = "AES256"
#   }

#   tags = {
#     Project   = "retail-infra"
#     ManagedBy = "Terraform"
#   }
# }

# output "repository_urls" {
#   value = {
#     for name, repository in aws_ecr_repository.this :
#     name => repository.repository_url
#   }
# }

# output "repository_arns" {
#   value = {
#     for name, repository in aws_ecr_repository.this :
#     name => repository.arn
#   }
# }