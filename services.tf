# variable "service_hostname" {
#   description = "서비스 도메인"
#   type        = string
# }

# variable "service_hosted_zone_id" {
#   description = "기존 public Hosted Zone ID"
#   type        = string
# }

# variable "service_alb" {
#   type = object({
#     dns_name = string
#     zone_id  = string
#   })
#   default = null
# }

# module "ecr" {
#   source = "./modules/ecr"

#   repository_names = [
#     "retail/catalog",
#     "retail/cart",
#     "retail/orders",
#     "retail/checkout",
#     "retail/ui",
#   ]
# }

# module "dns_tls" {
#   source = "./modules/dns-tls"

#   hosted_zone_id = var.service_hosted_zone_id
#   hostname       = var.service_hostname
#   alb            = var.service_alb
# }

# # 앱 전용 DB 자격증명을 보관할 Secret의 그릇만 생성합니다.
# # 실제 SQL 계정 생성과 Secret 값 입력은 별도 작업입니다.
# # RDS 관리자 Secret과 구분합니다.
# resource "aws_secretsmanager_secret" "orders_app" {
#   name                    = "retail/orders/app-db"
#   description             = "Orders application database credentials"
#   recovery_window_in_days = 7

#   tags = {
#     Project   = "retail-infra"
#     ManagedBy = "Terraform"
#   }
# }

# module "workload_iam" {
#   source = "./modules/workload-iam"

#   cluster_name = module.eks.cluster_name
#   name_prefix  = "retail"

#   workloads = {
#     orders = {
#       namespace       = "retail"
#       service_account = "orders"

#       policy_json = jsonencode({
#         Version = "2012-10-17"

#         Statement = [{
#           Effect = "Allow"

#           Action = [
#             "secretsmanager:GetSecretValue",
#             "secretsmanager:DescribeSecret",
#           ]

#           Resource = aws_secretsmanager_secret.orders_app.arn
#         }]
#       })
#     }

#     load-balancer-controller = {
#       namespace       = "kube-system"
#       service_account = "aws-load-balancer-controller"

#       policy_json = file(
#         "${path.module}/policies/aws-load-balancer-controller-v3.5.0.json"
#       )
#     }
#   }

#   depends_on = [
#     module.eks,
#   ]
# }

# output "service_handoff" {
#   description = "CI/GitOps 담당자에게 전달할 설정"

#   value = {
#     ecr_urls       = module.ecr.repository_urls
#     hostname       = module.dns_tls.hostname
#     certificate_arn = module.dns_tls.certificate_arn

#     orders_secret_arn = aws_secretsmanager_secret.orders_app.arn
#     workload_role_arns = module.workload_iam.role_arns
#   }
# }