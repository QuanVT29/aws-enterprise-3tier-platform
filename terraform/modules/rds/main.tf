resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.environment}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.environment}-primary-db"
  allocated_storage = 20
  storage_type      = "gp3"
  engine            = "postgres"
  engine_version    = "16.15"
  instance_class    = "db.t4g.micro" # Graviton Architecture

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  multi_az            = true # Multi-AZ HA Foundation
  publicly_accessible = false
  skip_final_snapshot = true
  storage_encrypted   = true

  backup_retention_period = 7

  tags = { Name = "${var.environment}-rds-multi-az" }
}

# Update Secrets Manager after RDS creates endpoint
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = var.secret_id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    database = var.db_name
    username = var.db_user
    password = var.db_password
  })
}