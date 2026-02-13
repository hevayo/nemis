#!/usr/bin/env bash
set -euo pipefail

# Domains to add to /etc/hosts
COMMENT="# NEMIS local development"
ENTRY="127.0.0.1 hrm.emis.moe.gov.lk apim.emis.moe.gov.lk identity.emis.moe.gov.lk service.emis.moe.gov.lk"

HOSTS_FILE="/etc/hosts"

if grep -v '^\s*#' "$HOSTS_FILE" 2>/dev/null | grep -qF "hrm.emis.moe.gov.lk"; then
    echo "Hosts entries already present in $HOSTS_FILE, skipping."
    exit 0
fi

echo "Adding NEMIS domains to $HOSTS_FILE (requires sudo)..."
printf '\n%s\n%s\n' "$COMMENT" "$ENTRY" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "Done. Added:"
echo "  $ENTRY"
