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
    local existing_key
    existing_key=$(hcloud ssh-key describe "$key_name" -o json | jq -r '.public_key')
    if [ "$existing_key" = "$DEPLOY_SSH_PUBKEY" ]; then
      log "SSH key '$key_name' already matches, skipping."
      return
    fi
    # hcloud ssh-key update cannot change the public key, only labels.
    # Delete and recreate to ensure the key matches the current deploy key.
    log "SSH key already exists with different pubkey, replacing..."
    hcloud ssh-key delete "$key_name"
  fi
  log "Creating SSH key..."
  hcloud ssh-key create --name "$key_name" --public-key "$DEPLOY_SSH_PUBKEY"
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

    # Add any extra SSH keys from NixOS config so operators can inspect
    # the server while nixos-infect is running or if it fails.
    log "Adding SSH keys from NixOS config to Ubuntu authorized_keys..."
    grep -oP '"ssh-[^"]+' "$SCRIPT_DIR/nixos/configuration.nix" | tr -d '"' | while read -r key; do
      ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" \
        "grep -qF '${key}' ~/.ssh/authorized_keys 2>/dev/null || echo '${key}' >> ~/.ssh/authorized_keys" 2>/dev/null
    done

    log "Installing NixOS via nixos-infect..."
    # nixos-infect reboots the server at the end, which kills the SSH session.
    # We use nohup + background to let it run independently, then wait for reboot.
    ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<'INFECT'
      curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /tmp/nixos-infect
      # Workaround: on BIOS systems, $bootFs is unset causing "mv/cp .bak" to fail.
      # Prepend bootFs=/boot as a safe default for non-EFI systems.
      sed -i 's|rm -rf $bootFs.bak|bootFs="${bootFs:-/boot}"; rm -rf $bootFs.bak|' /tmp/nixos-infect
      nohup bash -c 'NIX_CHANNEL=nixos-24.11 bash /tmp/nixos-infect 2>&1 | tee /tmp/nixos-infect.log' &>/dev/null &
INFECT
    # Wait for nixos-infect to finish and reboot the server.
    # nixos-infect downloads Nix, builds NixOS, then reboots. On CX23 this
    # can take 10-15 minutes. We detect completion by waiting for SSH to drop
    # (reboot) and then come back (NixOS booted).
    log "Waiting for nixos-infect to reboot the server (up to 20 minutes)..."

    # Phase 1: wait for SSH to DROP (indicates reboot started)
    for i in $(seq 1 120); do
      if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" echo ok &>/dev/null; then
        log "SSH dropped — server is rebooting."
        break
      fi
      sleep 10
    done

    # Phase 2: wait for SSH to come back (NixOS booted)
    log "Waiting for NixOS to boot..."
    sleep 30
    for i in $(seq 1 60); do
      if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" "command -v nixos-rebuild" &>/dev/null; then
        log "NixOS is ready."
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

  # Ensure DNS zone exists (create if needed)
  if ! hcloud dns zone describe "$zone_name" &>/dev/null; then
    log "DNS zone '$zone_name' not found, creating..."
    if ! hcloud dns zone create --name "$zone_name" 2>&1; then
      log "WARNING: Failed to create DNS zone '$zone_name'. Set A record manually: $domain -> $ip"
      return
    fi
    log "DNS zone '$zone_name' created."
  fi

  # Extract record name (subdomain part)
  # For apex domain (domain == zone), use "@"; otherwise strip zone suffix
  local record_name
  if [ "$domain" = "$zone_name" ]; then
    record_name="@"
  else
    record_name="${domain%%.$zone_name}"
  fi

  # Create or update A record via hcloud CLI
  log "Setting DNS record: $record_name -> $ip"
  if hcloud dns rrset describe "$zone_name" "$record_name" A &>/dev/null; then
    # RRset exists — delete and recreate (hcloud has no upsert)
    log "Existing A record found, deleting..."
    hcloud dns rrset delete "$zone_name" "$record_name" A 2>&1 || true
  fi
  if hcloud dns rrset create "$zone_name" --name "$record_name" --type A --record "$ip" --ttl 300 2>&1; then
    log "DNS record set: $domain -> $ip"
  else
    log "WARNING: DNS update failed. Set A record manually: $domain -> $ip"
  fi
}
###############################################################################
# NixOS configuration push
###############################################################################

push_nixos_config() {
  local env="$1"
  local ip
  ip=$(hcloud server ip "magento2-$(cfg_get "servers.$env.hostname")")

  log "Pushing NixOS configuration to $env ($ip)..."

  # Inject deploy SSH public key into NixOS config before uploading
  local tmp_nixos
  tmp_nixos=$(mktemp -d)
  cp -r "$SCRIPT_DIR/nixos/"* "$tmp_nixos/"
  sed -i "s|# Will be populated by the infra workflow|\"$DEPLOY_SSH_PUBKEY\"|g" "$tmp_nixos/configuration.nix"
  log "Injected SSH key into NixOS config"

  # Copy NixOS config to server
  ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" "mkdir -p /etc/nixos"
  scp -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" -r \
    "$tmp_nixos/"* root@"$ip":/etc/nixos/
  rm -rf "$tmp_nixos"

  # Rebuild NixOS (skip if NixOS is not installed yet — nixos-infect may still be running)
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" \
    "command -v nixos-rebuild" &>/dev/null; then
    ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" <<EOF
      export PATH=/run/current-system/sw/bin:\$PATH
      # Ensure nixos-unstable channel exists (for newer github-runner package)
      nix-channel --list | grep -q nixos-unstable || {
        nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
        nix-channel --update nixos-unstable 2>&1 | tail -3
      }
      cd /etc/nixos
      nixos-rebuild switch 2>&1 | tail -20
EOF
    log "NixOS configuration applied to $env."
  else
    log "WARNING: nixos-rebuild not found on $env — NixOS may not be installed yet."
    log "  Run the infra workflow again after nixos-infect completes."
    log "  You can SSH in to inspect: ssh root@$ip"
  fi
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

  # Write PAT token file for NixOS services.github-runners module
  if [ -n "${GH_PAT:-}" ]; then
    ssh -o StrictHostKeyChecking=no -i "$DEPLOY_SSH_PRIVKEY_PATH" root@"$ip" bash <<EOF
      echo -n "$GH_PAT" > /etc/nixos/runner-token
      chmod 600 /etc/nixos/runner-token
      echo "https://github.com/${GITHUB_REPOSITORY}" > /etc/nixos/runner-repo
      echo "Runner token and repo URL written to /etc/nixos/"
EOF
    log "Runner config files written. NixOS will manage the runner service."
  else
    log "GH_PAT not set. Runner will not be configured."
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
    setup_github_runner "$env" || log "WARNING: Runner setup failed for $env (non-fatal)"
    push_nixos_config "$env"
  done

  log "Infrastructure provisioning complete!"
}

main "$@"
