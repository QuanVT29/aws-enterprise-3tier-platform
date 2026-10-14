output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN Suffix of ALB for CloudWatch Metric dimension"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN Suffix of Target Group for CloudWatch Metric dimension"
  value       = aws_lb_target_group.app.arn_suffix
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer (for Route 53 Alias)"
  value       = aws_lb.main.zone_id
}

