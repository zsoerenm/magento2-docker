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
| `DEPLOY_SSH_PRIVATE_KEY` | SSH key for server access (auto-generated on first run) | Auto |
| `GH_PAT` | GitHub PAT with `repo` + `admin:org` for runner registration | Optional |
| `PRODUCTION_HOST` | Production server IP (set after first infra run) | After setup |

### 2. Configure Servers

Edit `servers.yaml` to set your desired server types, locations, and domains.

### 3. Run Infrastructure Workflow

Either push changes to `infra/` or manually trigger the "Infrastructure" workflow.

On first run:
1. Creates Hetzner VPS instances
2. Installs NixOS via nixos-infect
3. Configures Docker, firewall, SSH
4. Sets up GitHub Actions runner on staging
5. Configures DNS records

### 4. Configure Server Environment

SSH into each server and set up `.env` and secrets:

```bash
ssh root@<server-ip>
mkdir -p /opt/magento2/docker/secrets
# Create .env and secret files (see .env.example)
```

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
