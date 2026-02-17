#!/usr/bin/env bash
# Provision and reconcile Hetzner Cloud infrastructure
# Idempotent: safe to run multiple times
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/config.toml"

# Requires: HCLOUD_TOKEN, DEPLOY_SSH_PUBKEY, DEPLOY_SSH_PRIVKEY_PATH
# DNS management uses HCLOUD_TOKEN (Cloud API) — no separate DNS token needed

###############################################################################
# Helpers
###############################################################################

log() { echo "==> $*"; }
err() { echo "ERROR: $*" >&2; exit 1; }

cfg_get() {
  # TOML value extraction (requires python3 with tomllib, available in 3.11+)
  python3 -c "
import tomllib
with open('$CONFIG', 'rb') as f:
    data = tomllib.load(f)
keys = '$1'.split('.')
val = data
for k in keys:
    val = val[k]
print(val)
"
}

###############################################################################
# SSH Key
###############################################################################

ensure_ssh_key() {
  local key_name
  key_name=$(cfg_get "hetzner.ssh_key_name")

  log "Ensuring SSH key '$key_name' exists in Hetzner Cloud..."

  if hcloud ssh-key describe "$key_name" &>/dev/null; then
    log "SSH key already exists, updating..."
    hcloud ssh-key update "$key_name" --public-key "$DEPLOY_SSH_PUBKEY" 2>/dev/null || true
  else
    log "Creating SSH key..."
    hcloud ssh-key create --name "$key_name" --public-key "$DEPLOY_SSH_PUBKEY"
  fi
}

###############################################################################
# Server provisioning
###############################################################################

ensure_server() {
  local env="$1"
  local server_type location hostname
  server_type=$(cfg_get "servers.$env.server_type")
  location=$(cfg_get "servers.$env.location")
  hostname=$(cfg_get "servers.$env.hostname")

  local server_name="magento2-$hostname"
  local ssh_key_name
  ssh_key_name=$(cfg_get "hetzner.ssh_key_name")

  log "Ensuring server '$server_name' ($server_type @ $location)..."

  if hcloud server describe "$server_name" &>/dev/null; then
    log "Server '$server_name' already exists."

    # Check if server type matches; resize if needed
    local current_type
    current_type=$(hcloud server describe "$server_name" -o json | jq -r '.server_type.name')
    if [ "$current_type" != "$server_type" ]; then
      log "Server type mismatch ($current_type != $server_type). Resizing..."
      hcloud server shutdown "$server_name" --poll-interval 5s || true
      sleep 5
      hcloud server change-type "$server_name" --server-type "$server_type" --keep-disk
      hcloud server poweron "$server_name" --poll-interval 5s
      log "Server resized and restarted."
    fi
  else
    log "Creating server '$server_name'..."
    hcloud server create \
      --name "$server_name" \
      --type "$server_type" \
      --location "$location" \
      --image ubuntu-24.04 \
      --ssh-key "$ssh_key_name" \
      --poll-interval 5s

    log "Server created. Waiting for SSH..."
    local ip
    ip=$(hcloud server ip "$server_name")
    for i in $(seq 1 30); do
      if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" echo ok 2>/dev/null; then
        break
      fi
      sleep 5
    done

    log "Installing NixOS via nixos-infect..."
    ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<'INFECT'
      curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
        NIX_CHANNEL=nixos-24.11 bash -x 2>&1 | tail -20
INFECT

    log "Waiting for reboot after nixos-infect..."
    sleep 30
    for i in $(seq 1 30); do
      if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" echo ok 2>/dev/null; then
        break
      fi
      sleep 10
    done
  fi

  # Output the server IP for later use
  local ip
  ip=$(hcloud server ip "$server_name")
  echo "SERVER_IP_${env^^}=$ip" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  log "Server '$server_name' ready at $ip"
}

###############################################################################
# DNS
###############################################################################

ensure_dns() {
  local env="$1"
  local domain ip
  domain=$(cfg_get "servers.$env.domain")
  ip=$(hcloud server ip "magento2-$(cfg_get "servers.$env.hostname")")

  if [ -z "${HCLOUD_TOKEN:-}" ]; then
    log "HCLOUD_TOKEN not set, skipping DNS for $domain"
    return
  fi

  local zone_name
  zone_name=$(cfg_get "dns.zone")

  log "Setting up DNS: $domain -> $ip"

  # Get zone ID via Cloud API
  local zone_id
  zone_id=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
    "https://api.hetzner.cloud/v1/zones" | \
    jq -r ".zones[] | select(.name == \"$zone_name\") | .id")

  if [ -z "$zone_id" ]; then
    err "DNS zone '$zone_name' not found. Create it in Hetzner Console → project → DNS first."
  fi

  # Extract record name (subdomain part)
  local record_name="${domain%%.$zone_name}"

  # Upsert A record via Cloud API RRset endpoint
  log "Setting DNS record: $record_name.$zone_name -> $ip"
  local response
  response=$(curl -s -w "\n%{http_code}" -X PUT \
    -H "Authorization: Bearer $HCLOUD_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg ip "$ip" '{ttl: 300, records: [{value: $ip}]}')" \
    "https://api.hetzner.cloud/v1/zones/$zone_id/rrsets/$record_name/A")

  local http_code
  http_code=$(echo "$response" | tail -1)
  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    log "DNS record set: $domain -> $ip"
  else
    log "WARNING: DNS update failed (HTTP $http_code). Set A record manually: $domain -> $ip"
    log "Response: $(echo "$response" | head -1)"
  fi
}

###############################################################################
# Mail server (production only)
###############################################################################

ensure_mail() {
  local env="$1"

  # Only run for production
  if [ "$env" != "production" ]; then
    return
  fi

  local mail_domain
  mail_domain=$(python3 -c "
import tomllib
with open('$CONFIG', 'rb') as f:
    data = tomllib.load(f)
print(data.get('mail', {}).get('domain', ''))
") || true

  if [ -z "$mail_domain" ]; then
    log "mail.domain not set in config.toml, skipping mail setup."
    return
  fi

  local mail_admin_email
  mail_admin_email=$(python3 -c "
import tomllib
with open('$CONFIG', 'rb') as f:
    data = tomllib.load(f)
print(data.get('mail', {}).get('admin_email', ''))
") || true

  local domain ip server_name
  domain=$(cfg_get "servers.$env.domain")
  server_name="magento2-$(cfg_get "servers.$env.hostname")"
  ip=$(hcloud server ip "$server_name")

  local zone_name zone_id
  zone_name=$(cfg_get "dns.zone")

  log "Setting up mail server: $mail_domain"

  # Get DNS zone ID
  zone_id=$(curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" \
    "https://api.hetzner.cloud/v1/zones" | \
    jq -r ".zones[] | select(.name == \"$zone_name\") | .id")

  if [ -z "$zone_id" ]; then
    log "WARNING: DNS zone '$zone_name' not found. Skipping mail DNS records."
  else
    # MX record for base domain -> mail subdomain
    local base_record_name="${zone_name}"
    if [ "$zone_name" = "$zone_name" ]; then
      base_record_name="@"
    fi
    log "Setting MX record: $zone_name -> $mail_domain"
    curl -s -X PUT \
      -H "Authorization: Bearer $HCLOUD_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg val "10 $mail_domain." '{ttl: 300, records: [{value: $val}]}')" \
      "https://api.hetzner.cloud/v1/zones/$zone_id/rrsets/@/MX" > /dev/null

    # A record for mail subdomain
    local mail_record_name="${mail_domain%%.$zone_name}"
    log "Setting A record: $mail_domain -> $ip"
    curl -s -X PUT \
      -H "Authorization: Bearer $HCLOUD_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg ip "$ip" '{ttl: 300, records: [{value: $ip}]}')" \
      "https://api.hetzner.cloud/v1/zones/$zone_id/rrsets/$mail_record_name/A" > /dev/null

    # SPF record
    log "Setting SPF record for $zone_name"
    curl -s -X PUT \
      -H "Authorization: Bearer $HCLOUD_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg val "\"v=spf1 ip4:$ip -all\"" '{ttl: 300, records: [{value: $val}]}')" \
      "https://api.hetzner.cloud/v1/zones/$zone_id/rrsets/@/TXT" > /dev/null

    # DMARC record
    log "Setting DMARC record for $zone_name"
    curl -s -X PUT \
      -H "Authorization: Bearer $HCLOUD_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(jq -n --arg val "\"v=DMARC1; p=reject; rua=mailto:postmaster@$zone_name\"" '{ttl: 300, records: [{value: $val}]}')" \
      "https://api.hetzner.cloud/v1/zones/$zone_id/rrsets/_dmarc/TXT" > /dev/null
  fi

  # Set reverse DNS (PTR)
  log "Setting reverse DNS: $ip -> $mail_domain"
  hcloud server set-rdns --server "$server_name" --ip "$ip" --rdns "$mail_domain" 2>/dev/null || \
    log "WARNING: Could not set reverse DNS. You may need to do this manually."

  # Copy mail config to server
  log "Copying mail configuration to server..."
  scp -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" -r \
    "$SCRIPT_DIR/mail" root@"$ip":/opt/stalwart-mail/

  # Copy docker-compose.yml to the right place
  ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<EOF
    cp /opt/stalwart-mail/mail/docker-compose.yml /opt/stalwart-mail/docker-compose.yml
EOF

  # Run setup script on server
  log "Running mail setup on server..."
  local stalwart_admin_password="${STALWART_ADMIN_PASSWORD:-$(openssl rand -base64 24)}"

  DKIM_OUTPUT=$(ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" \
    "MAIL_DOMAIN='$mail_domain' MAIL_ADMIN_EMAIL='$mail_admin_email' STALWART_ADMIN_PASSWORD='$stalwart_admin_password' bash /opt/stalwart-mail/mail/setup-mail.sh")

  echo "$DKIM_OUTPUT"

  # Copy mail.caddy to production server's Caddy conf.d
  log "Setting up Caddy reverse proxy for mail web UI..."
  ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<EOF
    mkdir -p /opt/magento2/docker/caddy/conf.d
    cp /opt/stalwart-mail/mail/mail.caddy /opt/magento2/docker/caddy/conf.d/mail.caddy
EOF

  # Extract DKIM records from server and create DNS entries
  if [ -n "$zone_id" ]; then
    log "Retrieving DKIM records from Stalwart..."
    local dns_json
    dns_json=$(ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" \
      "cat /opt/stalwart-mail/dns-records.json 2>/dev/null || echo '[]'")

    if [ "$dns_json" != "[]" ] && [ -n "$dns_json" ]; then
      # Parse DKIM TXT records from Stalwart's DNS output and create them
      # Stalwart returns records as an array of {type, name, content} objects
      echo "$dns_json" | jq -r '.[] | select(.type == "TXT" and (.name | contains("_domainkey"))) | "\(.name) \(.content)"' 2>/dev/null | \
      while IFS=' ' read -r record_name record_value; do
        if [ -n "$record_name" ] && [ -n "$record_value" ]; then
          # Extract subdomain part relative to zone
          local dkim_name="${record_name%%.$zone_name}"
          dkim_name="${dkim_name%.}"  # Remove trailing dot
          log "Setting DKIM record: $record_name"
          curl -s -X PUT \
            -H "Authorization: Bearer $HCLOUD_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg val "\"$record_value\"" '{ttl: 300, records: [{value: $val}]}')" \
            "https://api.hetzner.cloud/v1/zones/$zone_id/rrsets/$dkim_name/TXT" > /dev/null
        fi
      done
      log "DKIM DNS records created."
    else
      log "WARNING: Could not retrieve DKIM records from Stalwart. Set them manually from the Stalwart web UI."
    fi
  fi

  log "Mail server setup complete for $mail_domain"
  log "Stalwart web UI: https://$mail_domain"
  log "Admin password: $stalwart_admin_password"
  log "⚠️  Remember to contact Hetzner support to unblock port 25 for SMTP!"
}

###############################################################################
# NixOS configuration push
###############################################################################

push_nixos_config() {
  local env="$1"
  local ip
  ip=$(hcloud server ip "magento2-$(cfg_get "servers.$env.hostname")")

  log "Pushing NixOS configuration to $env ($ip)..."

  # Copy NixOS config to server
  scp -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" -r \
    "$SCRIPT_DIR/nixos/"* root@"$ip":/etc/nixos/

  # Set the server role and rebuild
  ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<EOF
    export SERVER_ROLE=$env
    cd /etc/nixos
    nixos-rebuild switch 2>&1 | tail -20
EOF

  log "NixOS configuration applied to $env."
}

###############################################################################
# GitHub Actions runner (staging only)
###############################################################################

setup_github_runner() {
  local env="$1"
  local has_runner
  has_runner=$(cfg_get "servers.$env.github_runner")

  if [ "$has_runner" != "True" ] && [ "$has_runner" != "true" ]; then
    return
  fi

  local ip
  ip=$(hcloud server ip "magento2-$(cfg_get "servers.$env.hostname")")

  log "Setting up GitHub Actions runner on $env ($ip)..."

  ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<'RUNNER'
    # Create runner user if not exists
    id -u runner &>/dev/null || useradd -m -s /bin/bash runner
    usermod -aG docker runner

    RUNNER_DIR="/home/runner/actions-runner"

    if [ -f "$RUNNER_DIR/.runner" ]; then
      echo "GitHub Actions runner already configured"
      exit 0
    fi

    mkdir -p "$RUNNER_DIR"
    cd "$RUNNER_DIR"

    # Download latest runner
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
    curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | tar xz

    chown -R runner:runner "$RUNNER_DIR"

    echo "Runner downloaded. Registration requires GITHUB_RUNNER_TOKEN."
    echo "Run: sudo -u runner ./config.sh --url https://github.com/OWNER/REPO --token TOKEN --unattended --labels self-hosted,staging"
RUNNER

  # If we have a runner token, register it
  if [ -n "${GITHUB_RUNNER_TOKEN:-}" ]; then
    ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<EOF
      cd /home/runner/actions-runner
      sudo -u runner ./config.sh \
        --url "https://github.com/${GITHUB_REPOSITORY}" \
        --token "$GITHUB_RUNNER_TOKEN" \
        --unattended \
        --labels "self-hosted,staging" \
        --replace
      ./svc.sh install runner
      ./svc.sh start
EOF
    log "GitHub Actions runner registered and started."
  else
    log "GITHUB_RUNNER_TOKEN not set. Runner downloaded but not registered."
  fi
}

###############################################################################
# Main
###############################################################################

main() {
  command -v hcloud &>/dev/null || err "hcloud CLI not found. Install: https://github.com/hetznercloud/cli"
  [ -n "${HCLOUD_TOKEN:-}" ] || err "HCLOUD_TOKEN is required"
  [ -n "${DEPLOY_SSH_PUBKEY:-}" ] || err "DEPLOY_SSH_PUBKEY is required"
  [ -n "${DEPLOY_SSH_PRIVKEY_PATH:-}" ] || err "DEPLOY_SSH_PRIVKEY_PATH is required"

  ensure_ssh_key

  for env in staging production; do
    ensure_server "$env"
    ensure_dns "$env"
    ensure_mail "$env"
    push_nixos_config "$env"
    setup_github_runner "$env"
  done

  log "Infrastructure provisioning complete!"
}

main "$@"
