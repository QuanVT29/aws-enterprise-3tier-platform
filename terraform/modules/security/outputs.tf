output "instance_profile_name" {
  value = aws_iam_instance_profile.app_profile.name
}
output "secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}
output "secret_id" {
  value = aws_secretsmanager_secret.db_secret.id
}
output "db_generated_password" {
  value = random_password.db_password.result
  sensitive = true
}

