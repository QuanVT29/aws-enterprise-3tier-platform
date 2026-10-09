#!/usr/bin/env bash

# Script: quick-deploy.sh
# Description: Automates initialization, validation, and deployment of the Primary Singapore infrastructure environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$ROOT_DIR/terraform/environments/primary-singapore"

echo "============================================================"
echo " Starting Automated Deployment: Primary Singapore (Phase 1) "
echo "============================================================"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "[ERROR] AWS credentials not found or expired. Run 'aws configure' first."
  exit 1
fi

cd "$ENV_DIR"

echo "[1/4] Formatting Terraform files..."
terraform fmt -recursive "$ROOT_DIR/terraform"

echo "[2/4] Initializing Terraform backend and providers..."
terraform init -upgrade

echo "[3/4] Validating Terraform configuration..."
terraform validate

echo "[4/4] Deploying infrastructure to AWS..."
terraform apply -auto-approve

echo "============================================================"
echo " Deployment Complete! Key Infrastructure Outputs:           "
echo "============================================================"
terraform output

echo ""
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
echo ">> Access Web Application at: http://${ALB_DNS}"
echo "============================================================"