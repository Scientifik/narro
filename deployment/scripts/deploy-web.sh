#!/bin/bash
# Frontend Web Deployment Script
# Deploys narro-web container to frontend server
# Assumes: deploy-web.sh, docker-compose.web.yml, and .env.production are all in the same directory
# Run from /home/narro/deployment as narro user
# Usage: ./deploy-web.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get directory where this script is located
DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DEPLOYMENT_DIR" || {
    log_error "Failed to change to deployment directory: $DEPLOYMENT_DIR"
    exit 1
}

COMPOSE_FILE="docker-compose.web.yml"
SERVICE="narro-web"

# Verify docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Docker Compose file not found: $COMPOSE_FILE"
    exit 1
fi

log_info "Starting frontend web deployment from: $(pwd)"
log_info "Using compose file: $COMPOSE_FILE"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    log_error "Please ensure Docker is started: sudo systemctl start docker"
    exit 1
fi

# Check for .env.production
if [ ! -f ".env.production" ]; then
    log_error ".env.production not found in $(pwd)"
    log_error "Create .env.production with your secrets (see env.frontend.example)"
    exit 1
fi

# Check file permissions
PERMS=$(stat -c "%a" .env.production 2>/dev/null || stat -f "%OLp" .env.production 2>/dev/null)
if [ "$PERMS" != "600" ]; then
    log_warn "Setting .env.production permissions to 600"
    chmod 600 .env.production
fi

# Load environment variables
set -a
source .env.production
set +a

# Export for docker-compose
export REGISTRY_URL
export IMAGE_TAG

if [ -z "$REGISTRY_URL" ]; then
    log_error "REGISTRY_URL not set in .env.production"
    exit 1
fi

log_info "Registry: ${REGISTRY_URL}"
log_info "Image tag: ${IMAGE_TAG:-latest}"

# Login to registry if credentials provided
if [ -n "$REGISTRY_USER" ] && [ -n "$REGISTRY_PASSWORD" ]; then
    log_info "Logging in to registry..."
    echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_URL" -u "$REGISTRY_USER" --password-stdin
fi

# Pull latest web image
log_info "Pulling narro-web image from registry..."
docker compose -f "$COMPOSE_FILE" pull $SERVICE

# Start web service with zero-downtime
log_info "Starting narro-web container..."
docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-deps $SERVICE

# Wait for container to initialize
log_info "Waiting for narro-web to initialize..."
sleep 5

# Check container logs
log_info "Checking narro-web logs..."
docker compose -f "$COMPOSE_FILE" logs --tail=50 $SERVICE || true

# Check service status
log_info "Service status:"
docker compose -f "$COMPOSE_FILE" ps

# Check health status
if docker compose -f "$COMPOSE_FILE" ps $SERVICE | grep -q "unhealthy\|starting\|waiting"; then
    log_warn "narro-web container is not healthy yet. Checking logs..."
    docker compose -f "$COMPOSE_FILE" logs --tail=100 $SERVICE
    log_warn "Container may still be initializing. Check the logs above for errors."
fi

log_info "Frontend web deployment complete!"
log_info "Web service should be available at your configured domain (e.g., https://narro.info)"
