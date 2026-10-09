variable "environment" { default = "prod" }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "instance_profile_name" { type = string }
variable "target_group_arn" { type = string }
variable "user_data_path" { type = string }
variable "db_host" {
  type        = string
  description = "RDS endpoint host"
}

variable "db_port" {
  type        = number
  default     = 5432
  description = "RDS endpoint port"
}

variable "db_name" {
  type        = string
  default     = "enterprisedb"
  description = "Database name"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database master password"
}