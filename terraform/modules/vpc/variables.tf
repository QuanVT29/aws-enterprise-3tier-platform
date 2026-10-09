variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "isolated_db_subnet_cidrs" { type = list(string) }
variable "environment" { default = "prod" }
variable "single_nat_gateway" {
  description = "Turn on 1 NAT Gateway to optimize costs (FinOps)"
  type        = bool
  default     = true
}