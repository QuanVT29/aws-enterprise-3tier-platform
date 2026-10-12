output "sns_topic_arn" {
  description = "ARN of the SNS Topic receiving incident alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "canary_name" {
  description = "Name of CloudWatch Synthetics Canary"
  value       = aws_synthetics_canary.app_canary.name
}