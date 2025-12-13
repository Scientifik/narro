# Narro Deployment Guide

This guide covers the complete setup and deployment process for Narro production deployment on Vultr.

> **Note:** Deployment configuration files are located in the `deployment/` directory. This guide explains how to use them.

## Directory Structure

```
deployment/
├── docker-compose.yml              # Single-server setup (API + Web)
├── docker-compose.api.yml          # Backend API container only
├── docker-compose.web.yml          # Frontend web container only
├── .env.production                 # Production secrets (NOT in git, create manually)
├── nginx/
│   ├── nginx.api.conf              # Backend API Nginx config
│   ├── nginx.frontend.conf         # Frontend Nginx config (multi-server)
└── scripts/                        # Deployment scripts
    ├── provision-debian.sh         # Server provisioning script
    ├── deploy.sh                   # Container deployment script
    ├── env.prod                    # Environment template (single-server)
    ├── env.frontend.example        # Environment template (frontend)
    └── env.backend.example         # Environment template (backend)
```

## Prerequisites

1. **Vultr instance running** (Ubuntu 22.04 LTS recommended)
2. **Docker & Docker Compose installed**
3. **Nginx installed** (for reverse proxy)
4. **Domain configured** (narro.info) pointing to Vultr instance IP
5. **Gitea repository** with deployment scripts
6. **Gitea Actions runners** configured (if using Gitea Actions for CI/CD)

## Initial Setup

### 1. Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Create Directory Structure

```bash
# Create directories
mkdir -p /home/narro/{app,deployment/{scripts,logs,nginx}}

# Clone repository
cd /home/narro/app
git clone <your-gitea-repo-url> .
```

### 3. Create Production Environment File

```bash
# Create .env.production (you'll paste secrets here)
touch /home/narro/deployment/.env.production
chmod 600 /home/narro/deployment/.env.production
nano /home/narro/deployment/.env.production
```

**Required environment variables:**

```bash
# Server Configuration
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database (Supabase)
DATABASE_URL=postgresql://user:password@host:5432/dbname
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key

# API Configuration
API_BASE_URL=https://narro.info
NEXT_PUBLIC_API_URL=https://narro.info
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Scraping APIs
SCRAPING_API_KEY=your-scraperapi-key
SCRAPING_API_URL=https://api.scraperapi.com
APIFY_API_TOKEN=your-apify-token
APIFY_API_URL=https://api.apify.com/v2

# S3 Storage (for thumbnails)
STORAGE_S3_BUCKET=your-bucket-name
STORAGE_S3_REGION=us-east-1
STORAGE_S3_ENDPOINT=
STORAGE_S3_ACCESS_KEY_ID=your-access-key-id
STORAGE_S3_SECRET_ACCESS_KEY=your-secret-access-key
STORAGE_S3_USE_SSL=true
STORAGE_S3_PUBLIC_BASE_URL=https://your-bucket-name.region.digitaloceanspaces.com

# Optional: Stripe, Sentry, etc.
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
SENTRY_DSN=your-sentry-dsn
```

### 4. Copy Deployment Files

```bash
# Copy docker-compose files
cp /home/narro/app/deployment/*.yml /home/narro/deployment/

# Copy deployment scripts
cp /home/narro/app/deployment/scripts/*.sh /home/narro/deployment/scripts/
chmod +x /home/narro/deployment/scripts/*.sh

# Copy Nginx config
cp /home/narro/app/deployment/nginx/nginx.conf /home/narro/deployment/nginx/
```

### 5. Setup Nginx

See [Nginx Setup Guide](nginx-setup.md) for detailed Nginx setup instructions, including SSL/TLS with Let's Encrypt.

### 6. Setup Scraper Cron Job

```bash
# Edit crontab
crontab -e

# Add line to run scraper every 6 hours
0 */6 * * * /home/narro/deployment/scripts/cron-scraper.sh >> /home/narro/deployment/logs/cron.log 2>&1
```

---

## Multi-Host Deployment (Frontend + Backend Separation)

For production environments with dedicated frontend and backend servers running on a private network, use this section instead of the single-server setup above.

### Architecture Overview

**Frontend Server** (`narro.info`)
- Runs: Nginx (reverse proxy) + Next.js Web Container
- Purpose: Serves web UI, proxies API requests to backend
- Ports: 80/443 (public), connects to backend via private network

**Backend Server** (`api.narro.info`)
- Runs: Nginx (reverse proxy) + Go API Container
- Purpose: Serves REST API, connects to database
- Ports: 80/443 (on private network or public with firewall)

**Network**: Both servers communicate over a private network (VPC, VPN, or private LAN).

### Prerequisites for Multi-Host

1. **Two Debian/Ubuntu 22.04 LTS servers**
2. **Private network connection between servers** (Vultr VPC, AWS VPC, etc.)
3. **DNS Configuration**:
   - `narro.info` → Frontend Server IP (public)
   - `api.narro.info` → Backend Server IP (public or private VPC IP)
4. **Firewall Rules**:
   - Frontend: Allow 80, 443 from anywhere
   - Backend: Allow 80, 443 from Frontend server IP (or entire VPC)
5. **Database Access**: Backend server must reach Supabase/PostgreSQL

### Multi-Host Provisioning

#### Step 1: Provision Frontend Server

On the frontend server, as root:

```bash
# Download provisioning script
cd /tmp
curl -O https://your-repo-url/deployment/scripts/provision-debian.sh
chmod +x provision-debian.sh

# Provision for frontend role
sudo DOMAIN=narro.info bash provision-debian.sh frontend
```

Then as the `narro` user:

```bash
su - narro
cd ~/deployment

# Copy docker-compose file for web container
cp /path/to/docker-compose.web.yml .

# Copy frontend environment template
cp /path/to/env.frontend.example .env.production

# Edit environment - CRITICAL: Set API URL to backend
nano .env.production
# Set: NEXT_PUBLIC_API_URL=https://api.narro.info

chmod 600 .env.production
```

As root, setup SSL:

```bash
sudo certbot --nginx -d narro.info -d www.narro.info
```

Then deploy:

```bash
su - narro
cd ~/deployment
./deploy.sh frontend
```

#### Step 2: Provision Backend Server

On the backend server, as root:

```bash
# Download provisioning script
cd /tmp
curl -O https://your-repo-url/deployment/scripts/provision-debian.sh
chmod +x provision-debian.sh

# Provision for backend role
sudo DOMAIN=api.narro.info bash provision-debian.sh backend
```

Then as the `narro` user:

```bash
su - narro
cd ~/deployment

# Copy docker-compose file for API container
cp /path/to/docker-compose.api.yml .

# Copy backend environment template
cp /path/to/env.backend.example .env.production

# Edit environment - CRITICAL: Set database and Supabase config
nano .env.production
# REQUIRED:
# - DATABASE_URL=postgresql://...
# - SUPABASE_URL=https://...
# - SUPABASE_SERVICE_KEY=...

chmod 600 .env.production
```

As root, setup SSL:

```bash
sudo certbot --nginx -d api.narro.info
```

Then deploy:

```bash
su - narro
cd ~/deployment
./deploy.sh backend
```

### Multi-Host Testing

After both servers are running:

```bash
# Test frontend (from your local machine)
curl -v https://narro.info

# Test backend API (from your local machine)
curl -v https://api.narro.info/api/health

# Test from frontend server to backend
ssh narro@frontend-ip
curl -v https://api.narro.info/api/health

# Check logs
docker compose -f docker-compose.web.yml logs -f narro-web   # Frontend server
docker compose -f docker-compose.api.yml logs -f narro-api   # Backend server
```

### Multi-Host Troubleshooting

**Frontend shows "Failed to fetch"**: API not reachable
- Check: `curl https://api.narro.info/api/health` from frontend server
- Verify DNS: `nslookup api.narro.info`
- Check firewall: Backend port 443 open to frontend
- Check logs: `docker compose logs narro-web`

**Backend unreachable**: Database or Supabase connection
- Verify `DATABASE_URL` in `.env.production`
- Check database connectivity: `psql $DATABASE_URL -c "SELECT 1"`
- Check logs: `docker compose logs narro-api`
- Verify Supabase credentials in `.env.production`

**SSL certificate issues**:
- Ensure both domains resolve correctly: `nslookup narro.info` and `nslookup api.narro.info`
- Check Certbot logs: `sudo tail -f /var/log/letsencrypt/letsencrypt.log`
- Verify ports 80/443 are accessible for Certbot challenges

---

## Deployment

### Manual Deployment

```bash
cd /home/narro/deployment
bash scripts/deploy.sh
```

### Automated Deployment (Separate Repository CI/CD)

With separate **web** and **backend** repositories, each has its own Gitea Actions workflow that independently builds Docker images and deploys to their respective servers.

#### Web Repository Workflow

**Location:** `web/.gitea/workflows/build-and-deploy.yml`

**Triggers:** Push to `main` branch

**Workflow:**
1. Checks out code
2. Sets up Docker Buildx
3. Logs into container registry
4. Builds and pushes `narro-web` image (with tags: `latest` and commit SHA)
5. SSHes to `VULTR_FRONTEND_HOST`
6. Runs `bash scripts/deploy.sh frontend` to pull and deploy web container

**Required Secrets (Web Repository):**
- `REGISTRY_URL` - Container registry URL (e.g., `ord.vultrcr.com/narro`)
- `REGISTRY_USER` - Registry username
- `REGISTRY_PASSWORD` - Registry password
- `VULTR_FRONTEND_HOST` - Frontend server IP/hostname
- `VULTR_USER` - SSH username (usually `narro`)
- `VULTR_SSH_KEY` - Private SSH key for authentication
- `VULTR_DEPLOY_PATH` - Deployment directory (e.g., `/home/narro/deployment`)

**Optional Secrets (Web Repository):**
- `NEXT_PUBLIC_API_URL` - API URL for frontend (defaults to `https://api.narro.info`)
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anonymous key
- `NEXT_PUBLIC_SENTRY_DSN` - Sentry DSN for frontend
- `SENTRY_ORG` - Sentry organization
- `SENTRY_PROJECT` - Sentry project name
- `SENTRY_AUTH_TOKEN` - Sentry auth token

#### Backend Repository Workflow

**Location:** `backend/.gitea/workflows/build-and-deploy.yml`

**Triggers:** Push to `main` branch

**Workflow:**
1. Checks out code
2. Sets up Docker Buildx
3. Logs into container registry
4. Builds and pushes `narro-api` image (with tags: `latest` and commit SHA)
5. SSHes to `VULTR_BACKEND_HOST`
6. Runs `bash scripts/deploy.sh backend` to pull and deploy API container

**Required Secrets (Backend Repository):**
- `REGISTRY_URL` - Container registry URL (e.g., `ord.vultrcr.com/narro`)
- `REGISTRY_USER` - Registry username
- `REGISTRY_PASSWORD` - Registry password
- `VULTR_BACKEND_HOST` - Backend server IP/hostname
- `VULTR_USER` - SSH username (usually `narro`)
- `VULTR_SSH_KEY` - Private SSH key for authentication
- `VULTR_DEPLOY_PATH` - Deployment directory (e.g., `/home/narro/deployment`)

#### Deployment Flow

```
┌─────────────────────────────┐
│  Web Repo Push to Main      │
└──────────────┬──────────────┘
               ↓
       Build narro-web
               ↓
    Push to Registry
               ↓
    SSH to FRONTEND
    deploy.sh frontend
               ↓
    FRONTEND Server Updates

┌─────────────────────────────┐
│ Backend Repo Push to Main   │
└──────────────┬──────────────┘
               ↓
       Build narro-api
               ↓
    Push to Registry
               ↓
    SSH to BACKEND
    deploy.sh backend
               ↓
    BACKEND Server Updates
```

**Key Benefits:**
- **Independent deployments** - Web and backend deploy separately
- **Concurrent updates** - Both can deploy simultaneously if both repos change
- **Flexible updates** - Update only what changed (frontend only, backend only, or both)
- **Consistent deployment** - Both use the same `deploy.sh` script

#### Setting up Gitea Actions

1. **Ensure Gitea Actions is enabled** on your Gitea instance
2. **Configure Gitea Actions runners** (self-hosted or cloud) with Docker installed
3. **Add secrets to each repository:**
   - Go to repository Settings → Secrets
   - Add required secrets listed above for each repo
   - For `VULTR_SSH_KEY`, paste the full private key content (including `-----BEGIN` and `-----END` lines)
4. **Deploy servers must:**
   - Have `deploy.sh` and `docker-compose` files in `$VULTR_DEPLOY_PATH`
   - Have deployment scripts provisioned with `provision-debian.sh` (frontend or backend)
5. **Verify workflows:**
   - Push to `main` branch of web repo → frontend updates
   - Push to `main` branch of backend repo → backend updates
   - Check Actions tab in Gitea to view workflow runs

#### Image Tagging

Images are tagged with both `latest` and commit SHA:
- `ord.vultrcr.com/narro/narro-web:latest` and `ord.vultrcr.com/narro/narro-web:a1b2c3d`
- `ord.vultrcr.com/narro/narro-api:latest` and `ord.vultrcr.com/narro/narro-api:f9e8d7c`

The `deploy.sh` script uses the `IMAGE_TAG` environment variable (set to commit SHA by workflow) for pinpoint deployments of specific versions.

#### Troubleshooting CI/CD

**Workflow fails: "SSH host key verification failed"**
- Verify `VULTR_FRONTEND_HOST` or `VULTR_BACKEND_HOST` is correct and accessible
- Verify `VULTR_SSH_KEY` is properly formatted (includes BEGIN/END lines)
- Test SSH manually from local machine

**Workflow fails: "Image not found"**
- Verify registry secrets are correct
- Check that image was actually pushed to registry
- Verify Docker build step completed successfully

**Deployment succeeds but container won't start**
- SSH to server and check logs:
  ```bash
  # Frontend
  docker compose -f docker-compose.web.yml logs -f narro-web
  # Backend
  docker compose -f docker-compose.api.yml logs -f narro-api
  ```
- Verify `.env.production` has all required variables

**Frontend can't reach API after deployment**
- Verify `NEXT_PUBLIC_API_URL` secret is set to correct backend URL
- From frontend server, test connectivity:
  ```bash
  curl -v https://api.narro.info/api/health
  ```

## Service Management

### Start Services

```bash
cd /home/narro/deployment
docker-compose up -d
```

### Stop Services

```bash
docker-compose down
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f narro-api
docker-compose logs -f narro-web
```

### Run Scraper Manually

```bash
cd /home/narro/deployment
docker-compose -f docker-compose.scraper.yml run --rm narro-scraper python3 run.py
```

## Health Checks

### Manual Health Check

```bash
cd /home/narro/deployment
bash scripts/health-check.sh
```

### Check Service Status

```bash
docker-compose ps
docker stats
```

## Multi-Server Setup

If you want to split services across multiple servers:

1. **Create shared network** (on one server):
   ```bash
   docker network create narro-network
   ```

2. **Deploy API on server 1:**
   ```bash
   docker-compose -f docker-compose.api.yml up -d
   ```

3. **Deploy Web on server 2:**
   ```bash
   docker-compose -f docker-compose.web.yml up -d
   ```

4. **Update Nginx** to use `nginx.lb.conf` with actual server IPs (see [Nginx Setup Guide](nginx-setup.md))

5. **Update environment variables:**
   - Web server: `NEXT_PUBLIC_API_URL=http://api-server-ip:3000`
   - Or use DNS: `NEXT_PUBLIC_API_URL=http://api.narro.info`

## Troubleshooting

### Services won't start

1. Check logs: `docker-compose logs`
2. Verify `.env.production` exists and has correct values
3. Check Docker: `docker ps -a`
4. Verify ports aren't in use: `sudo netstat -tlnp | grep -E '3000|3001'`

### Health checks failing

1. Check service logs: `docker-compose logs narro-api`
2. Manual health check: `curl http://localhost:3000/api/health`
3. Verify environment variables: `docker exec narro-api env | grep DATABASE_URL`

### Scraper not running

1. Check cron logs: `tail -f /home/narro/deployment/logs/cron.log`
2. Test manually: `bash /home/narro/deployment/scripts/cron-scraper.sh`
3. Verify cron job: `crontab -l`

### Nginx issues

1. Test config: `sudo nginx -t`
2. Check logs: `sudo tail -f /var/log/nginx/narro-error.log`
3. Verify SSL certificates: `sudo certbot certificates`

## Rollback

If deployment fails:

```bash
cd /home/narro/app
git log --oneline  # Find previous commit
git reset --hard <previous-commit-hash>
cd ../deployment
bash scripts/deploy.sh
```

## Security Notes

- `.env.production` should have `chmod 600` permissions
- Never commit `.env.production` to git
- Rotate secrets regularly
- Keep Docker and system packages updated
- Monitor logs for suspicious activity

## Backup

- Database: Handled by Supabase (automatic backups)
- Thumbnails: Stored in S3 - configure S3 bucket versioning and lifecycle policies for backups
- Configuration: Backup `.env.production` securely (not in git)

## Monitoring

Consider setting up:
- Uptime monitoring (UptimeRobot, Pingdom)
- Error tracking (Sentry)
- Log aggregation (if needed)
- Resource monitoring (CPU, memory, disk)

## Related Documentation

- [Deployment Summary](deployment-summary.md) - Overview of deployment infrastructure
- [Nginx Setup Guide](nginx-setup.md) - Detailed Nginx and SSL configuration
- [Architecture Documentation](architecture.md) - System architecture overview




