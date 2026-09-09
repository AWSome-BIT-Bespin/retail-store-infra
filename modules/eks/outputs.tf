output "cluster_name" {
  description = "kubectl / GitOps bootstrap 대상 클러스터."
  value       = aws_eks_cluster.retail_cluster.name
}
output "cluster_endpoint" {
  description = "Kubernetes API 서버 주소."
  value       = aws_eks_cluster.retail_cluster.endpoint
}
output "cluster_security_group_id" {
  description = "EKS 클러스터 SG. 실제 앱 ENI에 연결되었는지 확인 후 DB client SG로 사용하세요."
  value       = aws_eks_cluster.retail_cluster.vpc_config[0].cluster_security_group_id
}
output "node_role_arn" {
  description = "EC2 노드 IAM 역할 ARN. 앱 전용 IAM 역할과 구분하세요."
  value       = aws_iam_role.retail_nodes.arn
}
