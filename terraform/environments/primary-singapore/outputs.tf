output "alb_dns_name" {
  description = "URL access website"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "Private Endpoint Database"
  value       = module.rds.endpoint
}

output "asg_name" {
  description = "Auto Scaling Group Name"
  value       = module.asg.asg_name
}

output "db_instance_id" {
  description = "RDS ID for Phase 5 DR"
  value       = module.rds.db_instance_id
}


output "cloudwatch_dashboard_url" {
  description = "Direct link to access CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.observability.dashboard_name}"
}

output "incident_sns_topic_arn" {
  description = "ARN of the SNS Topic receiving incident alerts"
  value       = module.observability.sns_topic_arn
}

output "waf_web_acl_arn" {
  description = "ARN of AWS WAF Web ACL secure ALB"
  value       = module.security.waf_acl_arn
}

output "kms_cmk_arn" {
  description = "ARN of Customer Managed Key (CMK)"
  value       = module.security.kms_key_arn
}