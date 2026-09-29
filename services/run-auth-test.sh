#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8081}"
USER="${USER_NAME:-demo$(date +%s)}"
EMAIL="${EMAIL:-${USER}@example.com}"
PASSWORD="${PASSWORD:-ChangeMe123!}"

echo "Registering ${USER}..."
REGISTER=$(curl -fsS -X POST "${BASE_URL}/api/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"${USER}\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")
echo "$REGISTER"

ACCESS=$(printf '%s' "$REGISTER" | python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])')
REFRESH=$(printf '%s' "$REGISTER" | python3 -c 'import json,sys; print(json.load(sys.stdin)["refreshToken"])')

echo "Calling /me..."
curl -fsS "${BASE_URL}/api/auth/me" -H "Authorization: Bearer ${ACCESS}"
echo

echo "Refreshing..."
REFRESHED=$(curl -fsS -X POST "${BASE_URL}/api/auth/refresh" \
  -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"${REFRESH}\"}")
echo "$REFRESHED"

NEW_REFRESH=$(printf '%s' "$REFRESHED" | python3 -c 'import json,sys; print(json.load(sys.stdin)["refreshToken"])')

echo "Logging out..."
curl -fsS -X POST "${BASE_URL}/api/auth/logout" \
  -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"${NEW_REFRESH}\"}"
echo
