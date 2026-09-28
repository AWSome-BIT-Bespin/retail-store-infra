resource "aws_db_subnet_group" "postgres" {
  name       = var.identifier
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  db_name           = var.database_name
  username          = var.master_username

  # RDS가 비밀번호를 생성하고 Secrets Manager에서 관리합니다.
  manage_master_user_password = true

  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_period
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.final_snapshot_identifier
  copy_tags_to_snapshot      = true

  tags = var.tags
}
