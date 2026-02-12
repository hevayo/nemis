#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "==> Checking prerequisites..."

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check for docker compose
if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose (v2) is not available. Please install it."
    exit 1
fi

# Check for Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: Ansible is not installed. Please install Ansible first."
    exit 1
fi

# Check for WSO2 resource zips
if [ ! -f "resources/apim/wso2am-4.3.0.zip" ]; then
    echo "Warning: resources/apim/wso2am-4.3.0.zip not found."
    echo "         Download it from https://wso2.com/api-manager/ and place it in resources/apim/"
fi

if [ ! -f "resources/is/wso2is-7.0.0.zip" ]; then
    echo "Warning: resources/is/wso2is-7.0.0.zip not found."
    echo "         Download it from https://wso2.com/identity-server/ and place it in resources/is/"
fi

# Copy .env from example if it doesn't exist
if [ ! -f .env ]; then
    echo "==> Creating .env from .env.example..."
    cp .env.example .env
fi

echo "==> Building and starting Docker containers..."
docker compose up -d --build

echo "==> Waiting for SSH to be ready on APIM container (port 2222)..."
for i in $(seq 1 30); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -p 2222 root@127.0.0.1 echo "SSH ready" 2>/dev/null; then
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "Error: Timed out waiting for APIM SSH."
        exit 1
    fi
    sleep 2
done

echo "==> Waiting for SSH to be ready on IS container (port 2223)..."
for i in $(seq 1 30); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -p 2223 root@127.0.0.1 echo "SSH ready" 2>/dev/null; then
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "Error: Timed out waiting for IS SSH."
        exit 1
    fi
    sleep 2
done

echo "==> Running Ansible provisioning..."
cd "$PROJECT_DIR/ansible"
ansible-playbook -i inventory/local.yml site.yml

echo ""
echo "==> Setup complete!"
echo ""
echo "Services:"
echo "  Web (Vite):     http://localhost:5173"
echo "  API (Laravel):  http://localhost:8000"
echo "  MySQL:          localhost:3306"
echo "  APIM Console:   https://localhost:9443/carbon  (admin/admin)"
echo "  IS Console:     https://localhost:9444/carbon   (admin/admin)"
echo "  APIM Gateway:   https://localhost:8243"
