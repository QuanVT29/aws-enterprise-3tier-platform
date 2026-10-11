#!/usr/bin/env bash
# Hook: ApplicationStart
# Description: Reloads systemd daemon and launches the application daemon.
set -euo pipefail

echo "==> [CodeDeploy Hook] Running ApplicationStart..."

# Reload systemd daemon to pick up any service changes
systemctl daemon-reload

# Start and enable the diagnostic application service
systemctl restart cloud-app.service
systemctl enable cloud-app.service

echo "==> ApplicationStart stage completed: cloud-app.service active."