#!/bin/bash
# Debug script for Docker containers
# Run from deployment directory

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Get deployment directory
DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DEPLOYMENT_DIR" || exit 1

log_info "Debugging Docker containers from: $(pwd)"

# Check if containers are running
log_info "\n=== Container Status ==="
docker compose ps

# Check API container logs
log_info "\n=== narro-api Logs (last 50 lines) ==="
docker compose logs --tail=50 narro-api

# Check if API is listening
log_info "\n=== Testing API Endpoints ==="
log_debug "Testing health endpoint from inside container..."
docker compose exec -T narro-api wget -q -O- http://localhost:3000/api/health || log_error "Health check failed inside container"

log_debug "Testing health endpoint from host..."
curl -v http://localhost:3000/api/health 2>&1 | head -20 || log_warn "Cannot reach API from host"

# Check what's listening on port 3000
log_info "\n=== Network Check ==="
log_debug "Checking what's listening on port 3000 inside container..."
docker compose exec -T narro-api netstat -tlnp 2>/dev/null || docker compose exec -T narro-api ss -tlnp 2>/dev/null || log_warn "Cannot check listening ports"

# Check environment variables
log_info "\n=== Environment Variables ==="
log_debug "PORT:"
docker compose exec -T narro-api sh -c 'echo $PORT' || true
log_debug "NODE_ENV:"
docker compose exec -T narro-api sh -c 'echo $NODE_ENV' || true
log_debug "DATABASE_URL (first 50 chars):"
docker compose exec -T narro-api sh -c 'echo ${DATABASE_URL:0:50}...' || true

# Check if routes are registered (if we can exec into container)
log_info "\n=== Process Check ==="
log_debug "Running processes in narro-api:"
docker compose exec -T narro-api ps aux | grep -E "main|go" || true

# Test from web container to API
log_info "\n=== Testing API from web container ==="
if docker compose ps narro-web | grep -q "Up"; then
    log_debug "Testing API connection from web container..."
    docker compose exec -T narro-web wget -q -O- http://narro-api:3000/api/health 2>&1 || log_warn "Web container cannot reach API"
else
    log_warn "narro-web container is not running"
fi

# Check Nginx configuration if accessible
log_info "\n=== Nginx Status ==="
if command -v nginx >/dev/null 2>&1; then
    log_debug "Nginx status:"
    sudo systemctl status nginx --no-pager -l | head -10 || true
    log_debug "Testing Nginx proxy to API..."
    curl -v http://localhost/api/health 2>&1 | head -20 || log_warn "Nginx cannot proxy to API"
else
    log_warn "Nginx not found on host"
fi

# Summary
log_info "\n=== Summary ==="
log_info "Run these commands manually for more details:"
log_info "  docker compose logs -f narro-api    # Follow API logs"
log_info "  docker compose exec narro-api sh    # Shell into API container"
log_info "  curl -v http://localhost:3000/api/health  # Test API directly"
log_info "  curl -v http://localhost/api/health  # Test through Nginx"

