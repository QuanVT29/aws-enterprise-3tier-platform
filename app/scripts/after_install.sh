#!/usr/bin/env bash
# Hook: AfterInstall
# Description: Sets file permissions and installs production npm dependencies.
set -euo pipefail

APP_DIR="/opt/app"

echo "==> [CodeDeploy Hook] Running AfterInstall..."
cd "$APP_DIR"

# Ensure runtime permissions are strictly owned by ec2-user
chown -R ec2-user:ec2-user "$APP_DIR"
chmod -R 755 "$APP_DIR"

# Install production-only dependencies
echo "--> Installing production Node.js dependencies..."
sudo -u ec2-user npm install --production --no-audit --no-fund

echo "==> AfterInstall stage completed successfully."