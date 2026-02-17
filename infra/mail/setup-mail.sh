#!/usr/bin/env bash
# Mail server provisioning — runs on the TARGET SERVER via SSH
# Called from provision.sh
set -euo pipefail

MAIL_DOMAIN="${MAIL_DOMAIN:?MAIL_DOMAIN is required}"
MAIL_ADMIN_EMAIL="${MAIL_ADMIN_EMAIL:-admin@$MAIL_DOMAIN}"
STALWART_ADMIN_PASSWORD="${STALWART_ADMIN_PASSWORD:?STALWART_ADMIN_PASSWORD is required}"
MAIL_DIR="${MAIL_DIR:-/opt/stalwart-mail}"

log() { echo "==> $*"; }

###############################################################################
# Shared proxy network
###############################################################################

log "Ensuring shared-proxy Docker network exists..."
docker network inspect shared-proxy &>/dev/null || \
  docker network create shared-proxy

###############################################################################
# Deploy Stalwart
###############################################################################

log "Setting up Stalwart mail server for $MAIL_DOMAIN..."

mkdir -p "$MAIL_DIR"
cd "$MAIL_DIR"

# Write .env for docker compose
cat > .env <<EOF
MAIL_DOMAIN=$MAIL_DOMAIN
MAIL_ADMIN_EMAIL=$MAIL_ADMIN_EMAIL
STALWART_ADMIN_PASSWORD=$STALWART_ADMIN_PASSWORD
EOF
chmod 600 .env

# Start Stalwart
log "Starting Stalwart..."
docker compose up -d

# Wait for healthy
log "Waiting for Stalwart to become healthy..."
for i in $(seq 1 60); do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' stalwart-mail 2>/dev/null || echo "starting")
  if [ "$STATUS" = "healthy" ]; then
    log "Stalwart is healthy!"
    break
  fi
  if [ "$i" = "60" ]; then
    log "WARNING: Stalwart did not become healthy within timeout"
    docker logs stalwart-mail --tail 20
    exit 1
  fi
  sleep 5
done

###############################################################################
# Create domain and extract DKIM records
###############################################################################

log "Creating domain $MAIL_DOMAIN in Stalwart..."

# Wait a moment for the API to be fully ready
sleep 5

# Stalwart API base URL (internal)
API="http://localhost:8080/api"
AUTH="Authorization: Basic $(echo -n "admin:$STALWART_ADMIN_PASSWORD" | base64)"

# Create the domain (idempotent)
curl -sf -X POST "$API/domain/$MAIL_DOMAIN" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  || log "Domain may already exist, continuing..."

# Extract DNS records (includes DKIM)
log "Extracting DNS records from Stalwart..."
DNS_RECORDS=$(curl -sf "$API/dns/records/$MAIL_DOMAIN" \
  -H "$AUTH" \
  -H "Accept: application/json")

echo "$DNS_RECORDS"

# Write DNS records to a file for later retrieval
echo "$DNS_RECORDS" > "$MAIL_DIR/dns-records.json"

log "Mail server setup complete!"
log "DNS records saved to $MAIL_DIR/dns-records.json"
