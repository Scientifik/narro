#!/bin/bash
# Debian/Ubuntu Server Provisioning Script for Narro
# One-time setup: Installs Docker, Nginx, and basic configuration
# Run as root on a fresh Debian 12+ or Ubuntu 22.04 installation
# Usage: sudo bash provision-debian.sh [frontend|backend]

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

# Trap errors and show helpful message
trap 'log_error "Script failed at line $LINENO. Check logs and error messages above."' ERR

# Check root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Must run as root (use sudo)"
    exit 1
fi

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log_warn "Could not reach 8.8.8.8 (Google DNS). This may cause package downloads to fail."
        log_warn "If your network has firewall restrictions, you may need to configure apt manually."
    fi
}

# Function to validate system requirements
validate_system() {
    log_info "Validating system requirements..."

    # Check if running on supported OS
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot determine OS. /etc/os-release not found."
        exit 1
    fi

    # Check available disk space (need at least 10GB)
    local available_gb=$(df /home | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$available_gb" -lt 10 ]; then
        log_warn "Low disk space: only ${available_gb}GB available. Recommend at least 10GB."
    fi

    # Check available memory (need at least 1GB)
    local available_mem=$(free -g | awk 'NR==2 {print $7}')
    if [ "$available_mem" -lt 1 ]; then
        log_warn "Low memory: only ${available_mem}GB available. Docker may perform poorly."
    fi

    log_info "System validation passed"
}

# Run validation
validate_system
check_internet

# Configuration
SERVER_TYPE="${1}"  # frontend or backend (required)

# Validate server type
if [[ ! "$SERVER_TYPE" =~ ^(frontend|backend)$ ]]; then
    log_error "Invalid or missing server type: $SERVER_TYPE"
    log_error "Usage: sudo bash provision-debian.sh [frontend|backend]"
    exit 1
fi

# Set DOMAIN defaults based on server type
if [ "$SERVER_TYPE" = "frontend" ]; then
    DOMAIN="${DOMAIN:-narro.info}"
elif [ "$SERVER_TYPE" = "backend" ]; then
    DOMAIN="${DOMAIN:-api.narro.info}"
fi

NARRO_USER="${NARRO_USER:-narro}"
NARRO_HOME="/home/${NARRO_USER}"

log_info "Provisioning Debian/Ubuntu server for Narro (Server Type: $SERVER_TYPE)..."
log_info "Domain: ${DOMAIN}"

# Update system
log_info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install essential packages
log_info "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    nginx \
    certbot \
    python3-certbot-nginx

# Install Docker
log_info "Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
    # Detect OS distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        log_error "Cannot determine OS distribution"
        exit 1
    fi

    # Log detected OS for debugging
    log_debug "Detected OS: $OS (from /etc/os-release ID field)"

    # Remove any pre-existing broken Docker repository configurations
    rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    if ! curl -fsSL https://download.docker.com/linux/${OS}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        log_error "Failed to add Docker GPG key"
        exit 1
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up Docker repository (use correct distro)
    DOCKER_ARCH=$(dpkg --print-architecture)
    DOCKER_DISTRO=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
    DOCKER_CODENAME=$(lsb_release -cs)

    log_debug "Docker distro: $DOCKER_DISTRO, codename: $DOCKER_CODENAME, arch: $DOCKER_ARCH"

    # Handle unsupported release codenames (like Debian Trixie which Docker doesn't have yet)
    # Fall back to a known stable release for the distribution
    if [ "$DOCKER_DISTRO" = "debian" ]; then
        case "$DOCKER_CODENAME" in
            trixie|testing)
                log_warn "Using bookworm (stable) for Docker packages since $DOCKER_CODENAME is not yet supported"
                DOCKER_CODENAME="bookworm"
                ;;
        esac
    elif [ "$DOCKER_DISTRO" = "ubuntu" ]; then
        case "$DOCKER_CODENAME" in
            oracular|devel)
                log_warn "Using jammy (LTS) for Docker packages since $DOCKER_CODENAME is not yet supported"
                DOCKER_CODENAME="jammy"
                ;;
        esac
    fi

    log_debug "Docker repository: https://download.docker.com/linux/${DOCKER_DISTRO}/${DOCKER_CODENAME}"
    echo "deb [arch=${DOCKER_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} ${DOCKER_CODENAME} stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    log_info "Updating package lists..."
    if ! apt-get update; then
        log_error "Failed to update package lists"
        exit 1
    fi

    log_info "Installing Docker packages..."
    if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "Failed to install Docker"
        exit 1
    fi
else
    log_info "Docker already installed"
fi

# Start and enable Docker
log_info "Starting Docker..."
systemctl start docker
systemctl enable docker

# Create user if it doesn't exist
if ! id -u "${NARRO_USER}" >/dev/null 2>&1; then
    log_info "Creating ${NARRO_USER} user..."
    useradd -m -s /bin/bash "${NARRO_USER}"
    log_warn "Set password for ${NARRO_USER}: passwd ${NARRO_USER}"
else
    log_info "User ${NARRO_USER} already exists"
fi

# Add user to docker group
log_info "Adding ${NARRO_USER} to docker group..."
usermod -aG docker "${NARRO_USER}"

# Create directory structure
log_info "Creating directory structure..."
mkdir -p "${NARRO_HOME}/deployment"
mkdir -p /var/www/certbot
chown -R "${NARRO_USER}:${NARRO_USER}" "${NARRO_HOME}"
chmod 700 "${NARRO_HOME}/deployment"

# Function to generate Nginx configuration
generate_nginx_config() {
    local config_file=$1
    local server_type=$2
    local domain=$3

    cat > "$config_file" << 'NGINX_EOF'
# Nginx configuration for Narro
# Domain: {DOMAIN}
# Server Type: {SERVER_TYPE}

{UPSTREAMS}

# HTTP server - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name {SERVER_NAMES};

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    access_log /var/log/nginx/narro-access.log;
    error_log /var/log/nginx/narro-error.log;

    client_max_body_size 10M;

    {LOCATIONS}

    location /api/health {
        proxy_pass http://api/api/health;
        access_log off;
    }
}

# HTTPS server will be added by Certbot when you run: certbot --nginx -d {DOMAIN}
NGINX_EOF

    # Read the template
    local nginx_config=$(cat "$config_file")

    # Replace placeholders
    nginx_config="${nginx_config//{DOMAIN}/$domain}"
    nginx_config="${nginx_config//{SERVER_TYPE}/$server_type}"

    # Set up server-specific configuration
    if [ "$server_type" = "frontend" ]; then
        local upstreams="upstream api {
    server api.narro.info:443;  # Backend API server
    keepalive 32;
}

upstream web {
    server localhost:3001;  # Local Next.js web application
    keepalive 32;
}"
        local server_names="$domain www.$domain"
        local locations="# API routes (proxy to backend)
    location /api/ {
        proxy_pass https://api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Web app (local)
    location / {
        proxy_pass http://web;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 60s;
    }"
    elif [ "$server_type" = "backend" ]; then
        local upstreams="upstream api {
    server localhost:3000;  # Local Go API server
    keepalive 32;
}"
        local server_names="$domain"
        local locations="# API routes
    location /api/ {
        proxy_pass http://api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }"
    else
        log_error "Unknown server type: $server_type"
        return 1
    fi

    # Replace server-specific placeholders
    nginx_config="${nginx_config//{UPSTREAMS}/$upstreams}"
    nginx_config="${nginx_config//{SERVER_NAMES}/$server_names}"
    nginx_config="${nginx_config//{LOCATIONS}/$locations}"

    # Write final config
    echo "$nginx_config" > "$config_file"
}

# Create Nginx configuration
log_info "Configuring Nginx for $SERVER_TYPE server..."
if ! generate_nginx_config "/etc/nginx/sites-available/narro" "$SERVER_TYPE" "$DOMAIN"; then
    log_error "Failed to generate Nginx configuration"
    exit 1
fi

# Enable site
ln -sf /etc/nginx/sites-available/narro /etc/nginx/sites-enabled/narro

# Remove default Nginx site if it exists
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
log_info "Testing Nginx configuration..."
if ! nginx -t 2>&1; then
    log_error "Nginx configuration test failed. Output above."
    log_error "Run 'sudo nginx -T' to see full configuration"
    exit 1
fi
log_info "Nginx configuration valid"

# Reload Nginx
if ! systemctl reload nginx; then
    log_error "Failed to reload Nginx"
    exit 1
fi

# Enable Nginx on boot
systemctl enable nginx

# Configure firewall
log_info "Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    # Allow SSH (important - don't lock yourself out!)
    ufw allow OpenSSH 2>/dev/null || ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall (if not already enabled)
    if ! ufw status | grep -q "Status: active"; then
        log_info "Enabling UFW firewall..."
        ufw --force enable
    else
        log_info "UFW firewall already enabled"
    fi
    
    log_info "Firewall configured: HTTP (80) and HTTPS (443) allowed"
elif command -v iptables >/dev/null 2>&1; then
    # Basic iptables rules (if ufw not available)
    log_info "Configuring iptables rules..."
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
    log_info "Basic iptables rules configured"
else
    log_warn "No firewall detected (ufw or iptables)"
fi

log_info "Provisioning complete!"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo ""
echo "1. Verify Docker installation:"
echo "   docker --version"
echo ""
echo "2. Switch to narro user:"
echo "   su - ${NARRO_USER}"
echo ""
echo "3. Copy docker-compose.yml to deployment directory:"
echo "   cp /path/to/narro/deployment/docker-compose.yml ${NARRO_HOME}/deployment/"
echo ""
echo "4. Copy and configure environment file:"
echo "   cp /path/to/narro/deployment/scripts/env.prod ${NARRO_HOME}/deployment/.env.production"
echo "   nano ${NARRO_HOME}/deployment/.env.production"
echo "   chmod 600 ${NARRO_HOME}/deployment/.env.production"
echo ""
echo "5. Get SSL certificate (as root):"
echo "   sudo certbot --nginx -d ${DOMAIN}"
if [ "$SERVER_TYPE" = "frontend" ]; then
    echo "   sudo certbot --nginx -d www.${DOMAIN}"
fi
echo ""
echo "6. Deploy services (as narro user):"
echo "   cd ${NARRO_HOME}/deployment"
echo "   docker compose pull"
echo "   docker compose up -d"
echo ""
echo "7. Verify deployment:"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo -e "${GREEN}✓ Server provisioning finished${NC}"
echo ""

