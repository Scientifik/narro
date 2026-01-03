#!/bin/bash

# Simple wrapper script that reads registry credentials from env files
# Usage: ./list-images.sh [env-file] [options]
# Options: -s (show sizes), -d (show digests), -h (help)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_SCRIPT="${SCRIPT_DIR}/list-registry-images.sh"

# Check if first argument is an env file (not a flag)
if [[ -n "$1" ]] && [[ "$1" != -* ]] && [[ -f "$1" ]]; then
    ENV_FILE="$1"
    shift  # Remove it from arguments so it's not passed to main script
elif [[ -f "${SCRIPT_DIR}/../.env.production" ]]; then
    ENV_FILE="${SCRIPT_DIR}/../.env.production"
elif [[ -f "${SCRIPT_DIR}/env.prod" ]]; then
    ENV_FILE="${SCRIPT_DIR}/env.prod"
elif [[ -f "${SCRIPT_DIR}/../.env.staging" ]]; then
    ENV_FILE="${SCRIPT_DIR}/../.env.staging"
elif [[ -f "${SCRIPT_DIR}/env.staging.example" ]]; then
    ENV_FILE="${SCRIPT_DIR}/env.staging.example"
else
    echo "Error: No environment file found. Please specify one:"
    echo "  $0 <path-to-env-file> [options]"
    echo ""
    echo "Or set environment variables:"
    echo "  export REGISTRY_URL=ord.vultrcr.com"
    echo "  export REGISTRY_USER=your-username"
    echo "  export REGISTRY_PASSWORD=your-password"
    exit 1
fi

# Source the env file
if [[ -f "$ENV_FILE" ]]; then
    echo "Loading credentials from: $ENV_FILE"
    # Extract registry config from env file
    export REGISTRY_URL=$(grep "^REGISTRY_URL=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
    export REGISTRY_USER=$(grep "^REGISTRY_USER=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
    export REGISTRY_PASSWORD=$(grep "^REGISTRY_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "")
    
    # Extract namespace from REGISTRY_URL if it contains a path
    if [[ "$REGISTRY_URL" == *"/"* ]]; then
        export REGISTRY_NAMESPACE=$(echo "$REGISTRY_URL" | cut -d'/' -f2-)
        export REGISTRY_URL=$(echo "$REGISTRY_URL" | cut -d'/' -f1)
    fi
else
    echo "Error: Environment file not found: $ENV_FILE"
    exit 1
fi

# Check if credentials are set
if [[ -z "$REGISTRY_URL" ]] || [[ -z "$REGISTRY_USER" ]] || [[ -z "$REGISTRY_PASSWORD" ]]; then
    echo "Error: Missing registry credentials in $ENV_FILE"
    echo "Required: REGISTRY_URL, REGISTRY_USER, REGISTRY_PASSWORD"
    exit 1
fi

# Run the main script with any additional arguments (like -s for sizes, -d for digests)
exec "$LIST_SCRIPT" "$@"

