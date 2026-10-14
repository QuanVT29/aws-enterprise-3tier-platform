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

output "kms_key_arn" {
  description = "ARN of Customer Managed Key (CMK)"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "Key ID of CMK"
  value       = aws_kms_key.main.key_id
}

output "waf_acl_arn" {
  description = "ARN of AWS WAF v2 Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}
