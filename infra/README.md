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

All configuration is done through **GitHub repository secrets**. No manual SSH access is needed.

To add secrets: go to your repository on GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

---

### Step 1: Create a GitHub Fine-Grained Token (`GH_PAT`)

This token allows the infrastructure workflow to automatically save server IPs and SSH keys back as GitHub Secrets.

1. Go to [GitHub → Settings → Developer settings → Fine-grained personal access tokens](https://github.com/settings/personal-access-tokens/new)
2. Set **Token name** to something like `magento2-deploy`
3. Set **Expiration** as desired
4. Under **Repository access**, select **"Only select repositories"** and choose `magento2-docker`
5. Under **Permissions**, grant:
   - **Actions**: Read & Write *(needed to register the self-hosted runner)*
   - **Secrets**: Read & Write *(needed to auto-save server IPs and SSH key)*
6. Click **Generate token** and copy it
7. Add it as a repository secret named **`GH_PAT`**

---

### Step 2: Hetzner Cloud Token (`HCLOUD_TOKEN`)

This token lets the workflow create and manage your VPS instances.

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project (or create one)
3. Go to **Security** → **API Tokens** → **Generate API Token**
4. Set permissions to **Read & Write**
5. Copy the token and add it as a repository secret named **`HCLOUD_TOKEN`**

---

### Step 3 (Optional): Hetzner DNS Token (`HETZNER_DNS_TOKEN`)

If you want automatic DNS record management (recommended):

1. Go to [Hetzner DNS Console](https://dns.hetzner.com/) → **API Tokens**
2. Create a new token
3. Add it as a repository secret named **`HETZNER_DNS_TOKEN`**

If you skip this, you'll need to manually point your domains to the server IPs.

---

### Step 4: Magento Configuration

Most configuration lives in `infra/config.toml` — edit it to set admin details, SMTP settings, database names, domains, etc. **Only actual secrets (passwords) need to be GitHub Secrets:**

| Secret | Description |
|--------|-------------|
| `ADMIN_PASSWORD` | Magento admin password (letters + numbers required) |
| `SMTP_PASSWORD` | SMTP mail server password |
| `DB_PASSWORD` | MariaDB user password |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password |
| `OPENSEARCH_PASSWORD` | OpenSearch admin password |

In `config.toml`, these are referenced as `${SECRET_NAME}` placeholders. The deploy workflows inject them from GitHub Secrets at deploy time.

Staging inherits all values from production unless explicitly overridden in a `[staging.*]` section. See `infra/config.toml` for the full structure and examples.

---

### Step 5: Configure Servers

Edit `infra/config.toml` to set your server types, locations, domains, and all non-secret configuration. Commit and push to `master`.

---

### Step 6: Run Infrastructure Workflow

The infrastructure workflow runs automatically when you push changes to `infra/`. You can also trigger it manually: **Actions** → **Infrastructure** → **Run workflow**.

On first run, it will:
1. ✅ Create 2 Hetzner VPS instances (staging + production)
2. ✅ Install NixOS on both servers
3. ✅ Configure Docker, firewall, SSH hardening, swap
4. ✅ Set up a self-hosted GitHub Actions runner on staging
5. ✅ Configure DNS records (if `HETZNER_DNS_TOKEN` is set)
6. ✅ Auto-save `DEPLOY_SSH_PRIVATE_KEY`, `STAGING_HOST`, and `PRODUCTION_HOST` as GitHub Secrets

**No manual SSH required.** Everything is fully automated from this point on.

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
