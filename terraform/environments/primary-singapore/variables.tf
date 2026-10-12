variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "isolated_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.100.0/24", "10.0.200.0/24"]
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}


variable "alert_email" {
  description = "Email receiving incident alerts from CloudWatch Alarms"
  type        = string
  default     = "quanvota29@gmail.com" 
}