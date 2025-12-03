#!/bin/bash
# Cron script to run the scraper service on-demand
# This script is executed by system cron to trigger scraping jobs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")/../deployment"

# Change to deployment directory
cd "$DEPLOYMENT_DIR" || exit 1

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}Error: .env.production not found in $DEPLOYMENT_DIR${NC}"
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Log file with timestamp
LOG_FILE="logs/scraper-$(date +%Y%m%d-%H%M%S).log"

echo -e "${YELLOW}Starting scraper run at $(date)${NC}" | tee -a "$LOG_FILE"

# Run scraper container
# Note: This uses docker-compose run which creates a temporary container
# The container is removed after execution (--rm flag)
if docker-compose -f docker-compose.scraper.yml run --rm narro-scraper python3 run.py 2>&1 | tee -a "$LOG_FILE"; then
    echo -e "${GREEN}Scraper run completed successfully at $(date)${NC}" | tee -a "$LOG_FILE"
    exit 0
else
    EXIT_CODE=$?
    echo -e "${RED}Scraper run failed with exit code $EXIT_CODE at $(date)${NC}" | tee -a "$LOG_FILE"
    
    # Optional: Send alert/notification here
    # Example: curl -X POST https://hooks.slack.com/... -d "Scraper failed"
    
    exit $EXIT_CODE
fi




