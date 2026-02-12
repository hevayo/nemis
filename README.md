# NEMIS Monorepo

Monorepo consolidating the NEMIS React (Vite) web app, Laravel PHP API, and WSO2 infrastructure (API Manager + Identity Server) with Docker Compose for local development.

## Architecture

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│   Web    │───▶│   API    │───▶│  MySQL   │
│ Vite:5173│    │ PHP:8000 │    │   :3306  │
└──────────┘    └────┬─────┘    └──────────┘
                     │
              ┌──────┴──────┐
              │             │
         ┌────▼────┐  ┌────▼────┐
         │  APIM   │  │   IS    │
         │  :9443  │  │  :9444  │
         │  :8243  │  │         │
         └─────────┘  └─────────┘
```

- **Web**: React + Vite frontend
- **API**: Laravel PHP backend
- **DB**: MySQL 8.0
- **APIM**: WSO2 API Manager 4.3.0 (API gateway, developer portal)
- **IS**: WSO2 Identity Server 7.0.0 (authentication, OAuth2/OIDC)

WSO2 products are installed via Ansible into Docker containers running Ubuntu + SSH, using the same playbooks that target production servers.

## Prerequisites

- Docker & Docker Compose v2
- Ansible (on host machine)
- WSO2 distribution zips (see below)

## Quick Start

1. **Clone and configure**
   ```bash
   cp .env.example .env
   ```

2. **Copy your application code**
   ```bash
   # Copy your React app into web/
   # Copy your Laravel app into api/
   ```

3. **Download WSO2 distributions** and place them in:
   - `resources/apim/wso2am-4.3.0.zip`
   - `resources/is/wso2is-7.0.0.zip`

4. **Run setup**
   ```bash
   bash scripts/setup.sh
   ```

5. **Access services**

   | Service       | URL                                  | Credentials  |
   |---------------|--------------------------------------|-------------|
   | Web (Vite)    | http://localhost:5173                | —           |
   | API (Laravel) | http://localhost:8000                | —           |
   | MySQL         | localhost:3306                        | nemis/secret|
   | APIM Console  | https://localhost:9443/carbon         | admin/admin |
   | IS Console    | https://localhost:9444/carbon         | admin/admin |
   | APIM Gateway  | https://localhost:8243                | —           |

## Teardown

```bash
bash scripts/teardown.sh
```

## Project Structure

```
nemis-repo/
├── web/                    # React Vite frontend
├── api/                    # Laravel PHP backend
├── docker/
│   ├── web/Dockerfile      # Node 20 dev container
│   ├── api/Dockerfile      # PHP 8.2 + Composer
│   └── base-ssh/Dockerfile # Ubuntu + SSH + JDK 17 (for WSO2)
├── resources/
│   ├── apim/               # Place wso2am-4.3.0.zip here
│   └── is/                 # Place wso2is-7.0.0.zip here
├── ansible/
│   ├── inventory/
│   │   ├── local.yml       # Docker containers
│   │   └── production.yml  # Production servers
│   ├── roles/              # common, apim, is
│   ├── site.yml            # Master playbook
│   └── ansible.cfg
├── scripts/
│   ├── setup.sh            # Build + provision
│   └── teardown.sh         # Stop + cleanup
├── docker-compose.yml
├── .env.example
└── .gitignore
```

## Ansible

The same Ansible playbooks provision both local Docker containers and production servers. Switch between environments using the inventory flag:

```bash
# Local (Docker)
ansible-playbook -i ansible/inventory/local.yml ansible/site.yml

# Production
ansible-playbook -i ansible/inventory/production.yml ansible/site.yml
```

## Troubleshooting

**SSH connection refused to APIM/IS containers**
- Ensure containers are running: `docker compose ps`
- Check SSH is ready: `ssh -p 2222 root@127.0.0.1` (password: `root`)

**WSO2 fails to start**
- Check logs inside the container: `docker compose exec apim bash`, then look at `<wso2_home>/repository/logs/`
- Verify the zip file is correctly placed in `resources/`

**Port conflicts**
- Adjust ports in `.env` if defaults (5173, 8000, 3306, 9443, 9444, 8243) conflict with local services

**Database connection issues**
- Wait for the MySQL health check to pass: `docker compose ps` should show `healthy`
- Verify credentials in `.env` match those in your Laravel `.env`
