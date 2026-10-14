terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "enterprise-tf-state-222634368199-ap-southeast-1"
    key            = "environments/dr-sydney/terraform.tfstate"
    region         = "ap-southeast-1"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AWS-Enterprise-3Tier-Platform"
      Environment = var.environment
      Region      = "ap-southeast-2"
      ManagedBy   = "Terraform"
    }
  }
}