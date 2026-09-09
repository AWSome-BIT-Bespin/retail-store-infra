resource "aws_security_group" "postgres" {
  name        = var.identifier
  description = "PostgreSQL access from application clients"
  vpc_id      = var.vpc_id
}

# 빈 집합이면 규칙을 만들지 않습니다. 실제 Pod/노드 ENI의 SG를 지정하세요.
resource "aws_vpc_security_group_ingress_rule" "postgres_app" {
  for_each                     = var.client_security_group_ids
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
