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