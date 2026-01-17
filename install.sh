#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

trap 'error "Script failed at line $LINENO"; docker compose logs --tail=50; exit 1' ERR

log "🚀 Starting Pterodactyl Zero-Touch Deployment for Codespaces..."

# --- 1. Pre-flight Checks ---
log "Checking prerequisites..."
if ! command -v docker >/dev/null; then error "Docker is not installed."; exit 1; fi
if ! docker compose version >/dev/null 2>&1; then error "Docker Compose is not installed."; exit 1; fi
if ! command -v node >/dev/null; then error "Node.js is not installed."; exit 1; fi

# --- 2. Environment Setup ---
log "Configuring environment..."
if [ ! -f .env ]; then
    cp .env.example .env
    log "Created .env from example."
fi

# Load environment variables and export them for sub-processes
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Auto-detect Codespace URL
if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    CODESPACE_URL="https://${CODESPACE_NAME}-80.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    log "Detected Codespace URL: ${CODESPACE_URL}"
    
    # Update .env using a different separator for sed to avoid issues with / in URL
    sed -i "s|APP_URL=.*|APP_URL=${CODESPACE_URL}|g" .env
    sed -i "s|CODESPACE_NAME=.*|CODESPACE_NAME=${CODESPACE_NAME}|g" .env
    sed -i "s|GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=.*|GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}|g" .env
else
    # Fallback for local or if variables are missing
    CODESPACE_URL=$(grep APP_URL .env | cut -d '=' -f2)
    warn "Not running in Codespaces or variables missing. Using existing APP_URL: ${CODESPACE_URL}"
fi

# Create directories
mkdir -p lib/wings logs scripts misc
chmod -R 777 lib logs # Ensure write permissions

# --- 3. Start Core Services ---
log "Starting MariaDB and Redis..."
docker compose up -d mariadb cache

log "Waiting for database to be ready..."
RETRIES=30
until docker compose exec -T mariadb mysqladmin ping -h localhost -u root -p"${DB_PASSWORD}" --silent || [ $RETRIES -eq 0 ]; do
    sleep 2
    RETRIES=$((RETRIES-1))
done

if [ $RETRIES -eq 0 ]; then
    error "Database failed to become ready in time."
    exit 1
fi
log "✅ Database is ready."

# --- 4. Initialize Panel ---
log "Generating application key..."
APP_KEY="base64:$(openssl rand -base64 32)"
sed -i "s|APP_KEY=.*|APP_KEY=${APP_KEY}|g" .env

log "Starting Pterodactyl Panel..."
docker compose up -d panel

log "Waiting for panel to be ready..."
sleep 10

log "Installing mysql client (required for migrations)..."
docker compose exec -T panel apk add --no-cache mariadb-client
# Disable SSL for client to avoid error 2026
docker compose exec -T panel mkdir -p /etc/my.cnf.d
docker compose exec -T panel sh -c 'echo "[client]" > /etc/my.cnf.d/00-no-ssl.cnf && echo "ssl=0" >> /etc/my.cnf.d/00-no-ssl.cnf'

log "Running database migrations..."
docker compose exec -T panel php artisan migrate --seed --force

log "Setting up panel cache..."
docker compose exec -T panel php artisan config:cache
docker compose exec -T panel php artisan route:cache
docker compose exec -T panel php artisan view:cache

# --- 5. Auto-Seed Database ---
log "Creating admin user, location, node, and allocations..."
docker compose exec -T panel php /scripts/auto-seeder.php

# --- 6. Generate & Deploy Wings Config ---
log "Generating Wings configuration..."
docker compose exec -T panel php /scripts/get-token.php > ./lib/wings/config.yml

if [ ! -s ./lib/wings/config.yml ]; then
    error "Failed to generate Wings config!"
    exit 1
fi
log "✅ Wings config.yml created successfully."

# --- 7. Start Wings Daemon ---
log "Starting Pterodactyl Wings..."
docker compose up -d wings

log "Waiting for Wings to connect..."
sleep 15
if docker compose ps wings | grep -q "Up"; then
    log "✅ Wings is running."
else
    error "Wings failed to start!"
    exit 1
fi

# --- 8. Start Keep-Alive Service ---
log "Starting Keep-Alive Service..."
cd misc
if [ ! -d "node_modules" ]; then
    npm install --production
fi

# Kill existing process if any
if [ -f ../logs/keep-alive.pid ]; then
    kill $(cat ../logs/keep-alive.pid) 2>/dev/null || true
fi

nohup node keep-alive.js > ../logs/keep-alive.log 2>&1 &
echo $! > ../logs/keep-alive.pid
cd ..

sleep 2
if pgrep -f "node keep-alive.js" > /dev/null; then
    log "✅ Keep-Alive service running."
else
    warn "Keep-Alive service failed to start. Check logs/keep-alive.log."
fi

# --- 9. Health Check ---
log "Running health checks..."
./scripts/health-check.sh || warn "Some health checks failed."

# --- 10. Final Output ---
APP_URL=$(grep APP_URL .env | cut -d '=' -f2)
ADMIN_EMAIL=$(grep ADMIN_EMAIL .env | cut -d '=' -f2)
ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d '=' -f2)

log ""
log "╔════════════════════════════════════════════════════════════╗"
log "║     🎉 PTERODACTYL DEPLOYMENT SUCCESSFUL! 🎉              ║"
log "╠════════════════════════════════════════════════════════════╣"
log "║ Panel URL:    ${APP_URL}                                   ║"
log "║ Admin Email:  ${ADMIN_EMAIL}                               ║"
log "║ Admin Pass:   ${ADMIN_PASSWORD}                            ║"
log "║                                                            ║"
log "║ Wings Status: $(docker compose ps wings | grep -q 'Up' && echo '✅ Connected' || echo '❌ Check logs') ║"
log "╚════════════════════════════════════════════════════════════╝"
log ""
