output "replica_endpoint" {
  description = "Connection endpoint of the Sydney RDS read replica"
  value       = aws_db_instance.replica.endpoint
}

output "replica_id" {
  description = "Identifier of the Sydney RDS replica for promotion scripts"
  value       = aws_db_instance.replica.identifier
}

output "replica_arn" {
  description = "ARN of the Sydney RDS replica"
  value       = aws_db_instance.replica.arn
}

output "health_check_id" {
  description = "Route 53 Health Check ID monitoring Singapore primary"
  value       = aws_route53_health_check.primary.id
}

output "replica_address" {
  description = "DNS hostname of the Sydney RDS read replica"
  value       = aws_db_instance.replica.address
}