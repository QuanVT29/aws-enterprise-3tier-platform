# Random password and store in Secrets Manager
resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "${var.environment}-rds-credentials"
  recovery_window_in_days = 0
  tags = {
    Name = "${var.environment}-db-secret"
  }
}


# IAM role for EC2 (Phase 1, 2, 3)
resource "aws_iam_role" "app_role" {
  name = "${var.environment}-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}


# Phase 1: Permissions SSM Session Manager (Zero trust, no SSH)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app_role.name 
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Phase 2: Permissions CodeDeploy Agent (CI/CD)
resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Phase 3: Permissions CloudWatch Agent (Metrics & Logs)
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}



# Permissions read Secrets Manager (Phase 1, 2, 3)
resource "aws_iam_role_policy" "read_secrets" {
  name = "${var.environment}-read-db-secrets"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      }
    ]
  })
}


resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.environment}-app-instance-profile"
  role = aws_iam_role.app_role.name
}

