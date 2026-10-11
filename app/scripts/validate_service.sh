#!/usr/bin/env bash
# Hook: ValidateService
# Description: Probes local HTTP health endpoint to verify application readiness.
set -euo pipefail

PORT=8080
HEALTH_URL="http://127.0.0.1:${PORT}/healthz"
MAX_ATTEMPTS=12
SLEEP_INTERVAL=5

echo "==> [CodeDeploy Hook] Validating service readiness at ${HEALTH_URL}..."

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
  
  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "--> [SUCCESS] Health check returned HTTP 200 OK on attempt $i."
    exit 0
  fi
  
  echo "--> [Attempt $i/$MAX_ATTEMPTS] Service not ready (HTTP $HTTP_STATUS). Retrying in ${SLEEP_INTERVAL}s..."
  sleep "$SLEEP_INTERVAL"
done

echo "--> [FATAL] Service validation failed after $MAX_ATTEMPTS attempts."
journalctl -u cloud-app.service -n 50 --no-pager
exit 1