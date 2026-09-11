resource "aws_eks_cluster" "retail_cluster" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster_role.arn

  # 기본 애드온은 나중에 노드와 함께 구성합니다.
  bootstrap_self_managed_addons = false

  access_config {
    # 아래 access entry로 kubectl 사용자를 등록합니다.
    authentication_mode = "API"

    # 생성자에게 자동으로 관리자 권한을 주지 않습니다.
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    # 기존 VPC의 앱용 private 서브넷 두 개
    subnet_ids = var.subnet_ids

    endpoint_public_access  = true
    endpoint_private_access = true
    
    security_group_ids = [aws_security_group.cp_sg.id]
    #네트워크가 바뀌면 수정하세요.
    public_access_cidrs = var.public_access_cidrs
  }

  tags = var.cluster_tags

  # IAM 정책 연결이 완료된 다음 클러스터를 생성합니다.
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_attach_role]
}
