# Deployment Scripts

## Files

- `scripts/provision-debian.sh` - One-time server provisioning script for Debian/Ubuntu (supports frontend, backend, or single-server modes)
- `scripts/deploy-web.sh` - Deployment script for frontend (web) server - pulls narro-web image and starts container
- `scripts/deploy-api.sh` - Deployment script for backend (API) server - pulls narro-api image and starts container
- `scripts/env.prod` - Example production environment file template (legacy, for single-server)
- `scripts/env.frontend.example` - Example environment file for frontend servers
- `scripts/env.backend.example` - Example environment file for backend servers

## Quick Start - Single Server (Default)

### 1. Provision Server (One-time, as root)

```bash
# On your Debian/Ubuntu server, as root:
DOMAIN=narro.info bash provision-debian.sh
# Or specify server type explicitly:
DOMAIN=narro.info bash provision-debian.sh single
```

This will:
- Install Docker and Docker Compose
- Install and configure Nginx
- Create narro user and directory structure
- Set up Nginx configuration for both API and web

### 2. Configure Environment (as narro user)

```bash
# Switch to narro user
su - narro
cd ~/deployment

# Copy docker-compose.yml to this directory
cp /path/to/docker-compose.yml .

# Create .env.production from template
cp ../scripts/env.prod .env.production

# Edit with your secrets
nano .env.production

# Set secure permissions
chmod 600 .env.production
```

### 3. Get SSL Certificate (as root)

```bash
sudo certbot --nginx -d narro.info -d www.narro.info
```

### 4. Deploy (as narro user)

For single-server deployments, both services are included in `docker-compose.yml`. You'll need to either:

**Option A:** Use both deploy scripts sequentially
```bash
cd ~/deployment
./scripts/deploy-web.sh   # Deploy web service
./scripts/deploy-api.sh   # Deploy API service
```

**Option B:** Use docker-compose directly (if you prefer not to use scripts)
```bash
cd ~/deployment
docker compose pull
docker compose up -d
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
./scripts/deploy-web.sh
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
./scripts/deploy-api.sh
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
- Verify DNS: `namerserver api.narro.info` should resolve to backend IP
- Check firewall: Backend port 443 must be accessible from frontend
- Verify backend is running: SSH to backend and run `docker compose ps`
- Check logs: `docker compose -f docker-compose.api.yml logs -f narro-api`

**SSL certificate issues:**
- Ensure backend server has outbound HTTP access for Certbot Let's Encrypt challenges
- Both domains must have valid DNS records before running certbot

---

## Single File Reference

| Mode | Provision | Deploy | Docker Compose | Environment |
|------|-----------|--------|----------------|-------------|
| Frontend | `provision-debian.sh frontend` | `scripts/deploy-web.sh` | `docker-compose.web.yml` | `env.frontend.example` |
| Backend | `provision-debian.sh backend` | `scripts/deploy-api.sh` | `docker-compose.api.yml` | `env.backend.example` |
| Single | `provision-debian.sh` (or `provision-debian.sh single`) | `scripts/deploy-web.sh` + `scripts/deploy-api.sh` | `docker-compose.yml` | `env.prod` |

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

### Docker not accessible
```bash
# Ensure Docker is running
sudo systemctl start docker

# Check user is in docker group
groups

# If not, add and relogin:
sudo usermod -aG docker narro
# Then log out and back in
```

### Ports already in use
```bash
# Check what's using ports 3000/3001
sudo netstat -tlnp | grep -E '3000|3001'
```

### Container won't start
```bash
# Check logs
docker compose logs narro-api
docker compose logs narro-web

# Check container status
docker compose ps
```

## Notes

- All scripts assume running in `/home/narro/deployment`
- Docker Compose uses the newer `docker compose` syntax (not `docker-compose`)
- Secrets are stored in `.env.production` (NOT in git)
- SSL certificates are managed by Certbot
- Services run on ports 3000 (API) and 3001 (Web) internally
- Nginx proxies these to port 80/443
