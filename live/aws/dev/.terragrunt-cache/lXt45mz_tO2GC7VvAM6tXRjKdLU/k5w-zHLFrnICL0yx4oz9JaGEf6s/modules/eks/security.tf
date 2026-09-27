resource "aws_security_group" "cp_sg" {

    name = "allow_cp"
    vpc_id = var.vpc_id

}

resource "aws_vpc_security_group_ingress_rule" "allow_tls" {
  security_group_id = aws_security_group.cp_sg.id
  cidr_ipv4         = "0.0.0.0/0" # bastion sg 해야됨 
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.cp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

