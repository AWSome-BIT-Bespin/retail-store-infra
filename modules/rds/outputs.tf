output "address" {
  description = "DB 호스트명. 포트는 별도 전달합니다."
  value       = aws_db_instance.postgres.address
}
output "port" {
  description = "PostgreSQL 포트."
  value       = aws_db_instance.postgres.port
}
output "database_name" {
  description = "Terraform이 생성한 최초 DB 이름."
  value       = aws_db_instance.postgres.db_name
}
output "security_group_id" {
  description = "DB 보안 그룹 ID."
  value       = aws_security_group.postgres.id
}
output "admin_secret_arn" {
  description = "관리자 비밀의 ARN만 출력합니다. 앱 사용자 비밀번호가 아닙니다."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}
