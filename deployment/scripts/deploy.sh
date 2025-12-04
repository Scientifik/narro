#!/bin/bash
# Deployment script - pulls images from registry and starts containers
# Assumes: deploy.sh, docker-compose.yml, and .env.production are all in the same directory
# Run from that directory as narro user

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get directory where this script is located (assume all files are here)
DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DEPLOYMENT_DIR" || {
    log_error "Failed to change to deployment directory: $DEPLOYMENT_DIR"
    exit 1
}

log_info "Starting deployment from: $(pwd)"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running or not accessible"
    log_error "Please ensure Docker is started: sudo systemctl start docker"
    log_error "And that your user is in the docker group (log out and back in after being added)"
    exit 1
fi

# Check for .env.production
if [ ! -f ".env.production" ]; then
    log_error ".env.production not found in $(pwd)"
    log_error "Create .env.production with your secrets (see env.prod example if available)"
    exit 1
fi

# Check file permissions
PERMS=$(stat -c "%a" .env.production 2>/dev/null || stat -f "%OLp" .env.production 2>/dev/null)
if [ "$PERMS" != "600" ]; then
    log_warn "Setting .env.production permissions to 600"
    chmod 600 .env.production
fi

# Check for docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found in $(pwd)"
    exit 1
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

# Pull latest images
log_info "Pulling images from registry..."
docker compose pull narro-api narro-web narro-scraper

# Start services with zero-downtime
log_info "Starting services..."
docker compose up -d --force-recreate --no-deps narro-api narro-web

# Wait a moment for containers to start
log_info "Waiting for containers to initialize..."
sleep 5

# Check container logs for errors
log_info "Checking narro-api logs..."
docker compose logs --tail=50 narro-api || true

# Check service status
log_info "Service status:"
docker compose ps

# If narro-api is still waiting, show more details
if docker compose ps narro-api | grep -q "unhealthy\|starting\|waiting"; then
    log_warn "narro-api container is not healthy. Checking logs..."
    docker compose logs --tail=100 narro-api
    log_warn "Check the logs above for errors (database connection, missing env vars, etc.)"
fi

# Run health checks if health-check script exists
if [ -f "health-check.sh" ]; then
    log_info "Running health checks..."
    bash health-check.sh || log_warn "Health checks failed, but deployment completed"
fi

log_info "Deployment complete!"
log_info "Services should be available at your configured domain"
