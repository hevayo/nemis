#!/bin/bash
# Extract NEMIS Test App credentials from APIM DevPortal and write hurl/vars.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

APIM_HOST="${APIM_HOST:-localhost}"
APIM_PORT="${APIM_PORT:-9443}"
APIM_USER="${APIM_USER:-admin}"
APIM_PASS="${APIM_PASS:-admin}"
APP_NAME="NEMIS Test App"

APIM_BASE="https://${APIM_HOST}:${APIM_PORT}/api/am/devportal/v3"

echo "==> Looking up '${APP_NAME}' in APIM DevPortal..."
APP_RESPONSE=$(curl -sk -u "${APIM_USER}:${APIM_PASS}" \
  "${APIM_BASE}/applications?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${APP_NAME}'))")")

APP_COUNT=$(echo "$APP_RESPONSE" | jq -r '.count // 0')
if [ "$APP_COUNT" -eq 0 ]; then
  echo "ERROR: Application '${APP_NAME}' not found. Run the configure playbook first:" >&2
  echo "  cd ansible && ansible-playbook configure-is-and-apim.yml -e @users-and-roles.yml -e apim_hostname=localhost -e is_hostname=localhost" >&2
  exit 1
fi

APP_ID=$(echo "$APP_RESPONSE" | jq -r '.list[0].applicationId')
echo "    Found application ID: ${APP_ID}"

echo "==> Fetching OAuth keys..."
KEYS_RESPONSE=$(curl -sk -u "${APIM_USER}:${APIM_PASS}" \
  "${APIM_BASE}/applications/${APP_ID}/oauth-keys")

KEY_COUNT=$(echo "$KEYS_RESPONSE" | jq -r '.count // (.list | length)')
if [ "$KEY_COUNT" -eq 0 ]; then
  echo "ERROR: No OAuth keys found for '${APP_NAME}'. Re-run the configure playbook." >&2
  exit 1
fi

CONSUMER_KEY=$(echo "$KEYS_RESPONSE" | jq -r '.list[0].consumerKey')
CONSUMER_SECRET=$(echo "$KEYS_RESPONSE" | jq -r '.list[0].consumerSecret')

if [ -z "$CONSUMER_KEY" ] || [ "$CONSUMER_KEY" = "null" ]; then
  echo "ERROR: Could not extract consumer key" >&2
  exit 1
fi

echo "    Consumer Key: ${CONSUMER_KEY}"

VARS_FILE="${REPO_DIR}/hurl/vars.env"
mkdir -p "$(dirname "$VARS_FILE")"

cat > "$VARS_FILE" <<EOF
gateway_url=https://service.emis.moe.gov.lk/nemis/1.0.0
is_url=https://identity.emis.moe.gov.lk
consumer_key=${CONSUMER_KEY}
consumer_secret=${CONSUMER_SECRET}
test_username=admin
test_password=admin
is_admin_user=admin
is_admin_password=admin
nic=199012345678
email=test.teacher@moe.gov.lk
EOF

echo "==> Written ${VARS_FILE}"
echo "    Run tests with: cd hurl && ./run.sh"
