# # 이 파일을 /home/yong/project/modules/vpc/eks-outputs.tf에 작성합니다.
# # 기존 VPC 모듈의 앱용 서브넷 ID를 루트 eks.tf에 전달합니다.
# output "private_app_subnet_ids" {
#   description = "Private application subnet IDs in two availability zones."
#   value = [
#     aws_subnet.private-app-a.id,
#     aws_subnet.private-app-b.id,
#   ]
# }
