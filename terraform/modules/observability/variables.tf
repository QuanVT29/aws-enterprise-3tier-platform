variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of ALB from module alb"
}

variable "target_group_arn_suffix" {
  type        = string
  description = "ARN suffix of ALB Target Group"
}

variable "asg_name" {
  type        = string
  description = "Name of the Auto Scaling Group"
}

variable "db_instance_id" {
  type        = string
  description = "Identifier of the RDS database instance"
}

variable "alb_dns_name" {
  type        = string
  description = "DNS endpoint of the ALB for Synthetic Canary ping"
}

variable "alert_email" {
  type        = string
  description = "Email to receive alerts from SNS"
  default     = "your-admin-email@example.com"
}