variable "environment" { default = "prod" }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "app_port" { default = 8080 }

# --- Available for Phase 4 & Phase 3 ---
variable "waf_acl_arn" {
  description = "ARN of WAF Web ACL (Phase 4). Default is null."
  type        = string
  default     = null
}

variable "access_logs_bucket" {
  description = "Bucket S3 store Access Logs (Phase 3). Default is null."
  type        = string
  default     = null
}