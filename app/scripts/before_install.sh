#!/usr/bin/env bash
# Hook: BeforeInstall
# Description: Prepares instance filesystem and stops old service instances.
set -euo pipefail

APP_DIR="/opt/app"
BACKUP_DIR="/opt/app_backup"

echo "==> [CodeDeploy Hook] Running BeforeInstall..."

# Create target directory if it does not exist
mkdir -p "$APP_DIR"

# Backup existing deployment for audit/rollback trace if directory is not empty
if [ -d "$APP_DIR" ] && [ "$(ls -A "$APP_DIR")" ]; then
  echo "--> Creating temporary backup of existing artifacts..."
  rm -rf "$BACKUP_DIR"
  cp -r "$APP_DIR" "$BACKUP_DIR"
fi

# Stop existing application service gracefully before overwriting files
if systemctl is-active --quiet cloud-app.service; then
  echo "--> Stopping running cloud-app.service..."
  systemctl stop cloud-app.service || true
fi

echo "==> BeforeInstall stage completed successfully."