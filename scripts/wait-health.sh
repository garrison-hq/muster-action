#!/usr/bin/env bash
# Poll a readiness URL until it returns HTTP 200 or a timeout elapses (D4).
# Used when a consumer boots the agent under test inside the workflow.
set -uo pipefail

URL="${HEALTH_URL:?HEALTH_URL is required}"
TIMEOUT="${HEALTH_TIMEOUT:-60}"

echo "Waiting up to ${TIMEOUT}s for ${URL} to return 200..."
deadline=$(( SECONDS + TIMEOUT ))
while [ "$SECONDS" -lt "$deadline" ]; do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null || echo 000)"
  if [ "$code" = "200" ]; then
    echo "Endpoint ready (200)."
    exit 0
  fi
  echo "  not ready (HTTP ${code}); retrying in 3s..."
  sleep 3
done

echo "::error::muster-action: ${URL} did not return 200 within ${TIMEOUT}s"
exit 1
