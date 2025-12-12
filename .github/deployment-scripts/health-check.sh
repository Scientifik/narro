#!/bin/bash
# Health check script for Narro services
# Checks API and Web health endpoints

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
API_URL="${API_URL:-http://localhost:3000}"
WEB_URL="${WEB_URL:-http://localhost:3001}"
MAX_RETRIES=3
RETRY_DELAY=5

check_endpoint() {
    local url=$1
    local service_name=$2
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}✓ $service_name is healthy (HTTP $HTTP_CODE)${NC}"
            return 0
        else
            retries=$((retries + 1))
            if [ $retries -lt $MAX_RETRIES ]; then
                echo -e "${YELLOW}⚠ $service_name check failed (HTTP $HTTP_CODE), retrying in ${RETRY_DELAY}s... (attempt $retries/$MAX_RETRIES)${NC}"
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    echo -e "${RED}✗ $service_name health check failed after $MAX_RETRIES attempts (HTTP $HTTP_CODE)${NC}"
    return 1
}

echo -e "${YELLOW}Running health checks...${NC}"

# Check API health
check_endpoint "$API_URL/api/health" "API"

# Check Web health (root endpoint)
check_endpoint "$WEB_URL/" "Web"

echo -e "${GREEN}✓ All services are healthy${NC}"
exit 0









