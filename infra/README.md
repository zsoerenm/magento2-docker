# Infrastructure

This directory contains everything needed to provision and manage the Magento 2 hosting infrastructure on Hetzner Cloud.

## Architecture

```
┌─────────────────┐     merge to main     ┌─────────────────┐
│   GitHub Repo   │ ───────────────────── │  Staging VPS    │
│                 │                        │  (self-hosted   │
│  infra/         │     new release        │   GH runner)    │
│  docker/        │ ──────────┐            │                 │
│  src/           │           │            │  Builds images  │
│  workflows/     │           │            │  Deploys staging│
└─────────────────┘           │            └────────┬────────┘
                              │                     │
                              │            docker save | ssh
                              │                     │
                              │            ┌────────▼────────┐
                              └──────────▶ │  Production VPS │
                                           │                 │
                                           │  docker load    │
                                           │  docker up      │
                                           └─────────────────┘
```

## Setup (One-Time)

### 1. GitHub Secrets

Add these secrets to your repository:

| Secret | Description | Required |
|--------|-------------|----------|
| `HCLOUD_TOKEN` | Hetzner Cloud API token | ✅ |
| `HETZNER_DNS_TOKEN` | Hetzner DNS API token (for automatic DNS) | Optional |
| `DEPLOY_SSH_PRIVATE_KEY` | SSH key for server access (auto-saved on first run) | Auto |
| `GH_PAT` | Fine-grained GitHub PAT (see below) | ✅ |
| `PRODUCTION_HOST` | Production server IP (auto-saved by infra workflow) | Auto |
| `STAGING_HOST` | Staging server IP (auto-saved by infra workflow) | Auto |

### 2. Create `GH_PAT` (Fine-Grained Token)

Create a **fine-grained personal access token** at GitHub → Settings → Developer settings → Fine-grained tokens:

- **Repository access**: Only select `magento2-docker`
- **Permissions**:
  - **Actions**: Read & Write (runner registration)
  - **Secrets**: Read & Write (auto-save server IPs & SSH key)

Save it as the `GH_PAT` secret.

### 3. GitHub Secrets for Magento Environment

These are written to `.env` and `docker/secrets/` on each server automatically by the deploy workflows.

| Secret | Description |
|--------|-------------|
| `BACKEND_FRONTNAME` | Admin URL path (e.g. `admin_xyz`) |
| `ADMIN_EMAIL` | Admin email |
| `ADMIN_FIRSTNAME` | Admin first name |
| `ADMIN_LASTNAME` | Admin last name |
| `ADMIN_PASSWORD` | Admin password |
| `TRANS_EMAIL_NAME` | Store transactional email name |
| `TRANS_EMAIL_ADDRESS` | Store transactional email address |
| `SMTP_TRANSPORT` | SMTP transport (e.g. `smtp`) |
| `SMTP_HOST` | SMTP server host |
| `SMTP_PORT` | SMTP port (e.g. `587`) |
| `SMTP_USERNAME` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |
| `SMTP_AUTH` | SMTP auth type (`login`, `plain`, `none`) |
| `SMTP_SSL` | SMTP encryption (`tls`, `ssl`) |
| `DB_USER` | Database user |
| `DB_NAME` | Database name |
| `DB_PASSWORD` | Database password |
| `MYSQL_ROOT_PASSWORD` | MySQL root password |
| `OPENSEARCH_PASSWORD` | OpenSearch admin password |
| `CADDY_EMAIL` | Email for Let's Encrypt |


Domains are read from `infra/servers.yaml` — no need to duplicate them as secrets.

### 4. Configure Servers

Edit `servers.yaml` to set your desired server types, locations, and domains.

### 5. Run Infrastructure Workflow

Either push changes to `infra/` or manually trigger the "Infrastructure" workflow.

On first run:
1. Creates Hetzner VPS instances
2. Installs NixOS via nixos-infect
3. Configures Docker, firewall, SSH
4. Sets up GitHub Actions runner on staging
5. Configures DNS records

**No manual SSH required.** The deploy workflows automatically write `.env` and secrets from GitHub Secrets.

## Workflows

| Workflow | Trigger | Runner | Action |
|----------|---------|--------|--------|
| `infra.yml` | Push to `infra/` | GitHub-hosted | Provision/update servers |
| `deploy-staging.yml` | Push to `main` | Self-hosted (staging) | Build & deploy to staging |
| `deploy-production.yml` | New release | Self-hosted (staging) | Build, push & deploy to production |

## Cost Estimate

- 2× CX22 (2 vCPU, 4 GB): ~€8.70/month
- No container registry needed
- No GitHub Actions minutes for builds (self-hosted runner)

## Extending (Private Repo)

Your private repo can extend this setup:

1. Add this repo as a git submodule or reference
2. Add `docker-compose.override.yml` with custom services/volumes
3. Copy/extend the deploy workflows
4. Server `.env` files contain your shop-specific configuration
