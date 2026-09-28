
resource "aws_iam_role" "bastion" {
  name = var.bastion_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_admin" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_instance_profile" "bastion" {
  name = "${var.bastion_role_name}-profile"
  role = aws_iam_role.bastion.name
}

output "role_arn" {
  value = aws_iam_role.bastion.arn
}

output "role_name" {
  value = aws_iam_role.bastion.name
}
