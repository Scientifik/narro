#!/bin/bash
# Debian/Ubuntu Server Provisioning Script for Narro
# One-time setup: Installs Docker, Nginx, and basic configuration
# Run as root on a fresh Debian 12+ or Ubuntu 22.04 installation
# Usage: sudo DOMAIN=your-domain.com bash provision-debian.sh [frontend|backend|scraper]
#        sudo DOMAIN=frontend.example.com API_DOMAIN=api.example.com bash provision-debian.sh staging
#
# Note: SSH keys from /root/.ssh/authorized_keys are automatically copied to the narro user for CI/CD

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
SERVER_TYPE="${1}"  # frontend, backend, scraper, or staging (required)

# Validate server type
if [[ ! "$SERVER_TYPE" =~ ^(frontend|backend|scraper|staging)$ ]]; then
    log_error "Invalid or missing server type: $SERVER_TYPE"
    log_error "Usage: sudo DOMAIN=your-domain.com bash provision-debian.sh [frontend|backend|scraper]"
    log_error "       sudo DOMAIN=frontend.example.com API_DOMAIN=api.example.com bash provision-debian.sh staging"
    exit 1
fi

# Validate that DOMAIN is explicitly set and not empty (required for all server types)
if [ -z "$DOMAIN" ]; then
    log_error "DOMAIN environment variable is REQUIRED and must be explicitly specified"
    log_error "Please specify DOMAIN when running the script:"
    log_error "  sudo DOMAIN=your-domain.com bash provision-debian.sh $SERVER_TYPE"
    exit 1
fi

# Validate DOMAIN format (basic check - should contain a dot)
if ! echo "$DOMAIN" | grep -q '\.'; then
    log_error "Invalid DOMAIN format: '$DOMAIN'"
    log_error "Domain should be a valid hostname (e.g., example.com or api.example.com)"
    exit 1
fi

# For staging, API_DOMAIN is REQUIRED and must be different from DOMAIN
if [ "$SERVER_TYPE" = "staging" ]; then
    # Validate that API_DOMAIN is explicitly set and not empty
    if [ -z "$API_DOMAIN" ]; then
        log_error "API_DOMAIN environment variable is REQUIRED for staging and must be explicitly specified"
        log_error "Please specify API_DOMAIN when running the script:"
        log_error "  sudo DOMAIN=frontend.example.com API_DOMAIN=api.example.com bash provision-debian.sh staging"
        exit 1
    fi
    
    # Validate API_DOMAIN format
    if ! echo "$API_DOMAIN" | grep -q '\.'; then
        log_error "Invalid API_DOMAIN format: '$API_DOMAIN'"
        log_error "API domain should be a valid hostname (e.g., api.example.com)"
        exit 1
    fi
    
    # Validate that API_DOMAIN and DOMAIN are different
    if [ "$DOMAIN" = "$API_DOMAIN" ]; then
        log_error "API_DOMAIN and DOMAIN cannot be the same for staging"
        log_error "  DOMAIN: $DOMAIN"
        log_error "  API_DOMAIN: $API_DOMAIN"
        log_error "Please specify different domains:"
        log_error "  sudo DOMAIN=frontend.example.com API_DOMAIN=api.example.com bash provision-debian.sh staging"
        exit 1
    fi
fi

NARRO_USER="${NARRO_USER:-narro}"
NARRO_HOME="/home/${NARRO_USER}"

log_info "Provisioning Debian/Ubuntu server for Narro (Server Type: $SERVER_TYPE)..."
log_info "Domain: ${DOMAIN}"
if [ "$SERVER_TYPE" = "staging" ]; then
    log_info "API Domain: ${API_DOMAIN}"
fi

# Remove any pre-existing broken Docker repository configurations from failed runs
log_info "Cleaning up pre-existing repository configurations..."
rm -f /etc/apt/sources.list.d/docker.list* 2>/dev/null || true

# Update system
log_info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Set timezone
log_info "Setting timezone to America/Denver..."
timedatectl set-timezone America/Denver || {
    log_warn "timedatectl not available, using traditional method..."
    rm -f /etc/localtime
    ln -s /usr/share/zoneinfo/America/Denver /etc/localtime
    echo "America/Denver" > /etc/timezone
}
log_info "Timezone set to $(timedatectl | grep 'Time zone' || date +%Z)"

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

    # Fallback detection: If /etc/os-release says ubuntu but /etc/debian_version exists, it's Debian
    if [ "$OS" = "ubuntu" ] && [ -f /etc/debian_version ]; then
        log_warn "Detected /etc/debian_version but /etc/os-release says ubuntu. Using debian for Docker repo."
        OS="debian"
    fi

    # Log detected OS for debugging
    log_debug "Detected OS: $OS (from /etc/os-release ID field, with fallback checks)"

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

# Setup SSH keys for narro user (for CI/CD deployment)
log_info "Setting up SSH keys for ${NARRO_USER}..."
mkdir -p "${NARRO_HOME}/.ssh"
chmod 700 "${NARRO_HOME}/.ssh"

# Copy authorized_keys from root if it exists (includes deploy keys added during server setup)
if [ -f /root/.ssh/authorized_keys ]; then
    log_info "Copying authorized_keys from root to ${NARRO_USER}..."
    cp /root/.ssh/authorized_keys "${NARRO_HOME}/.ssh/authorized_keys"
    chmod 600 "${NARRO_HOME}/.ssh/authorized_keys"
    chown -R "${NARRO_USER}:${NARRO_USER}" "${NARRO_HOME}/.ssh"
    log_info "SSH keys copied successfully"
else
    log_warn "No /root/.ssh/authorized_keys found - you may need to manually add deploy keys"
    log_warn "Add your CI/CD public key to ${NARRO_HOME}/.ssh/authorized_keys"
fi

# Also allow adding keys via environment variable (optional)
if [ -n "$DEPLOY_SSH_PUBKEY" ]; then
    log_info "Adding DEPLOY_SSH_PUBKEY to ${NARRO_USER} authorized_keys..."
    echo "$DEPLOY_SSH_PUBKEY" >> "${NARRO_HOME}/.ssh/authorized_keys"
    chmod 600 "${NARRO_HOME}/.ssh/authorized_keys"
    chown -R "${NARRO_USER}:${NARRO_USER}" "${NARRO_HOME}/.ssh"
fi

# Create directory structure
log_info "Creating directory structure..."
mkdir -p "${NARRO_HOME}/deployment/scripts"
mkdir -p /var/www/certbot
chown -R "${NARRO_USER}:${NARRO_USER}" "${NARRO_HOME}"
chmod 700 "${NARRO_HOME}/deployment"

# Function to generate Nginx configuration
generate_nginx_config() {
    local config_file=$1
    local server_type=$2
    local domain=$3
    local api_domain=${4:-$domain}  # Optional API domain, defaults to same as domain

    if [ "$server_type" = "frontend" ]; then
        cat > "$config_file" << NGINX_EOF
# Nginx configuration for Narro Frontend
# Domain: $domain
# Server Type: frontend

upstream api {
    server api.narro.info:443;  # Backend API server
    keepalive 32;
}

upstream web {
    server localhost:3001;  # Local Next.js web application
    keepalive 32;
}

# HTTP server - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    access_log /var/log/nginx/narro-access.log;
    error_log /var/log/nginx/narro-error.log;

    client_max_body_size 10M;

    # API routes (proxy to backend)
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
    }

    location /api/health {
        proxy_pass http://api/api/health;
        access_log off;
    }
}

# HTTPS server will be added by Certbot when you run: certbot --nginx -d $domain
NGINX_EOF

    elif [ "$server_type" = "backend" ]; then
        cat > "$config_file" << NGINX_EOF
# Nginx configuration for Narro API Backend
# Domain: $domain
# Server Type: backend

upstream api {
    server localhost:3000;  # Local Go API server
    keepalive 32;
}

# HTTP server - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    access_log /var/log/nginx/narro-access.log;
    error_log /var/log/nginx/narro-error.log;

    client_max_body_size 10M;

    # API routes
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
    }

    location /api/health {
        proxy_pass http://api/api/health;
        access_log off;
    }
}

# HTTPS server will be added by Certbot when you run: certbot --nginx -d $domain
NGINX_EOF

    elif [ "$server_type" = "scraper" ]; then
        cat > "$config_file" << NGINX_EOF
# Nginx configuration for Narro Scraper API
# Domain: $domain
# Server Type: scraper

upstream scraper {
    server localhost:8000;  # Local scraper API server
    keepalive 32;
}

# HTTP server - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    access_log /var/log/nginx/narro-access.log;
    error_log /var/log/nginx/narro-error.log;

    client_max_body_size 10M;

    # Scraper API routes
    location / {
        proxy_pass http://scraper;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /health {
        proxy_pass http://scraper/health;
        access_log off;
    }
}

# HTTPS server will be added by Certbot when you run: certbot --nginx -d $domain
NGINX_EOF

    elif [ "$server_type" = "staging" ]; then
        # Generate staging nginx config - supports separate frontend and API domains
        {
            cat << NGINX_EOF
# Nginx configuration for Narro Staging (Single Server - Web + API)
# Frontend Domain: $domain
# API Domain: $api_domain
# Server Type: staging
# This configuration serves both web app and API on a single server
# Can use same domain for both, or separate domains

upstream api {
    server localhost:3000;  # Local Go API server
    keepalive 32;
}

upstream web {
    server localhost:3001;  # Local Next.js web application
    keepalive 32;
}

# HTTP server for frontend domain - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    access_log /var/log/nginx/narro-access.log;
    error_log /var/log/nginx/narro-error.log;

    client_max_body_size 10M;

NGINX_EOF
            # If same domain, add API routes to frontend server
            if [ "$domain" = "$api_domain" ]; then
                cat << SAME_DOMAIN_EOF
    # API routes (proxy to local backend) - same domain as frontend
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
    }

    location /api/health {
        proxy_pass http://api/api/health;
        access_log off;
    }

SAME_DOMAIN_EOF
            fi
            # Web app (always on frontend domain)
            cat << WEB_EOF
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
    }
}

WEB_EOF
            # If different domains, add separate API server block
            if [ "$domain" != "$api_domain" ]; then
                cat << API_SERVER_EOF
# HTTP server for API domain (separate from frontend domain)
server {
    listen 80;
    listen [::]:80;
    server_name $api_domain;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    access_log /var/log/nginx/narro-api-access.log;
    error_log /var/log/nginx/narro-api-error.log;

    client_max_body_size 10M;

    # API routes (proxy to local backend)
    location / {
        proxy_pass http://api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api/health {
        proxy_pass http://api/api/health;
        access_log off;
    }
}

API_SERVER_EOF
            fi
            cat << NGINX_EOF
# HTTPS servers will be added by Certbot when you run:
#   sudo certbot --nginx -d $domain
NGINX_EOF
            if [ "$domain" != "$api_domain" ]; then
                echo "#   sudo certbot --nginx -d $api_domain"
            fi
        } > "$config_file"

    else
        log_error "Unknown server type: $server_type"
        return 1
    fi
}

# Create Nginx configuration
log_info "Configuring Nginx for $SERVER_TYPE server..."
if [ "$SERVER_TYPE" = "staging" ]; then
    # For staging, pass both frontend and API domains
    if ! generate_nginx_config "/etc/nginx/sites-available/narro" "$SERVER_TYPE" "$DOMAIN" "$API_DOMAIN"; then
        log_error "Failed to generate Nginx configuration"
        exit 1
    fi
    log_info "Frontend domain: ${DOMAIN}"
    log_info "API domain: ${API_DOMAIN}"
else
    # For other server types, only pass the single domain
    if ! generate_nginx_config "/etc/nginx/sites-available/narro" "$SERVER_TYPE" "$DOMAIN"; then
        log_error "Failed to generate Nginx configuration"
        exit 1
    fi
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
echo "Server provisioning is complete. Your $SERVER_TYPE server is ready for deployment."
echo ""
echo "1. Get SSL certificate (as root):"
if [ "$SERVER_TYPE" = "staging" ]; then
    echo "   sudo certbot --nginx -d ${DOMAIN}"
    if [ "$DOMAIN" != "$API_DOMAIN" ]; then
        echo "   sudo certbot --nginx -d ${API_DOMAIN}"
    fi
elif [ "$SERVER_TYPE" = "frontend" ]; then
    echo "   sudo certbot --nginx -d ${DOMAIN}"
    echo "   sudo certbot --nginx -d www.${DOMAIN}"
else
    echo "   sudo certbot --nginx -d ${DOMAIN}"
fi
echo ""
echo "2. Deploy via CI/CD:"
if [ "$SERVER_TYPE" = "scraper" ]; then
    echo "   Push code to main branch in the scraper repository"
else
    echo "   Push code to main branch in the repository (web/ or backend/)"
fi
echo "   The build-and-deploy.yml workflow will automatically:"
echo "   - Build Docker images"
echo "   - Push to container registry"
echo "   - Deploy to this server via the deploy script"
echo ""
echo "3. Verify deployment (after CI/CD completes):"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo "   Or manually verify services:"
if [ "$SERVER_TYPE" = "backend" ]; then
    echo "   curl http://localhost:3000/api/health  (backend)"
elif [ "$SERVER_TYPE" = "frontend" ]; then
    echo "   curl http://localhost:3001            (frontend)"
elif [ "$SERVER_TYPE" = "scraper" ]; then
    echo "   curl http://localhost:8000/health      (scraper)"
fi
echo ""
echo "Environment:"
echo "   Deployment directory: ${NARRO_HOME}/deployment"
echo "   Nginx config: /etc/nginx/sites-available/narro"
echo "   Narro user: ${NARRO_USER}"
echo ""
echo -e "${GREEN}✓ Server provisioning finished${NC}"
echo ""

