# Deployment Scripts

## Files

- `provision-debian.sh` - One-time server provisioning script for Debian/Ubuntu (supports frontend or backend servers)
- `env.frontend.example` - Example environment file for frontend servers
- `env.backend.example` - Example environment file for backend servers

**Note:** Deployment scripts (`deploy.sh`) are maintained in the **web** and **backend** repositories separately. This allows each service to manage its own deployment independently. The provisioning script here only handles server setup (Docker, Nginx, user accounts).

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

# 2. As root, get SSL certificate
sudo certbot --nginx -d narro.info -d www.narro.info

# 3. Push code to main branch
# The CI/CD pipeline will automatically:
#   - Build Docker images
#   - Push to container registry
#   - Deploy to this server via deploy script
git push origin main

# 4. Monitor deployment
# SSH to frontend server and check:
docker compose ps
docker compose logs -f narro-web
```

#### Backend Server

```bash
# 1. As root, provision backend server
sudo DOMAIN=api.narro.info bash provision-debian.sh backend

# 2. As root, get SSL certificate
sudo certbot --nginx -d api.narro.info

# 3. Push code to main branch
# The CI/CD pipeline will automatically:
#   - Build Docker images
#   - Push to container registry
#   - Deploy to this server via deploy script
git push origin main

# 4. Monitor deployment
# SSH to backend server and check:
docker compose ps
docker compose logs -f narro-api
```

**Note:** The `.gitea/workflows/build-and-deploy.yml` workflow in each repository (web/ and backend/) handles all deployment steps automatically. The deploy script is SCP'd to the server and executed by the CI/CD pipeline, which pulls the latest container images and starts the services.

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

## Server Reference

| Mode | Provision | Deploy | Docker Compose | Environment |
|------|-----------|--------|----------------|-------------|
| Frontend | `provision-debian.sh frontend` | `web/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.web.yml` | `env.frontend.example` |
| Backend | `provision-debian.sh backend` | `backend/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.api.yml` | `env.backend.example` |

**Note:** Deploy scripts are stored in the web and backend repositories, not in the narro repository. CI/CD workflows SCP these scripts to the server before execution.

## Directory Structure

After provisioning and CI/CD deployment, your server will have:

```
/home/narro/
└── deployment/
    ├── docker-compose.yml    # Created by CI/CD (web.yml or api.yml)
    ├── .env.production       # Created by CI/CD with env vars
    └── scripts/
        └── deploy.sh         # SCP'd by CI/CD from repo
```

All files in `/home/narro/deployment/` are created and managed by the CI/CD pipeline. Do not manually create or edit them - they will be overwritten on each deployment.

## Environment Variables

The CI/CD pipeline uses the following environment variables (configured in Gitea Actions secrets):

- `REGISTRY_URL` - Container registry URL (e.g., `ord.vultrcr.com/narro`)
- `REGISTRY_USER` - Registry login username
- `REGISTRY_PASSWORD` - Registry login password
- `DATABASE_URL` - Supabase PostgreSQL connection string
- `SUPABASE_SERVICE_KEY` - Supabase service role key (backend only)
- `SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_API_URL` - Backend API URL (frontend only, e.g., `https://api.narro.info`)
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase URL for frontend
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anonymous key for frontend
- `NEXT_PUBLIC_S3_BASE_URL` - S3 bucket URL for thumbnails (frontend only)

See `env.frontend.example` and `env.backend.example` for complete variable lists. These templates are referenced by the deploy scripts.

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
