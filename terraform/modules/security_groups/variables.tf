variable "vpc_id" { type = string }
variable "environment" { default = "prod" }
variable "app_port" { default = 8080 }
variable "db_port" { default = 5432 }