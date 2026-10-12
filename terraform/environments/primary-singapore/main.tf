# 1. Module VPC
module "vpc" {
  source                   = "../../modules/vpc"
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  isolated_db_subnet_cidrs = var.isolated_db_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
}

# 2. Module Security Groups
module "security_groups" {
  source      = "../../modules/security_groups"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# 3. Module Security (IAM Roles + Secrets Manager)
module "security" {
  source      = "../../modules/security"
  environment = var.environment
}

# 4. Module RDS (Multi-AZ)
module "rds" {
  source             = "../../modules/rds"
  environment        = var.environment
  subnet_ids         = module.vpc.isolated_db_subnet_ids
  security_group_ids = [module.security_groups.rds_sg_id]
  db_password        = module.security.db_generated_password
  secret_id          = module.security.secret_id
}

# 5. Module ALB
module "alb" {
  source             = "../../modules/alb"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_sg_id]
}

# 6. Module ASG
module "asg" {
  source                = "../../modules/asg"
  environment           = var.environment
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  security_group_ids    = [module.security_groups.app_sg_id]
  instance_profile_name = module.security.instance_profile_name
  target_group_arn      = module.alb.target_group_arn
  user_data_path        = "${path.root}/../../../app/scripts/user_data.sh"

  db_host     = module.rds.endpoint
  db_port     = module.rds.port
  db_name     = module.rds.db_name
  db_password = module.security.db_generated_password
}



# 7. OBSERVABILITY & INCIDENT RESPONSE (PHASE 3)
module "observability" {
  source                  = "../../modules/observability"
  environment             = var.environment
  aws_region              = var.aws_region
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  asg_name                = module.asg.asg_name
  db_instance_id          = module.rds.db_instance_identifier
  alb_dns_name            = module.alb.alb_dns_name
  alert_email             = var.alert_email
}