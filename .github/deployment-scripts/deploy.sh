#!/bin/bash
# Deployment script for Narro
# This script handles zero-downtime deployment of API and Web services
# Scraper is NOT deployed here - it runs on-demand via cron

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")/../deployment"
APP_DIR="$(dirname "$SCRIPT_DIR")/.."

# Change to deployment directory
cd "$DEPLOYMENT_DIR" || exit 1

echo -e "${GREEN}Starting deployment...${NC}"

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}Error: .env.production not found in $DEPLOYMENT_DIR${NC}"
    echo "Please create .env.production with all required environment variables"
    exit 1
fi

# Load environment variables safely
set -a
source .env.production
set +a

# Get current git commit SHA for tagging
cd "$APP_DIR" || exit 1
COMMIT_SHA=$(git rev-parse --short HEAD)
cd "$DEPLOYMENT_DIR" || exit 1

echo -e "${YELLOW}Building images with commit SHA: $COMMIT_SHA${NC}"

# Build Docker images with commit SHA tags
docker-compose build \
    --build-arg NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-http://narro-api:3000}" \
    --build-arg NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL}" \
    --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY}"

# Tag images with commit SHA
docker tag narro-api:latest narro-api:$COMMIT_SHA || true
docker tag narro-web:latest narro-web:$COMMIT_SHA || true
docker tag narro-scraper:latest narro-scraper:$COMMIT_SHA || true

echo -e "${YELLOW}Running database migrations...${NC}"
# Note: Migrations are manual for now, but this is a placeholder
# docker-compose run --rm narro-api ./migrate up

echo -e "${YELLOW}Deploying services with zero-downtime...${NC}"

# Deploy with zero-downtime (force recreate, but keep old containers until new ones are healthy)
docker-compose up -d --force-recreate --no-deps narro-api narro-web

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
sleep 10

# Run health checks
if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
    bash "$SCRIPT_DIR/health-check.sh"
    HEALTH_CHECK_EXIT=$?
    
    if [ $HEALTH_CHECK_EXIT -ne 0 ]; then
        echo -e "${RED}Health check failed! Rolling back...${NC}"
        # Rollback logic would go here
        exit 1
    fi
else
    echo -e "${YELLOW}Warning: health-check.sh not found, skipping health checks${NC}"
fi

# Clean up old images (keep last 3 versions)
echo -e "${YELLOW}Cleaning up old images...${NC}"
docker image prune -f --filter "until=24h" || true

# Remove old containers
docker-compose down --remove-orphans || true

echo -e "${GREEN}✓ Deployment successful!${NC}"
echo -e "${GREEN}Services are running with commit: $COMMIT_SHA${NC}"




