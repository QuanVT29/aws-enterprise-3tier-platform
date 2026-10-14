#  1. DATA SOURCE: READ SINGAPORE PRIMARY STATE 
data "terraform_remote_state" "primary" {
  backend = "s3"
  config = {
    bucket = "enterprise-tf-state-222634368199-ap-southeast-1"
    key    = "primary-singapore/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_caller_identity" "current" {}


# --- 2. REGIONAL KMS CMK IN SYDNEY (FOR REPLICA STORAGE ENCRYPTION) ---
resource "aws_kms_key" "dr_cmk" {
  description             = "Customer Managed Key for Sydney DR Storage"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowAutoScalingServiceRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAutoScalingCreateGrant"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },
      {
        Sid       = "AllowRDSReplicationAndServiceAccess"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-dr-cmk"
    Environment = var.environment
  }
}



# 3. 3-TIER VPC INFRASTRUCTURE IN SYDNEY 
module "vpc" {
  source                   = "../../modules/vpc"
  environment              = "${var.environment}-dr"
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  isolated_db_subnet_cidrs = var.isolated_db_subnet_cidrs
  single_nat_gateway       = true
}

# 4. SECURITY GROUPS IN SYDNEY 
module "security_groups" {
  source      = "../../modules/security_groups"
  environment = "${var.environment}-dr"
  vpc_id      = module.vpc.vpc_id
}



# 5. APPLICATION LOAD BALANCER IN SYDNEY 
module "alb" {
  source             = "../../modules/alb"
  environment        = "${var.environment}-dr"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_sg_id]
}



# 6. ASG PILOT LIGHT FOOTPRINT IN SYDNEY 
resource "aws_db_subnet_group" "replica" {
  name       = "${var.environment}-dr-subnet-group"
  subnet_ids = module.vpc.isolated_db_subnet_ids

  tags = {
    Name = "${var.environment}-dr-subnet-group"
  }
}

module "asg" {
  source                = "../../modules/asg"
  environment           = "${var.environment}-dr"
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  security_group_ids    = [module.security_groups.app_sg_id]
  instance_profile_name = data.terraform_remote_state.primary.outputs.instance_profile_name
  target_group_arn      = module.alb.target_group_arn
  user_data_path        = "${path.root}/../../../app/scripts/user_data.sh"
  kms_key_arn           = aws_kms_key.dr_cmk.arn
  min_size              = 1
  desired_capacity      = 1
  max_size              = 4

  db_host     = module.disaster_recovery.replica_address
  db_password = data.terraform_remote_state.primary.outputs.db_password
}



# 7. DISASTER RECOVERY & RDS READ REPLICA 
module "disaster_recovery" {
  source                 = "../../modules/disaster-recovery"
  environment            = var.environment
  source_db_instance_arn = data.terraform_remote_state.primary.outputs.db_instance_arn
  kms_key_arn            = aws_kms_key.dr_cmk.arn
  db_subnet_group_name   = aws_db_subnet_group.replica.name
  vpc_security_group_ids = [module.security_groups.rds_sg_id]
  primary_alb_dns        = data.terraform_remote_state.primary.outputs.alb_dns_name
  secondary_alb_dns      = module.alb.alb_dns_name
  secondary_alb_zone_id  = module.alb.alb_zone_id
}