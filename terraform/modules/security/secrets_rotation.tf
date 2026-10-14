# IAM Role executed for Secrets Manager Rotation Lambda
resource "aws_iam_role" "rotation_lambda_role" {
  name = "${var.environment}-secrets-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rotation_vpc" {
  role       = aws_iam_role.rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "rotation_secrets_policy" {
  name = "${var.environment}-rotation-policy"
  role = aws_iam_role.rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetRandomPassword"]
        Resource = "*"
      }
    ]
  })
}

# Package inline code Python basic handle for Secret Rotation
data "archive_file" "rotation_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/rotation_lambda.zip"

  source {
    content  = <<-EOF
      import boto3
      import json

      def lambda_handler(event, context):
          arn = event['SecretId']
          token = event['ClientRequestToken']
          step = event['Step']
          print(f"Executing step {step} for secret {arn}")
          return {"statusCode": 200, "body": json.dumps("Rotation step processed")}
    EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "secrets_rotation" {
  filename         = data.archive_file.rotation_lambda_zip.output_path
  function_name    = "${var.environment}-db-secret-rotator"
  role             = aws_iam_role.rotation_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.rotation_lambda_zip.output_base64sha256
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.app_sg_id]
  }

  tags = {
    Name        = "${var.environment}-secret-rotator"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_secrets_manager" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secrets_rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# Activate rotation cycle of 30 days on the existing Secret from Phase 1
resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_secret.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.allow_secrets_manager]
}