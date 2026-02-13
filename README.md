# NEMIS Monorepo

Monorepo for the NEMIS React (Vite) web app, Laravel PHP API, and WSO2 infrastructure (API Manager + Identity Server). Docker Compose for local development, Ansible for WSO2 provisioning (same playbooks for local and production).

---

## Developer Guide

### Prerequisites

Install these on your machine before starting:

```bash
# Docker (follow https://docs.docker.com/engine/install/ubuntu/)
# Then install Ansible and sshpass:
sudo apt-add-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible sshpass
```

Also install the Ansible MySQL collection (needed for database setup):

```bash
ansible-galaxy collection install community.mysql
```

### First-time setup

```bash
# 1. Clone with submodules
git clone --recurse-submodules git@github.com:<org>/nemis-repo.git
cd nemis-repo

# 2. Copy environment file
cp .env.example .env

# 3. Download WSO2 distributions and place them in ansible/resources/
#    - wso2am-4.6.0.zip   (from https://wso2.com/api-manager/)
#    - wso2is-7.2.0.zip   (from https://wso2.com/identity-server/)

# 4. Add local domain names to /etc/hosts
bash scripts/setup-hosts.sh

# 5. Run the setup script (single-instance mode — APIM + IS in one container)
bash scripts/setup.sh
```

That's it. The script handles the full setup in 5 steps:

1. Builds and starts Docker containers (web, api, mysql, wso2)
2. Waits for MySQL and creates 4 WSO2 databases (apim_db, apim_shared_db, is_db, is_shared_db)
3. Waits for SSH and installs WSO2 APIM + IS via Ansible
4. Starts WSO2 services and waits for them to be healthy (~2 minutes)
5. Configures IS as Key Manager in APIM, creates roles, APIs, apps, and M2M credentials

The configure playbook will output the OAuth credentials you need for your `.env`.

### Day-to-day commands

```bash
# Start/stop/restart WSO2 services (single-instance mode)
cd ansible
ansible-playbook -i inventory/local.ini start-stop.yml -e same_instance=true                     # start (default)
ansible-playbook -i inventory/local.ini start-stop.yml -e wso2_action=stop -e same_instance=true  # stop
ansible-playbook -i inventory/local.ini start-stop.yml -e wso2_action=restart -e same_instance=true

# Re-run configuration (e.g. after rebuilding containers)
cd ansible
ansible-playbook configure-is-and-apim.yml \
    -e @users-and-roles.yml \
    -e apim_hostname=localhost \
    -e is_hostname=localhost

# Stop all containers
bash scripts/teardown.sh

# Rebuild WSO2 container from scratch
docker compose --profile single rm -s -f nemis-app
docker compose --profile single up -d --build nemis-app

# SSH into the WSO2 container
sshpass -p 123456 ssh -p 2222 nemis@localhost

# View WSO2 logs
docker compose exec nemis-app cat /var/log/wso2/wso2-apim.log
docker compose exec nemis-app cat /var/log/wso2/wso2-is.log

# Run the teacher creation test
cd ansible
ansible-playbook test-create-teacher.yml -i inventory/local.ini -e bearer_token=<your_token>
```

### Switching between single and separate instance modes

**Single instance** (default) — APIM + IS share one container:
```bash
bash scripts/setup.sh single
# Uses inventory/local.ini, passes -e same_instance=true to Ansible
```

**Separate instances** — APIM and IS on their own containers:
```bash
bash scripts/setup.sh separate
# Uses inventory/local-separate.ini, two SSH-enabled containers
```

Both modes are fully automated — the setup script handles containers, databases, installation, startup, and configuration.

### Service URLs

An nginx reverse proxy terminates SSL and routes requests by domain name, matching production URLs. Self-signed certificates are generated automatically on first run.

| Service       | URL (via nginx)                              | Direct URL                     | Credentials     |
|---------------|----------------------------------------------|--------------------------------|-----------------|
| Web (Vite)    | https://hrm.emis.moe.gov.lk                 | http://localhost:5173          | -               |
| API (Laravel) | -                                            | http://localhost:8080          | -               |
| APIM Console  | https://apim.emis.moe.gov.lk/carbon         | https://localhost:9443/carbon  | admin / admin   |
| IS Console    | https://identity.emis.moe.gov.lk/carbon     | https://localhost:9444/carbon  | admin / admin   |
| APIM Gateway  | -                                            | https://localhost:8243         | -               |
| MySQL         | -                                            | localhost:3307                 | root / root     |
| SSH (WSO2)    | -                                            | localhost:2222                 | nemis / 123456  |

> **Note:** The nginx URLs require `/etc/hosts` entries (added by `scripts/setup-hosts.sh`). Your browser will show a self-signed certificate warning on first visit — accept it to proceed.

---

## Architecture

```
                          ┌──────────────────────┐
                          │    Nginx (SSL :443)   │
                          │  hrm.emis.moe.gov.lk  │
                          │  apim.emis.moe.gov.lk │
                          │  identity.emis...      │
                          └───┬──────┬──────┬─────┘
                              │      │      │
                 ┌────────────┘      │      └────────────┐
                 ▼                   ▼                   ▼
          ┌──────────┐        ┌──────────┐        ┌──────────┐
          │   Web    │        │  APIM    │        │   IS     │
          │ Vite:5173│        │  :9443   │        │  :9444   │
          └────┬─────┘        │  :8243   │        └──────────┘
               │              └────┬─────┘
               ▼                   │
          ┌──────────┐             │
          │   API    │             │
          │ PHP:8080 │             │
          └────┬─────┘             │
               │                   │
               ▼                   ▼
          ┌────────────────────────────┐
          │          MySQL :3306       │
          └────────────────────────────┘
```

- **Web**: React + Vite frontend (git submodule: `nemis-react`)
- **API**: Laravel PHP backend (git submodule: `cemis-lk`)
- **MySQL**: Application database + 4 WSO2 databases
- **APIM**: WSO2 API Manager 4.6.0 — API gateway, developer portal, rate limiting
- **IS**: WSO2 Identity Server 7.2.0 — authentication, OAuth2/OIDC, user management

WSO2 products are installed via Ansible into Docker containers running Ubuntu + SSH. The same Ansible playbooks target production servers with a different inventory file.

## Project Structure

```
nemis-repo/
├── web/                          # React Vite frontend (git submodule)
├── api/                          # Laravel PHP backend (git submodule)
├── docker/
│   ├── web/Dockerfile            # Node 20 dev container
│   ├── api/Dockerfile            # PHP 8.3 + Composer
│   ├── base-ssh/Dockerfile       # Ubuntu 22.04 + SSH (for WSO2)
│   └── nginx/
│       ├── Dockerfile            # nginx:alpine + openssl
│       ├── nginx.conf            # Reverse proxy config (3 domains)
│       └── generate-certs.sh     # Self-signed cert generator
├── ansible/
│   ├── inventory/
│   │   ├── local.ini             # Single-instance (same SSH port)
│   │   ├── local-separate.ini    # Separate containers
│   │   ├── production.ini        # Production servers
│   │   └── mysql.ini             # MySQL setup (localhost)
│   ├── roles/
│   │   ├── common/               # apt update, Java 21, service user
│   │   ├── apim/                 # Install APIM, configure deployment.toml, init script
│   │   └── is/                   # Install IS, configure deployment.toml, init script
│   ├── resources/                # WSO2 zips + JARs (zips gitignored)
│   ├── install.yml               # Install APIM + IS + certificate exchange
│   ├── start-stop.yml            # Start/stop/restart WSO2 services
│   ├── configure-is-and-apim.yml # Post-install: KM, roles, APIs, apps, M2M
│   ├── mysql-setup.yml           # Create and seed WSO2 databases
│   ├── users-and-roles.yml       # Roles, APIs, and apps configuration
│   ├── test-create-teacher.yml   # End-to-end teacher creation test
│   ├── site.yml                  # Master playbook (install + start)
│   └── ansible.cfg
├── scripts/
│   ├── setup.sh                  # Docker up + Ansible provision
│   ├── setup-hosts.sh            # Add domain entries to /etc/hosts
│   └── teardown.sh               # Docker down + optional volume cleanup
├── docker-compose.yml            # Profiles: single, separate
├── .env.example
└── .gitignore
```

## Ansible Playbooks

| Playbook                     | Purpose                                                    |
|------------------------------|------------------------------------------------------------|
| `install.yml`                | Install APIM + IS, configure deployment.toml, cert exchange|
| `start-stop.yml`             | Start/stop/restart WSO2 services via init scripts          |
| `mysql-setup.yml`            | Create 4 WSO2 databases, import schemas, grant privileges  |
| `configure-is-and-apim.yml`  | Register IS as KM, create roles/users/APIs/apps/M2M        |
| `site.yml`                   | Master playbook (install + start)                          |
| `test-create-teacher.yml`    | End-to-end test: create teacher via APIM gateway           |

### Production deployment

Same playbooks, different inventory. The `configure-is-and-apim.yml` playbook defaults to production hostnames (`apim.emis.moe.gov.lk` / `is.emis.moe.gov.lk`), so no hostname overrides are needed:

```bash
cd ansible
ansible-playbook -i inventory/production.ini install.yml
ansible-playbook -i inventory/production.ini start-stop.yml
ansible-playbook -i inventory/production.ini mysql-setup.yml
ansible-playbook configure-is-and-apim.yml -e @users-and-roles.yml
```

For local development, `setup.sh` automatically passes `-e apim_hostname=localhost -e is_hostname=localhost`.

## Troubleshooting

**SSH connection refused**
- Ensure containers are running: `docker compose --profile single ps`
- Test SSH: `sshpass -p 123456 ssh -p 2222 nemis@localhost`

**WSO2 fails to start**
- Check logs inside the container:
  ```bash
  docker compose exec nemis-app cat /var/log/wso2/wso2-apim.log
  docker compose exec nemis-app cat /var/log/wso2/wso2-is.log
  ```
- Verify zip files exist in `ansible/resources/`
- Check Java: `docker compose exec nemis-app java -version`

**Port conflicts**
- Adjust ports in `.env` if defaults conflict with local services

**Database errors**
- Wait for MySQL healthcheck: `docker compose ps` should show `healthy`
- Re-run database setup: `ansible-playbook -i inventory/mysql.ini mysql-setup.yml`
- Check MySQL connectivity: `mysql -h 127.0.0.1 -P 3307 -u root -proot`

**configure-is-and-apim fails**
- Both APIM and IS must be fully started (takes ~2 minutes after restart)
- The playbook waits and retries, but if it times out, just re-run it

**Rebuilding from scratch**
```bash
bash scripts/teardown.sh              # answer 'y' to remove volumes
bash scripts/setup.sh                 # rebuild everything
```
