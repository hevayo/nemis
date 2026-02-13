#!/bin/sh
set -e

CERT_DIR="/etc/nginx/certs"
DOMAINS="hrm.emis.moe.gov.lk apim.emis.moe.gov.lk identity.emis.moe.gov.lk service.emis.moe.gov.lk"

mkdir -p "$CERT_DIR"

for domain in $DOMAINS; do
    if [ ! -f "$CERT_DIR/$domain.crt" ]; then
        echo "Generating self-signed certificate for $domain ..."
        openssl req -x509 -nodes -days 365 \
            -newkey rsa:2048 \
            -keyout "$CERT_DIR/$domain.key" \
            -out    "$CERT_DIR/$domain.crt" \
            -subj   "/CN=$domain" \
            -addext "subjectAltName=DNS:$domain" \
            2>/dev/null
    else
        echo "Certificate for $domain already exists, skipping."
    fi
done
