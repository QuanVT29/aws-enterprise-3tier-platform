variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "prod"
}

variable "source_db_instance_arn" {
  description = "ARN of the primary RDS instance in Singapore (source for replication)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the Customer Managed Key (CMK) in Sydney for storage encryption"
  type        = string
}

variable "db_subnet_group_name" {
  description = "Database subnet group name in Sydney"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the Sydney RDS read replica"
  type        = list(string)
}

variable "primary_alb_dns" {
  description = "DNS endpoint of the primary ALB in Singapore for health probing"
  type        = string
}

variable "secondary_alb_dns" {
  description = "DNS endpoint of the secondary ALB in Sydney"
  type        = string
}

variable "secondary_alb_zone_id" {
  description = "Canonical hosted zone ID of the secondary ALB in Sydney"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 Public Hosted Zone ID (leave empty if testing with direct ALB DNS)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Apex or subdomain for failover routing (e.g., app.enterprise-cloud.net)"
  type        = string
  default     = ""
}