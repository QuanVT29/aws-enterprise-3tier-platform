output "dr_alb_dns_name" {
  description = "Public DNS of the Secondary ALB in Sydney"
  value       = module.alb.alb_dns_name
}

output "dr_asg_name" {
  description = "Auto Scaling Group Name in Sydney"
  value       = module.asg.asg_name
}

output "dr_replica_endpoint" {
  description = "RDS Replica Endpoint in Sydney"
  value       = module.disaster_recovery.replica_endpoint
}

output "dr_replica_id" {
  description = "RDS Replica Identifier in Sydney"
  value       = module.disaster_recovery.replica_id
}