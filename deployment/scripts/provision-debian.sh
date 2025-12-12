#!/bin/bash
# Debian/Ubuntu Server Provisioning Script for Narro
# One-time setup: Installs Docker, Nginx, and basic configuration
# Run as root on a fresh Debian 12+ or Ubuntu 22.04 installation
# Usage: sudo bash provision-debian.sh [frontend|backend|single]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Must run as root (use sudo)"
    exit 1
fi

# Configuration
SERVER_TYPE="${1:-single}"  # frontend, backend, or single (default)

# Validate server type
if [[ ! "$SERVER_TYPE" =~ ^(frontend|backend|single)$ ]]; then
    log_error "Invalid server type: $SERVER_TYPE"
    log_error "Usage: sudo bash provision-debian.sh [frontend|backend|single]"
    exit 1
fi

# Set DOMAIN defaults based on server type
if [ "$SERVER_TYPE" = "frontend" ]; then
    DOMAIN="${DOMAIN:-narro.info}"
elif [ "$SERVER_TYPE" = "backend" ]; then
    DOMAIN="${DOMAIN:-api.narro.info}"
else
    DOMAIN="${DOMAIN:-alpha.narro.info}"
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
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
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

# Create Nginx configuration
log_info "Configuring Nginx..."

# Generate appropriate nginx config based on server type
if [ "$SERVER_TYPE" = "frontend" ]; then
    log_info "Configuring Nginx for FRONTEND server"
    cat > /etc/nginx/sites-available/narro << NGINX_EOF
# Nginx configuration for Narro Frontend
# Domain: ${DOMAIN}

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
    server_name ${DOMAIN} www.${DOMAIN};

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
}

# HTTPS server will be added by Certbot when you run: certbot --nginx -d ${DOMAIN}
NGINX_EOF
elif [ "$SERVER_TYPE" = "backend" ]; then
    log_info "Configuring Nginx for BACKEND server"
    cat > /etc/nginx/sites-available/narro << NGINX_EOF
# Nginx configuration for Narro API Backend
# Domain: ${DOMAIN}

upstream api {
    server localhost:3000;  # Local Go API server
    keepalive 32;
}

# HTTP server - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

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

# HTTPS server will be added by Certbot when you run: certbot --nginx -d ${DOMAIN}
NGINX_EOF
else
    log_info "Configuring Nginx for SINGLE server (default)"
    cat > /etc/nginx/sites-available/narro << NGINX_EOF
# Nginx configuration for Narro (Single Server)
# Domain: ${DOMAIN}

upstream api {
    server localhost:3000;
    keepalive 32;
}

upstream web {
    server localhost:3001;
    keepalive 32;
}

# HTTP server - serves content initially, Certbot will add HTTPS and redirect
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

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

    # Web app
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

# HTTPS server will be added by Certbot when you run: certbot --nginx -d ${DOMAIN}
NGINX_EOF
fi

# Enable site
ln -sf /etc/nginx/sites-available/narro /etc/nginx/sites-enabled/narro

# Remove default Nginx site if it exists
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
log_info "Testing Nginx configuration..."
if nginx -t; then
    log_info "Nginx configuration valid"
    systemctl reload nginx
else
    log_error "Nginx configuration test failed"
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
log_warn ""
log_warn "Next steps:"
log_warn "1. su - ${NARRO_USER}"
log_warn "2. cd ${NARRO_HOME}/deployment"
log_warn "3. Copy docker-compose.yml to this directory"
log_warn "4. Create .env.production file with your secrets (see env.prod example)"
log_warn "5. chmod 600 .env.production"
log_warn "6. certbot --nginx -d ${DOMAIN}  # Get SSL certificate (as root)"
log_warn "7. ./deploy.sh  # Deploy containers (as narro user)"

