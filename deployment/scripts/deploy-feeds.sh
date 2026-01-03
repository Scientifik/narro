#!/bin/bash

set -e

echo "🚀 Deploying Narro RSS Feeds Proxy..."

DEPLOYMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DEPLOYMENT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Create directories
echo -e "${YELLOW}📁 Creating required directories...${NC}"
mkdir -p nginx/ssl
mkdir -p nginx/certbot
mkdir -p logs/nginx
echo -e "${GREEN}✓ Directories created${NC}"

# Step 2: Check DNS
echo -e "${YELLOW}🌐 Checking DNS configuration...${NC}"
if nslookup feeds.narro.info &>/dev/null; then
    RESOLVED_IP=$(dig +short feeds.narro.info A | tail -n1)
    echo -e "${GREEN}✓ feeds.narro.info resolves to: $RESOLVED_IP${NC}"
else
    echo -e "${RED}✗ DNS not configured. Please add A record for feeds.narro.info${NC}"
    echo "  Add this A record at your domain registrar:"
    echo "  feeds.narro.info → <your-server-ip>"
    exit 1
fi

# Step 3: Check SSL certificates
echo -e "${YELLOW}🔒 Checking SSL certificates...${NC}"
if [ -d "nginx/ssl/feeds.narro.info" ] && [ -f "nginx/ssl/feeds.narro.info/cert.pem" ]; then
    echo -e "${GREEN}✓ SSL certificates found${NC}"
else
    echo -e "${YELLOW}⚠️  SSL certificates not found. Running certbot...${NC}"

    # Try to get certificates using standalone mode
    sudo certbot certonly \
        --standalone \
        -d feeds.narro.info \
        --email admin@narro.info \
        --agree-tos \
        --non-interactive || {
        echo -e "${RED}✗ Failed to obtain certificates${NC}"
        echo "  Make sure ports 80 and 443 are open and no other service is using them"
        exit 1
    }

    # Copy certificates
    echo -e "${YELLOW}📋 Copying certificates...${NC}"
    sudo mkdir -p nginx/ssl/feeds.narro.info
    sudo cp /etc/letsencrypt/live/feeds.narro.info/cert.pem nginx/ssl/feeds.narro.info/
    sudo cp /etc/letsencrypt/live/feeds.narro.info/key.pem nginx/ssl/feeds.narro.info/
    sudo chown -R $(whoami) nginx/ssl/
    echo -e "${GREEN}✓ Certificates copied${NC}"
fi

# Step 4: Start Docker services
echo -e "${YELLOW}🐳 Starting Docker services...${NC}"
docker-compose -f docker-compose.feeds.yml up -d

# Step 5: Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 5

# Step 6: Health check
echo -e "${YELLOW}🏥 Running health checks...${NC}"
if curl -s -f http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ nginx health check passed${NC}"
else
    echo -e "${RED}✗ nginx health check failed${NC}"
    docker-compose -f docker-compose.feeds.yml logs nginx-feeds
    exit 1
fi

# Step 7: Display summary
echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}📍 RSS Feeds Service Information:${NC}"
echo "   URL: https://feeds.narro.info/{feedId}.rss"
echo "   Example: https://feeds.narro.info/550e8400-e29b-41d4-a716-446655440000.rss"
echo ""
echo -e "${YELLOW}🔍 Testing:${NC}"
echo "   curl -v https://feeds.narro.info/{feedId}.rss"
echo ""
echo -e "${YELLOW}📊 Monitoring:${NC}"
echo "   docker-compose -f docker-compose.feeds.yml logs -f nginx-feeds"
echo ""
echo -e "${YELLOW}🛑 Stopping:${NC}"
echo "   docker-compose -f docker-compose.feeds.yml down"
echo ""
