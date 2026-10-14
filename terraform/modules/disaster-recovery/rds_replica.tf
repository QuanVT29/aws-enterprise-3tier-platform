resource "aws_db_instance" "replica" {
  identifier          = "${var.environment}-dr-sydney-replica"
  replicate_source_db = var.source_db_instance_arn
  instance_class      = "db.t4g.micro"
  storage_type        = "gp3"
  multi_az            = false  # Giữ single-AZ ở trạng thái Warm Standby để tối ưu chi phí

  kms_key_id        = var.kms_key_arn
  storage_encrypted = true

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  auto_minor_version_upgrade = true
  skip_final_snapshot        = true
  deletion_protection        = false

  tags = {
    Name        = "${var.environment}-dr-sydney-replica"
    Environment = var.environment
    Role        = "DisasterRecovery-Replica"
  }
}