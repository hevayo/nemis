#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# ─── Defaults ────────────────────────────────────────────────────────────
MODE="${1:-single}"   # "single" or "separate"

usage() {
    echo "Usage: $0 [single|separate]"
    echo ""
    echo "  single    - APIM + IS on same container (default)"
    echo "  separate  - APIM and IS on separate containers"
    exit 1
}

if [[ "$MODE" != "single" && "$MODE" != "separate" ]]; then
    usage
fi

echo "==> Mode: $MODE"

# ─── Prerequisites ───────────────────────────────────────────────────────
echo "==> Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose (v2) is not available."
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: Ansible is not installed."
    exit 1
fi

# Check for WSO2 resource zips
if ! ls ansible/resources/wso2am-*.zip 1>/dev/null 2>&1; then
    echo "Error: No wso2am-*.zip found in ansible/resources/"
    echo "       Download from https://wso2.com/api-manager/ and place it there."
    exit 1
fi

if ! ls ansible/resources/wso2is-*.zip 1>/dev/null 2>&1; then
    echo "Error: No wso2is-*.zip found in ansible/resources/"
    echo "       Download from https://wso2.com/identity-server/ and place it there."
    exit 1
fi

# Copy .env from example if it doesn't exist
if [ ! -f .env ]; then
    echo "==> Creating .env from .env.example..."
    cp .env.example .env
fi

# ─── Step 1: Start Docker containers ────────────────────────────────────
echo ""
echo "==> Step 1/6: Building and starting Docker containers (profile: $MODE)..."
docker compose --profile "$MODE" up -d --build

# ─── Step 2: Wait for MySQL and create WSO2 databases ───────────────────
echo ""
echo "==> Step 2/6: Waiting for MySQL to be healthy..."
until docker compose exec nemis-mysql mysqladmin ping -h localhost --silent 2>/dev/null; do
    sleep 2
done
echo "    MySQL is ready."

echo "==> Creating WSO2 databases..."
cd "$PROJECT_DIR/ansible"
ansible-playbook -i inventory/mysql.ini mysql-setup.yml

# ─── Step 3: Run Laravel migrations and seeders ──────────────────────────
echo ""
echo "==> Step 3/6: Running Laravel migrations and seeders..."
cd "$PROJECT_DIR"
echo "    Waiting for API container to be ready..."
until docker compose exec api php artisan --version &>/dev/null; do
    sleep 3
done
docker compose exec api php artisan migrate --force
docker compose exec api php artisan db:seed --force || echo "    Warning: Some seeders failed. You can re-run manually."

cd "$PROJECT_DIR/ansible"

# ─── Step 4: Wait for SSH and install WSO2 via Ansible ──────────────────
echo ""
echo "==> Step 4/6: Waiting for SSH..."

wait_for_ssh() {
    local port=$1
    local name=$2
    echo "    Waiting for $name (port $port)..."
    for i in $(seq 1 30); do
        if sshpass -p 123456 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -p "$port" nemis@127.0.0.1 echo "ready" 2>/dev/null; then
            echo "    $name SSH is ready."
            return 0
        fi
        sleep 2
    done
    echo "Error: Timed out waiting for $name SSH on port $port."
    exit 1
}

if [[ "$MODE" == "single" ]]; then
    wait_for_ssh 2222 "nemis-app"
    INVENTORY="inventory/local.ini"
    EXTRA_VARS="-e same_instance=true"
else
    wait_for_ssh 2222 "nemis-apim"
    wait_for_ssh 2223 "nemis-is"
    INVENTORY="inventory/local-separate.ini"
    EXTRA_VARS=""
fi

echo "==> Installing WSO2 APIM and IS..."
ansible-playbook -i "$INVENTORY" install.yml $EXTRA_VARS

# ─── Step 5: Start WSO2 services ────────────────────────────────────────
echo ""
echo "==> Step 5/6: Starting WSO2 services..."
ansible-playbook -i "$INVENTORY" start-stop.yml $EXTRA_VARS

echo "    Waiting for APIM and IS to fully start (this takes ~2 minutes)..."
# Wait for APIM
for i in $(seq 1 60); do
    if curl -sk -o /dev/null -w "%{http_code}" "https://localhost:9443/services/Version" 2>/dev/null | grep -qE '200|401|403'; then
        echo "    APIM is ready."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "Warning: APIM did not respond in time. You may need to wait longer or check logs."
    fi
    sleep 5
done

# Wait for IS
for i in $(seq 1 60); do
    if curl -sk -o /dev/null -w "%{http_code}" "https://localhost:9444/api/server/v1/configs" 2>/dev/null | grep -qE '200|401|403'; then
        echo "    IS is ready."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "Warning: IS did not respond in time. You may need to wait longer or check logs."
    fi
    sleep 5
done

# ─── Step 6: Configure IS as Key Manager in APIM ────────────────────────
echo ""
echo "==> Step 6/6: Configuring IS as Key Manager in APIM..."
ansible-playbook configure-is-and-apim.yml \
    -e @users-and-roles.yml \
    -e apim_hostname=localhost \
    -e is_hostname=localhost

echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo ""
echo "Services:"
echo "  Web (Vite):     http://localhost:5173"
echo "  API (Laravel):  http://localhost:8080"
echo "  MySQL:          localhost:3307"
echo "  APIM Console:   https://localhost:9443/carbon  (admin/admin)"
echo "  IS Console:     https://localhost:9444/carbon   (admin/admin)"
echo "  APIM Gateway:   https://localhost:8243"
echo "  SSH (WSO2):     ssh -p 2222 nemis@localhost     (nemis/123456)"
echo ""
