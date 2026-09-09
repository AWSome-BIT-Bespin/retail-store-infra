# 기존 리소스 주소와 태그를 보존합니다. 이름 정리는 별도 plan으로 진행하세요.
output "private_app_subnet_ids" {
  value = [
    aws_subnet.private-app-a.id,
    aws_subnet.private-app-b.id,
  ]
}

output "vpc_id" {
  value = aws_vpc.retail_infra_vpc.id
}

output "private_db_subnet_ids" {
  value = [
    aws_subnet.private-db-a.id,
    aws_subnet.private-db-b.id,
  ]
}

output "public_subnet_ids" {
  description = "인터넷 연결 로드밸런서용 서브넷."
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}
output "availability_zones" {
  description = "현재 선택된 AZ. 이후 명시적으로 고정할 때 사용합니다."
  value       = local.azs
}
