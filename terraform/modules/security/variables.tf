variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to assign to VPC Endpoint"
  default     = ""
}

variable "route_table_ids" {
  type        = list(string)
  description = "List of Route Table IDs to associate with S3 Gateway Endpoint"
  default     = []
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private Subnet IDs to Lambda Rotation"
  default     = []
}

variable "app_sg_id" {
  type        = string
  description = "App Security Group ID for Lambda Rotation"
  default     = ""
}