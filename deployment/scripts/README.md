# Deployment Scripts

**Status:** CURRENT
**Last Updated:** 2026-01-31

---

## Quick Start

- **For production releases:** See [Tag Deployment Guide](../TAG_DEPLOYMENT.md)
- **For server setup:** Continue reading below

---

## Files

- `provision-debian.sh` - One-time server provisioning script for Debian/Ubuntu (supports frontend, backend, or scraper servers)
- `env.frontend.example` - Example environment file for frontend servers
- `env.backend.example` - Example environment file for backend servers
- `cleanup-registry-images.sh` - Clean up old Docker images from container registry
- `cleanup-images.sh` - Wrapper script that auto-loads credentials from env.prod
- `list-registry-images.sh` - List all container images in the registry

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

**Note:** The `.gitea/workflows/build-and-deploy.yml` workflow in each repository (web/, backend/, and scraper/) handles all deployment steps automatically. The deploy script is SCP'd to the server and executed by the CI/CD pipeline, which pulls the latest container images and starts the services.

#### Scraper Server

```bash
# 1. As root, provision scraper server
sudo DOMAIN=utility.narro.info bash provision-debian.sh scraper

# 2. As root, get SSL certificate
sudo certbot --nginx -d utility.narro.info

# 3. Push code to main branch
# The CI/CD pipeline will automatically:
#   - Build Docker images
#   - Push to container registry
#   - Deploy to this server via deploy script
git push origin main

# 4. Monitor deployment
# SSH to scraper server and check:
docker compose ps
docker compose logs -f narro-scraper-api
```

**Note:** The scraper server is internet-exposed (has public IP) and uses Nginx with SSL/TLS for security. The scraper API runs on port 8000 internally and is proxied through Nginx on port 443.

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

## Container Registry Cleanup

Each CI/CD build creates new container images tagged with commit SHAs. Over time, these accumulate in the registry and consume disk space. Use the cleanup scripts to remove old images while keeping recent ones.

### Quick Start

The easiest way to clean up images is using the wrapper script:

```bash
# Dry run - see what would be deleted (keeps last 5)
cd /Users/kurtdusek/Sites/narro/deployment/scripts
./cleanup-images.sh --dry-run

# Actually delete old images (keeps last 5)
./cleanup-images.sh

# Keep more images (e.g., last 10)
./cleanup-images.sh -k 10
```

The wrapper script automatically loads registry credentials from `env.prod` in the scripts directory.

### Manual Usage

For more control, use the main cleanup script directly:

```bash
# Dry run with environment variables
export REGISTRY_USER=your-username
export REGISTRY_PASSWORD=your-password
./cleanup-registry-images.sh --dry-run -k 5

# Clean up, keep last 3 images
./cleanup-registry-images.sh -u username -p password -k 3

# Clean up specific namespace
./cleanup-registry-images.sh -n narro -k 5
```

### What Gets Cleaned

The cleanup script:
- **Targets three repositories**: `narro/narro-api`, `narro/narro-web`, `narro/narro-scraper`
- **Keeps the N most recent tags** (default: 5) per repository
- **Protects special tags** that are never deleted:
  - `latest` - current production build
  - `staging-latest` - current staging build
  - `buildcache` - Docker layer cache for faster builds

### How It Works

1. Connects to Vultr Container Registry using Docker Registry API v2
2. Lists all tags for each repository
3. Filters out protected tags (`latest`, `staging-latest`, `buildcache`)
4. Sorts remaining tags by recency (based on commit SHAs)
5. Keeps the N most recent tags
6. Deletes older tags by fetching their manifest digest and calling DELETE endpoint

### Common Use Cases

```bash
# Before a major release - keep more history
./cleanup-images.sh -k 10

# After a release - aggressive cleanup
./cleanup-images.sh -k 3

# Check what would be deleted first
./cleanup-images.sh --dry-run

# List all images before cleanup
./list-registry-images.sh
```

### Scheduling Regular Cleanup

To automate cleanup, add a cron job on your deployment server:

```bash
# Run cleanup weekly on Sunday at 2am, keep last 5 images
0 2 * * 0 cd /home/narro/deployment/scripts && ./cleanup-images.sh -k 5 >> /var/log/registry-cleanup.log 2>&1
```

### Troubleshooting

**Authentication failures:**
- Verify `REGISTRY_USER` and `REGISTRY_PASSWORD` in `env.prod`
- Test credentials: `./list-registry-images.sh`

**No images deleted:**
- Check you have more than the keep count (e.g., >5 images)
- Verify you're not in dry-run mode
- Protected tags (`latest`, etc.) are never deleted

**Storage not freed:**
- Some registries require garbage collection to reclaim space
- Vultr may take some time to reflect storage changes
- Check registry documentation for garbage collection details

---

## Server Reference

| Mode | Provision | Deploy | Docker Compose | Environment |
|------|-----------|--------|----------------|-------------|
| Frontend | `provision-debian.sh frontend` | `web/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.web.yml` | `env.frontend.example` |
| Backend | `provision-debian.sh backend` | `backend/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.api.yml` | `env.backend.example` |
| Scraper | `provision-debian.sh scraper` | `scraper/scripts/deploy.sh` (via SCP in CI/CD) | `docker-compose.scraper.yml` | `env.production` (scraper-specific) |

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

### Gitea Runner Docker Connection Issues

**Error: "cannot ping the docker daemon, is it running? Cannot connect to the Docker daemon at unix:///var/run/docker.sock"**

This error occurs when the Gitea runner container cannot access the host Docker daemon. The runner needs the Docker socket mounted as a **bind mount**, not a Docker volume.

**Diagnosis:**
```bash
# Check if Docker socket is mounted correctly
docker inspect <runner-container> --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' | grep docker.sock

# Should show: /var/run/docker.sock -> /var/run/docker.sock
# If it shows: /var/lib/docker/volumes/... -> /var/run/docker.sock (WRONG - this is a volume, not bind mount)
```

**Fix:**
Recreate the runner container with the correct bind mount:
```bash
# Stop and remove the current container
docker stop <runner-container>
docker rm <runner-container>

# Recreate with correct Docker socket bind mount
docker run -d \
  --name gitea-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v <data-volume>:/data \
  -e <env-vars> \
  gitea/act_runner:latest
```

**Critical:** Use `-v /var/run/docker.sock:/var/run/docker.sock` (bind mount from host), **NOT** a Docker volume. The socket must be directly mounted from the host filesystem.

## Notes

- All scripts assume running in `/home/narro/deployment`
- Docker Compose uses the newer `docker compose` syntax (not `docker-compose`)
- Secrets are stored in `.env.production` (NOT in git)
- SSL certificates are managed by Certbot
- Services run on ports 3000 (API), 3001 (Web), and 8000 (Scraper) internally
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
