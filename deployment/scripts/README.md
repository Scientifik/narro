# Deployment Scripts

## Files

- `provision-debian.sh` - One-time server provisioning script for Debian/Ubuntu (supports frontend, backend, or single-server modes)
- `env.prod` - Example production environment file template (for single-server deployments)
- `env.frontend.example` - Example environment file for frontend servers
- `env.backend.example` - Example environment file for backend servers

**Note:** Deployment scripts (`deploy.sh`) are maintained in the **web** and **backend** repositories separately. This allows each service to manage its own deployment independently. The provisioning script here only handles server setup (Docker, Nginx, user accounts).

## Quick Start - Single Server (Default)

For a single server running both API and web services.

### 1. Provision Server (One-time, as root)

```bash
# On your Debian/Ubuntu server, as root:
export DOMAIN=narro.info
bash provision-debian.sh
# Or specify server type explicitly:
bash provision-debian.sh single
```

This script will:
- Detect OS (Debian/Ubuntu) and install correct Docker version
- Install Docker, Docker Compose, Nginx, and Certbot
- Create `narro` user and directory structure
- Configure Nginx with reverse proxy for API and web
- Set up firewall rules (UFW or iptables)

### 2. Configure Environment (as narro user)

```bash
# Switch to narro user
su - narro
cd ~/deployment

# Copy docker-compose.yml from narro repo to this directory
cp /path/to/narro/deployment/docker-compose.yml .

# Create environment file from template
cp /path/to/narro/deployment/scripts/env.prod .env.production

# Edit with your secrets (database URL, registry credentials, etc.)
nano .env.production

# Set secure permissions
chmod 600 .env.production
```

### 3. Get SSL Certificate (as root)

```bash
# Run as root - ensures port 443 is free
sudo certbot --nginx -d narro.info -d www.narro.info
```

### 4. Deploy Services (as narro user)

Deploy using Docker Compose:

```bash
cd ~/deployment

# Pull latest images from registry
docker compose pull

# Start services (API on :3000, web on :3001)
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

---

## Multi-Host Deployment (Frontend + Backend)

For production deployments with separated frontend and backend servers on a private network.

### Architecture Overview

```
┌─────────────────────────────┐
│   Frontend Server           │
│  Domain: narro.info         │
│  ┌─────────────────────┐    │
│  │  Nginx              │    │ :80/:443
│  │  - Serves web app   │    ├─────────► Internet
│  │  - Proxies /api/*   │    │
│  │    to backend       │    │
│  │  ┌─────────────────┐│    │
│  │  │ narro-web       ││    │
│  │  │ (Next.js)       ││    │
│  │  └─────────────────┘│    │
│  └─────────────────────┘    │
└─────────────────────────────┘
          ↕ (Private Network)
┌─────────────────────────────┐
│   Backend Server            │
│  Domain: api.narro.info     │
│  ┌─────────────────────┐    │
│  │  Nginx              │    │ :80/:443
│  │  - Proxies /api/*   │    ├─────────► Internet
│  │    to API server    │    │
│  │  ┌─────────────────┐│    │
│  │  │ narro-api       ││    │
│  │  │ (Go REST API)   ││    │
│  │  └─────────────────┘│    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

### Prerequisites

- Two Debian/Ubuntu 22.04 LTS servers
- Both servers on a private network (VPC/VPN)
- DNS configured:
  - `narro.info` → Frontend server IP
  - `api.narro.info` → Backend server IP (can be private IP within VPC)
- Each server has public internet access for Docker pulls

### Provisioning Steps

#### Frontend Server

```bash
# 1. As root, provision frontend server
sudo DOMAIN=narro.info bash provision-debian.sh frontend

# 2. Switch to narro user and setup deployment
su - narro
cd ~/deployment

# 3. Copy frontend docker-compose
cp /path/to/docker-compose.web.yml .

# 4. Copy frontend environment template
cp ../scripts/env.frontend.example .env.production

# 5. Edit with your registry credentials and Supabase config
# IMPORTANT: Set NEXT_PUBLIC_API_URL=https://api.narro.info
nano .env.production
chmod 600 .env.production

# 6. As root, get SSL certificate
sudo certbot --nginx -d narro.info -d www.narro.info

# 7. Deploy frontend
cp /path/to/web/scripts/deploy.sh ./scripts/
bash ./scripts/deploy.sh
```

#### Backend Server

```bash
# 1. As root, provision backend server
sudo DOMAIN=api.narro.info bash provision-debian.sh backend

# 2. Switch to narro user and setup deployment
su - narro
cd ~/deployment

# 3. Copy backend docker-compose
cp /path/to/docker-compose.api.yml .

# 4. Copy backend environment template
cp ../scripts/env.backend.example .env.production

# 5. Edit with your registry credentials, database, and Supabase config
# REQUIRED: DATABASE_URL, SUPABASE_SERVICE_KEY
nano .env.production
chmod 600 .env.production

# 6. As root, get SSL certificate
sudo certbot --nginx -d api.narro.info

# 7. Deploy backend
cp /path/to/backend/scripts/deploy.sh ./scripts/
bash ./scripts/deploy.sh
```

### Testing Multi-Host Connectivity

After both servers are deployed:

```bash
# From frontend server, test API connectivity:
curl -v https://api.narro.info/api/health

# From local machine, test both services:
curl -v https://narro.info              # Frontend
curl -v https://api.narro.info/api/health  # Backend API
```

### Troubleshooting Multi-Host

**Frontend can't reach backend API:**
- Verify DNS: `nslookup api.narro.info` or `dig api.narro.info` should resolve to backend IP
- Check firewall: Backend port 443 must be accessible from frontend private network
- Verify backend is running: SSH to backend and run `docker compose ps`
- Check logs: `docker compose logs -f narro-api`

**SSL certificate issues:**
- Ensure both servers have outbound HTTP access (port 80) for Certbot Let's Encrypt challenges
- Both domains must have valid DNS records before running certbot
- For backend server behind firewall: ensure Let's Encrypt can reach the server during cert validation

---

## Single File Reference

| Mode | Provision | Deploy | Docker Compose | Environment |
|------|-----------|--------|----------------|-------------|
| Frontend | `provision-debian.sh frontend` | `web/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.web.yml` | `env.frontend.example` |
| Backend | `provision-debian.sh backend` | `backend/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.api.yml` | `env.backend.example` |
| Single | `provision-debian.sh` | `web/scripts/deploy.sh` + `backend/scripts/deploy.sh` (manual copy) | `docker-compose.yml` | `env.prod` |

**Note:** Deploy scripts are stored in the web and backend repositories, not in the narro repository. CI/CD workflows SCP these scripts to the server before execution.

## Directory Structure

After provisioning, your server will have:

```
/home/narro/
└── deployment/
    ├── docker-compose.yml    # Copy this from repo
    ├── .env.production       # Your secrets (create this)
    └── scripts/
        ├── deploy.sh
        └── env.prod          # Template
```

## Environment Variables

See `env.prod` for all required environment variables. Key ones:

- `REGISTRY_URL` - Container registry (e.g., `ord.vultrcr.com/narro`)
- `REGISTRY_USER` - Registry username
- `REGISTRY_PASSWORD` - Registry password
- `IMAGE_TAG` - Image tag to deploy (default: `latest`)
- `DATABASE_URL` - Supabase PostgreSQL connection string
- `SUPABASE_*` - Supabase configuration
- `NEXT_PUBLIC_*` - Frontend environment variables

## Troubleshooting

### Docker Repository/Installation Errors

**Error: "404 Not Found" for docker.com/linux/ubuntu or trixie Release**
- The script now auto-detects your OS (Debian vs Ubuntu) and uses the correct repository
- If you see this error, ensure you're running the latest version of `provision-debian.sh`
- The script reads `/etc/os-release` to determine OS, then uses `https://download.docker.com/linux/{debian|ubuntu}`

```bash
# To check your OS:
cat /etc/os-release | grep -E "^ID="
# Should show: debian or ubuntu
```

### Docker not accessible
```bash
# Ensure Docker is running
sudo systemctl start docker

# Check user is in docker group
groups

# If narro user not in docker group, add them:
sudo usermod -aG docker narro
# Then log out and back in as narro user
```

### Nginx configuration errors
```bash
# Test Nginx config
sudo nginx -t

# If test fails, check syntax
sudo nginx -T | tail -50

# Reload if valid
sudo systemctl reload nginx
```

### Ports already in use
```bash
# Check what's using ports 3000/3001/80/443
sudo ss -tlnp | grep -E ':3000|:3001|:80|:443'

# Or with netstat (if available)
sudo netstat -tlnp | grep -E '3000|3001|80|443'
```

### Container won't start
```bash
# Check logs
docker compose logs narro-api
docker compose logs narro-web

# Check container status
docker compose ps

# Inspect specific container
docker compose logs -f narro-api --tail 50
```

## Notes

- All scripts assume running in `/home/narro/deployment`
- Docker Compose uses the newer `docker compose` syntax (not `docker-compose`)
- Secrets are stored in `.env.production` (NOT in git)
- SSL certificates are managed by Certbot
- Services run on ports 3000 (API) and 3001 (Web) internally
- Nginx proxies these to port 80/443

## Recent Improvements

**v2.0 - December 2025**
- Fixed Docker repository detection for Debian vs Ubuntu systems
- Improved error handling with checks at each installation step
- Consolidated Nginx configuration code to reduce duplication (~150 lines → ~100 lines)
- Enhanced logging with color-coded messages and clear status indicators
- Added OS detection to automatically use correct Docker repository
- Improved firewall configuration with fallback from UFW to iptables
- Better error messages when installations fail
