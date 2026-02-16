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

#### How to add a GitHub Secret

1. Go to your repository on GitHub (e.g. `https://github.com/your-username/your-repo`)
2. Click **Settings** (top menu bar, far right — you need admin access)
3. In the left sidebar, expand **Secrets and variables** → click **Actions**
4. Click the green **"New repository secret"** button
5. Enter the **Name** (e.g. `HCLOUD_TOKEN`) and **Secret** value
6. Click **"Add secret"**

Repeat for each secret listed below. Names must match exactly (uppercase, underscores).

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

1. Go to [Hetzner Console](https://console.hetzner.cloud/) → select your **project** → **DNS** (in the left sidebar)
   > **Note:** You must be inside a project to see the DNS entry in the sidebar. Hetzner DNS has moved from the old DNS Console (`dns.hetzner.com`) to the main Hetzner Console. New DNS zones can only be created there. Existing zones can be migrated via zone settings — see [Hetzner DNS FAQ](https://docs.hetzner.com/dns-console/dns/general/dns-console-moving/) for details.
2. Create an **API Token** for DNS management
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
| `STAGING_PASSWORD` | Basic auth password for staging site (keeps it private) |

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

- 2× CX23 (2 vCPU, 4 GB): ~€6.98/month (upgrade to CX33 or higher for production)
- No container registry needed
- No GitHub Actions minutes for builds (self-hosted runner)

## Creating Your Private Shop

This repository is a **GitHub template**. To build your own Magento shop on top of it, create a private repository from the template:

### 1. Create from template

On GitHub, click the green **"Use this template"** → **"Create a new repository"**. Set it to **Private** — it will contain your shop-specific code and configuration.

### 2. Customize

Add your shop-specific files. The template repo doesn't touch these paths, so upstream syncs stay clean:

```
your-private-repo/
├── infra/config.toml              # ← Edit: your real domains, server config, etc.
├── src/
│   ├── app/code/YourVendor/       # ← Your custom Magento modules
│   ├── app/design/frontend/       # ← Your custom theme
│   └── composer.json              # ← Add your dependencies
├── docker-compose.override.yml    # ← Optional: extra services, dev volumes
└── .github/workflows/             # ← Inherited from template, works as-is
```

### 3. Set up GitHub Secrets

Follow the [Setup (One-Time)](#setup-one-time) steps above in your private repo.

### 4. Syncing with upstream

When the template repo gets updates (Docker improvements, workflow fixes, dependency bumps), pull them into your repo:

```bash
# One-time: add the template repo as upstream remote
git remote add upstream https://github.com/zsoerenm/magento2-docker.git

# Fetch and merge upstream changes
git fetch upstream
git merge upstream/master --allow-unrelated-histories
```

> **Note:** The `--allow-unrelated-histories` flag is needed for the first merge because template repos don't share git history with the source. After the first successful merge, future syncs are just `git fetch upstream && git merge upstream/master` — no special flags needed.

If there are merge conflicts, they'll typically be in files like `docker-compose.yml` or `Dockerfile`s. Resolve them, test on staging (push to `master`), then create a release to deploy to production.

**Tip:** To stay informed about upstream changes, click **Watch** → **Releases only** on the template repo.
