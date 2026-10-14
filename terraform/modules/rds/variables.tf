variable "environment" { default = "prod" }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "db_password" {
    type = string
    sensitive = true
}
variable "secret_id" { type = string }
variable "db_name" { default = "enterprisedb" }
variable "db_user" { default = "cloudadmin" }

variable "kms_key_arn" {
  description = "KMS CMK ARN use for encrypting RDS Storage"
  type        = string
  default     = null
}