#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Generate unique test data for each run
# NIC format: 12 digits — YYYYDDDDSSSS (1990 + day 123 + random serial)
SERIAL=$(shuf -i 1000-9999 -n 1)
TEST_NIC="19900123${SERIAL}"
TEST_EMAIL="test.teacher.${SERIAL}@moe.gov.lk"
TEST_PHONE="077$(shuf -i 1000000-9999999 -n 1)"

echo "==> Test NIC: $TEST_NIC"
echo "==> Test Email: $TEST_EMAIL"
echo "==> Test Phone: $TEST_PHONE"

echo "==> Getting bearer token..."
TOKEN=$(hurl --variables-file vars.env tests/get-token.hurl | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to obtain access token" >&2
  exit 1
fi

echo "==> Running create-teacher tests..."
hurl --variables-file vars.env \
  --variable "token=$TOKEN" \
  --variable "nic=$TEST_NIC" \
  --variable "email=$TEST_EMAIL" \
  --variable "phone=$TEST_PHONE" \
  --test "$@" tests/create-teacher.hurl
