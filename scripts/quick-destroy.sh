#!/usr/bin/env bash

# Script: quick-destroy.sh
# Description: Safely tears down all active compute, database, and networkresources in primary-singapore to prevent unnecessary AWS costs.


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$ROOT_DIR/terraform/environments/primary-singapore"


echo "   FINOPS TEARDOWN: Primary Singapore Environment           "
echo "============================================================"
echo "WARNING: This will destroy the VPC, NAT Gateways, ALB, ASG, "
echo "         and RDS Multi-AZ instances in region ap-southeast-1."
echo "Remote state files in S3 and DynamoDB locks will remain intact."
echo "============================================================"

read -rp "Are you sure you want to proceed with destruction? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted by user. No resources were modified."
  exit 0
fi

cd "$ENV_DIR"

echo "[1/2] Initializing environment..."
terraform init

echo "[2/2] Running Terraform Destroy..."
terraform destroy -auto-approve

echo "============================================================"
echo " Teardown completed successfully. Billing has ceased.        "
echo "============================================================"