# # 1. EKS 서비스가 AWS 리소스를 관리할 때 사용할 IAM 역할
# resource "aws_iam_role" "cluster_role" {
#   name = "retail-infra-eks-cluster-role"

#   # EKS 서비스가 이 역할을 사용할 수 있도록 허용합니다.
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "eks.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }



# # 2. 위 역할에 EKS 운영에 필요한 AWS 관리형 정책을 연결
# resource "aws_iam_role_policy_attachment" "eks_cluster_attach_role" {
#   role       = aws_iam_role.cluster_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
# }w

# # 3. EKS 클러스터 생성 (워커 노드는 나중에 추가)
# resource "aws_eks_cluster" "retail_cluster" {
#   name     = "retail-infra-eks"
#   version  = "1.36"
#   role_arn = aws_iam_role.eks_cluster.arn

#   # 기본 애드온은 나중에 노드와 함께 구성합니다.
#   bootstrap_self_managed_addons = false

#   access_config {
#     # 아래 access entry로 kubectl 사용자를 등록합니다.
#     authentication_mode = "API"

#     # 생성자에게 자동으로 관리자 권한을 주지 않습니다.
#     bootstrap_cluster_creator_admin_permissions = false
#   }

#   vpc_config {
#     # 기존 VPC의 앱용 private 서브넷 두 개
#     subnet_ids = [ 
#     module.vpc.aws_subnet.private-app-a.id,
#     module.vpc.aws_subnet.private-app-a.id
#     ]



#     endpoint_public_access  = true
#     endpoint_private_access = true

#     # 2026-09-06 확인한 PC 공인 IP. 네트워크가 바뀌면 수정하세요.
#     # /32는 이 IP 하나만 허용한다는 뜻입니다.
#     public_access_cidrs = ["121.88.27.71/32"]
#   }

#   tags = {
#     Name        = "retail-infra-eks"
#     Project     = "retail-infra"
#     Environment = "prod"
#     ManagedBy   = "Terraform"
#   }

#   # IAM 정책 연결이 완료된 다음 클러스터를 생성합니다.
#   depends_on = [aws_iam_role_policy_attachment.eks_cluster]
# }

# # 4. kubectl로 접속할 IAM 사용자 등록
# resource "aws_eks_access_entry" "admin" {
#   cluster_name  = aws_eks_cluster.retail.name
#   principal_arn = "arn:aws:iam::350606136784:user/kdn15"
#   type          = "STANDARD"
# }

# # 5. 등록한 사용자에게 이 클러스터의 관리자 권한 부여
# resource "aws_eks_access_policy_association" "admin" {
#   cluster_name  = aws_eks_access_entry.admin.cluster_name
#   principal_arn = aws_eks_access_entry.admin.principal_arn
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

#   access_scope {
#     type = "cluster"
#   }
# }

# # 생성 후 확인할 클러스터 이름
# output "eks_cluster_name" {
#   value = aws_eks_cluster.retail.name
# }
