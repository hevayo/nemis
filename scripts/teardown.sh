#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "==> Stopping and removing containers..."
docker compose down

read -p "Remove volumes (database data, node_modules, vendor)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "==> Removing volumes..."
    docker compose down -v
    echo "Volumes removed."
else
    echo "Volumes preserved."
fi

echo "==> Teardown complete."
