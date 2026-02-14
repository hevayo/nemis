#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Getting bearer token..."
TOKEN=$(hurl --variables-file vars.env tests/get-token.hurl | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to obtain access token" >&2
  exit 1
fi

echo "==> Running create-teacher tests..."
hurl --variables-file vars.env --variable "token=$TOKEN" --test "$@" tests/create-teacher.hurl
