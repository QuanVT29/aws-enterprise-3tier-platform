terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

variable "aws_region" {
  description = "Target AWS region for global identity and deployment pipelines"
  type        = string
  default     = "ap-southeast-1"
}

variable "github_repository" {
  description = "GitHub repository formatted as <owner>/<repo_name> authorized to assume IAM roles"
  type        = string
  default     = "QuanVT29/aws-enterprise-3tier-platform"
}

# 1. GITHUB ACTIONS OIDC IDENTITY PROVIDER
# Establishes trust federation between AWS STS and GitHub Actions OpenID Connect
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "a031c46782e6e6c662c2c87c76da9aa62ccabd8e"
  ]

  tags = {
    Name        = "github-actions-oidc-provider"
    Environment = "global"
  }
}


# 2. S3 ARTIFACT STORAGE FOR CODEDEPLOY RELEASES
# Encrypted, version-controlled storage bucket for immutable release bundles
resource "aws_s3_bucket" "codedeploy_artifacts" {
  bucket_prefix = "enterprise-codedeploy-artifacts-"
  force_destroy = true

  tags = {
    Name        = "codedeploy-artifacts-storage"
    Environment = "global"
    ManagedBy   = "Terraform"
    Project     = "aws-enterprise-3tier-platform"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.codedeploy_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.codedeploy_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# 3. IAM ROLE FOR GITHUB ACTIONS (KEYLESS OIDC FEDERATION)
# Grants temporary execution credentials scoped strictly to QuanVT29 repository
resource "aws_iam_role" "github_actions_deployer" {
  name = "github-actions-enterprise-deployer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:*",
              "repo:${lower(var.github_repository)}:*",
              "repo:*:*aws-enterprise-3tier-platform:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "github-actions-enterprise-deployer-role"
    Environment = "global"
  }
}

# IAM policy granting artifact publishing and deployment orchestration rights
resource "aws_iam_role_policy" "github_actions_permissions" {
  name = "github-actions-deploy-permissions"
  role = aws_iam_role.github_actions_deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArtifactBucketPermissions"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codedeploy_artifacts.arn,
          "${aws_s3_bucket.codedeploy_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "CodeDeployOrchestrationPermissions"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision"
        ]
        Resource = "*"
      }
    ]
  })
}

# 4. OUTPUT EXPORTS
# Values required by GitHub Actions repository secrets and workflow parameters
output "github_actions_role_arn" {
  description = "IAM Role ARN to be used in GitHub Actions (aws-actions/configure-aws-credentials)"
  value       = aws_iam_role.github_actions_deployer.arn
}

output "artifacts_bucket_name" {
  description = "S3 bucket name designated for staging CodeDeploy application bundles"
  value       = aws_s3_bucket.codedeploy_artifacts.bucket
}