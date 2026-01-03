#!/bin/bash

# Script to list all container images in a Docker registry
# Supports Docker Registry API v2 (compatible with Vultr Container Registry)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values (can be overridden by env vars or arguments)
REGISTRY_URL="${REGISTRY_URL:-ord.vultrcr.com}"
REGISTRY_USER="${REGISTRY_USER:-}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-narro}"

# Parse command line arguments
SHOW_SIZES=false
SHOW_DIGESTS=false

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

List all container images in a Docker registry.

Options:
    -r, --registry URL        Registry URL (default: ord.vultrcr.com)
    -n, --namespace NAME      Registry namespace/repository prefix (default: narro)
    -u, --user USERNAME       Registry username
    -p, --password PASSWORD   Registry password
    -s, --sizes               Show image sizes (slower)
    -d, --digests             Show image digests
    -h, --help                Show this help message

Environment Variables:
    REGISTRY_URL              Registry URL
    REGISTRY_USER             Registry username
    REGISTRY_PASSWORD         Registry password
    REGISTRY_NAMESPACE        Registry namespace

Examples:
    # Use environment variables
    export REGISTRY_URL=ord.vultrcr.com
    export REGISTRY_USER=myuser
    export REGISTRY_PASSWORD=mypass
    $0

    # Use command line arguments
    $0 -r ord.vultrcr.com -n narro -u myuser -p mypass

    # Show sizes and digests
    $0 -s -d

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY_URL="$2"
            shift 2
            ;;
        -n|--namespace)
            REGISTRY_NAMESPACE="$2"
            shift 2
            ;;
        -u|--user)
            REGISTRY_USER="$2"
            shift 2
            ;;
        -p|--password)
            REGISTRY_PASSWORD="$2"
            shift 2
            ;;
        -s|--sizes)
            SHOW_SIZES=true
            shift
            ;;
        -d|--digests)
            SHOW_DIGESTS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$REGISTRY_URL" ]]; then
    echo -e "${RED}Error: Registry URL is required${NC}"
    usage
fi

if [[ -z "$REGISTRY_USER" ]] || [[ -z "$REGISTRY_PASSWORD" ]]; then
    echo -e "${YELLOW}Warning: Registry credentials not provided. Some registries may allow anonymous access.${NC}"
    echo -e "${YELLOW}Set REGISTRY_USER and REGISTRY_PASSWORD environment variables or use -u/-p flags.${NC}"
fi

# Remove https:// or http:// prefix if present
REGISTRY_HOST="${REGISTRY_URL#https://}"
REGISTRY_HOST="${REGISTRY_HOST#http://}"

# Extract namespace from REGISTRY_URL if it contains a path (e.g., ord.vultrcr.com/narro)
if [[ "$REGISTRY_HOST" == *"/"* ]]; then
    if [[ -z "$REGISTRY_NAMESPACE" ]] || [[ "$REGISTRY_NAMESPACE" == "narro" ]]; then
        REGISTRY_NAMESPACE=$(echo "$REGISTRY_HOST" | cut -d'/' -f2-)
    fi
    REGISTRY_HOST=$(echo "$REGISTRY_HOST" | cut -d'/' -f1)
fi

# Base URL for registry API
if [[ "$REGISTRY_URL" == https://* ]]; then
    BASE_URL="https://${REGISTRY_HOST}/v2"
else
    BASE_URL="http://${REGISTRY_HOST}/v2"
fi

# Function to get authentication token
get_auth_token() {
    if [[ -z "$REGISTRY_USER" ]] || [[ -z "$REGISTRY_PASSWORD" ]]; then
        echo ""
        return
    fi
    
    local auth_url="https://${REGISTRY_HOST}"
    if [[ "$REGISTRY_URL" != https://* ]]; then
        auth_url="http://${REGISTRY_HOST}"
    fi
    
    # Try to get token from auth service
    local response=$(curl -s -u "${REGISTRY_USER}:${REGISTRY_PASSWORD}" \
        "${auth_url}/v2/token?service=${REGISTRY_HOST}&scope=registry:catalog:*" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]] && echo "$response" | grep -q "token"; then
        echo "$response" | grep -o '"token":"[^"]*' | cut -d'"' -f4
    else
        # Fallback: use basic auth
        echo -n "${REGISTRY_USER}:${REGISTRY_PASSWORD}" | base64
    fi
}

# Function to make authenticated API call
api_call() {
    local endpoint="$1"
    local url="${BASE_URL}${endpoint}"
    local token=$(get_auth_token)
    
    if [[ -n "$token" ]] && [[ "$token" != *":"* ]]; then
        # Token-based auth
        curl -s -H "Authorization: Bearer ${token}" "$url"
    elif [[ -n "$REGISTRY_USER" ]] && [[ -n "$REGISTRY_PASSWORD" ]]; then
        # Basic auth
        curl -s -u "${REGISTRY_USER}:${REGISTRY_PASSWORD}" "$url"
    else
        # No auth
        curl -s "$url"
    fi
}

# Function to format bytes
format_bytes() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

# Function to get image size
get_image_size() {
    local repo="$1"
    local tag="$2"
    local manifest=$(api_call "/${repo}/manifests/${tag}")
    
    if echo "$manifest" | grep -q "schemaVersion"; then
        # For v2 manifests, calculate size from layers
        local size=$(echo "$manifest" | grep -o '"size":[0-9]*' | grep -o '[0-9]*' | awk '{sum+=$1} END {print sum}')
        if [[ -n "$size" ]] && [[ "$size" != "0" ]]; then
            echo "$size"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Main execution
echo -e "${BLUE}=== Container Registry Image List ===${NC}"
echo -e "${BLUE}Registry: ${REGISTRY_HOST}${NC}"
echo -e "${BLUE}Namespace: ${REGISTRY_NAMESPACE}${NC}"
echo ""

# Get catalog of repositories
echo -e "${YELLOW}Fetching repository list...${NC}"
catalog=$(api_call "/_catalog?n=1000")

if echo "$catalog" | grep -q "repositories"; then
    all_repos=$(echo "$catalog" | grep -o '"[^"]*"' | tr -d '"')
    
    # Filter by namespace if specified
    if [[ -n "$REGISTRY_NAMESPACE" ]] && [[ "$REGISTRY_NAMESPACE" != "all" ]]; then
        repos=$(echo "$all_repos" | grep "^${REGISTRY_NAMESPACE}/" || true)
        if [[ -z "$repos" ]]; then
            echo -e "${RED}No repositories found in namespace '${REGISTRY_NAMESPACE}'${NC}"
            echo -e "${YELLOW}Available repositories:${NC}"
            echo "$all_repos" | sed 's/^/  - /'
            exit 0
        fi
    else
        repos="$all_repos"
    fi
    
    total_images=0
    total_size=0
    
    # Process each repository
    while IFS= read -r repo; do
        if [[ -z "$repo" ]]; then
            continue
        fi
        
        echo ""
        echo -e "${GREEN}📦 Repository: ${repo}${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Get tags for this repository
        tags_response=$(api_call "/${repo}/tags/list")
        
        if echo "$tags_response" | grep -q "tags"; then
            tags=$(echo "$tags_response" | grep -o '"[^"]*"' | tr -d '"' | grep -v "tags" | sort)
            
            if [[ -z "$tags" ]]; then
                echo -e "  ${YELLOW}No tags found${NC}"
                continue
            fi
            
            tag_count=0
            while IFS= read -r tag; do
                if [[ -z "$tag" ]]; then
                    continue
                fi
                
                tag_count=$((tag_count + 1))
                total_images=$((total_images + 1))
                
                output="  ${BLUE}•${NC} ${tag}"
                
                if [[ "$SHOW_DIGESTS" == true ]]; then
                    manifest=$(api_call "/${repo}/manifests/${tag}")
                    digest=$(echo "$manifest" | grep -o '"digest":"[^"]*' | head -1 | cut -d'"' -f4)
                    if [[ -n "$digest" ]]; then
                        output="${output} ${YELLOW}(digest: ${digest:0:20}...)${NC}"
                    fi
                fi
                
                if [[ "$SHOW_SIZES" == true ]]; then
                    size=$(get_image_size "$repo" "$tag")
                    if [[ "$size" != "0" ]] && [[ -n "$size" ]]; then
                        formatted_size=$(format_bytes "$size")
                        output="${output} ${GREEN}[${formatted_size}]${NC}"
                        total_size=$((total_size + size))
                    fi
                fi
                
                echo -e "$output"
            done <<< "$tags"
            
            echo -e "  ${BLUE}Total tags: ${tag_count}${NC}"
        else
            echo -e "  ${RED}Error fetching tags: ${tags_response}${NC}"
        fi
    done <<< "$repos"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Summary:${NC}"
    echo -e "  Total images: ${total_images}"
    if [[ "$SHOW_SIZES" == true ]] && [[ $total_size -gt 0 ]]; then
        echo -e "  Total size: $(format_bytes $total_size)"
    fi
else
    echo -e "${RED}Error: Failed to fetch catalog${NC}"
    echo "Response: $catalog"
    exit 1
fi

