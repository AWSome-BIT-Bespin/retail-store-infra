variable "bastion_role_name" {
  type = string
}


variable "eks_cluster_arn" {
  description = "Bastion에서 조회할 EKS 클러스터 ARN"
  type        = string
}