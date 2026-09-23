# 1. Bastion 전용 보안 그룹
resource "aws_security_group" "bastion" {
  name        = "retail-bastion-sg"
  description = "Security group for bastion"
  vpc_id      = var.vpc_id
}

# 2. 내 PC에서 들어오는 SSH만 허용
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id

  cidr_ipv4   = var.bastion_admin_cidr
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}


resource "aws_vpc_security_group_ingress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion.id

  cidr_ipv4   = var.bastion_admin_cidr
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "bastion_outbound" {
  security_group_id = aws_security_group.bastion.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}