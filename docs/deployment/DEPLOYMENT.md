# Narro Deployment Guide

**Status:** ✅ CURRENT
**Last Updated:** 2026-02-06
**Consolidated From:** deployment-guide.md, deployment-summary.md, nginx-setup.md

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Multi-Host Deployment](#multi-host-deployment)
5. [Nginx Configuration](#nginx-configuration)
6. [SSL/TLS Setup](#ssltls-setup)
7. [Service Management](#service-management)
8. [Health Checks](#health-checks)
9. [Troubleshooting](#troubleshooting)
10. [Security](#security)
11. [Backup & Monitoring](#backup--monitoring)

---

## Overview

This guide covers complete deployment setup for Narro on Vultr infrastructure. Narro uses a **multi-host architecture** with separate frontend and backend servers, deployed via automated CI/CD pipelines.

### Key Features

- **Zero-downtime deployments** via health checks and graceful restarts
- **Multi-server architecture** with dedicated frontend/backend servers
- **Automated CI/CD** via Gitea Actions workflows
- **Container registry deployment** using Vultr Container Registry
- **SSL/TLS encryption** via Let's Encrypt
- **Scraper as cron job** (not a long-running service)

---

## Architecture

### Production Environment

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
          ↕ (Private Network or Public)
┌─────────────────────────────┐
│   Backend Server            │
│  Domain: api.narro.info     │
│  ┌─────────────────────┐    │
│  │  Nginx              │    │ :80/:443
│  │  │ narro-api       ││    │
│  │  │ (Go REST API)   ││    │
│  │  └─────────────────┘│    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

### Staging Environment

**Single server** hosting both backend and web:
- Backend on port 3000
- Web on port 3001
- Nginx proxies both services
- Uses `docker-compose.staging.yml`

---

## Prerequisites

### Server Requirements

- **OS:** Debian 12+ or Ubuntu 22.04 LTS+
- **RAM:** 2GB minimum (4GB recommended)
- **Disk:** 20GB minimum
- **Network:** Public IP + optional private network between servers

### Required Software

- Docker 24.0+
- Docker Compose 2.20+
- Nginx 1.18+
- Certbot (for SSL)
- Git

### DNS Configuration

- `narro.info` → Frontend server public IP
- `api.narro.info` → Backend server IP (public or VPC private)
- `staging.narro.info` → Staging server IP (if separate staging environment)

### Access Requirements

- SSH access to all servers
- Vultr Container Registry credentials
- Supabase database credentials
- Domain registrar access for DNS

---

## Multi-Host Deployment

### Step 1: Provision Frontend Server

Run the provisioning script on the frontend server as root:

```bash
# Download provisioning script
cd /tmp
wget https://raw.githubusercontent.com/your-org/narro/main/deployment/scripts/provision-debian.sh

# Make executable
chmod +x provision-debian.sh

# Provision for frontend role
sudo DOMAIN=narro.info bash provision-debian.sh frontend
```

**What this does:**
- Creates `narro` user with sudo access
- Installs Docker and Docker Compose
- Installs Nginx
- Sets up deployment directory structure at `/home/narro/deployment`
- Configures firewall (ports 22, 80, 443)
- Configures Nginx for frontend (serves web app, proxies `/api/*` to backend)

### Step 2: Provision Backend Server

Run the provisioning script on the backend server as root:

```bash
# Same provisioning script, different role
sudo DOMAIN=api.narro.info bash provision-debian.sh backend
```

**What this does:**
- Creates `narro` user with sudo access
- Installs Docker and Docker Compose
- Installs Nginx
- Sets up deployment directory at `/home/narro/deployment`
- Configures Nginx for backend (proxies to API on port 3000)
- Configures firewall

### Step 3: Configure Environment Files

**On Frontend Server:**

```bash
su - narro
cd ~/deployment

# Copy environment template
cp /path/to/deployment/scripts/env.frontend.example .env.production

# Edit with your secrets
nano .env.production
```

**Required frontend environment variables:**

```bash
# API Configuration
NEXT_PUBLIC_API_URL=https://api.narro.info

# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Optional: Sentry, analytics
NEXT_PUBLIC_SENTRY_DSN=your-sentry-dsn

# Container Registry
REGISTRY_URL=ord.vultrcr.com/narro
IMAGE_TAG=latest
```

**On Backend Server:**

```bash
su - narro
cd ~/deployment

# Copy environment template
cp /path/to/deployment/scripts/env.backend.example .env.production

# Edit with your secrets
nano .env.production
```

**Required backend environment variables:**

```bash
# Server
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-key

# S3 Storage
STORAGE_S3_BUCKET=your-bucket-name
STORAGE_S3_REGION=us-east-1
STORAGE_S3_ACCESS_KEY_ID=your-access-key
STORAGE_S3_SECRET_ACCESS_KEY=your-secret-key
STORAGE_S3_PUBLIC_BASE_URL=https://your-bucket.s3.amazonaws.com

# Scraping APIs (if needed)
SCRAPERAPI_API_KEY=your-key
APIFY_API_TOKEN=your-token

# Container Registry
REGISTRY_URL=ord.vultrcr.com/narro
IMAGE_TAG=latest
```

**Set proper permissions:**

```bash
chmod 600 .env.production
```

### Step 4: Deploy Docker Compose Files

The CI/CD pipeline automatically deploys the correct docker-compose files to each server, but you can also deploy manually:

**On Frontend Server:**

```bash
cd ~/deployment

# Copy docker-compose.web.yml from repository
# (CI/CD does this automatically via SCP)
```

**On Backend Server:**

```bash
cd ~/deployment

# Copy docker-compose.api.yml from repository
# (CI/CD does this automatically via SCP)
```

### Step 5: Configure SSL Certificates

**On each server, as root:**

```bash
# Install Certbot
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# Frontend server
sudo certbot --nginx -d narro.info -d www.narro.info

# Backend server
sudo certbot --nginx -d api.narro.info
```

**Certbot will:**
- Obtain SSL certificates from Let's Encrypt
- Automatically configure Nginx with SSL
- Set up auto-renewal via systemd timer

**Verify auto-renewal:**

```bash
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

### Step 6: Deploy via CI/CD

**For automatic deployment:**

Push to the appropriate branch in each repository (backend, web):

```bash
# Backend repo
cd backend
git push origin main  # Triggers production deployment to backend server

# Web repo
cd web
git push origin main  # Triggers production deployment to frontend server
```

See [CI/CD Guide](CICD.md) for complete workflow documentation.

**For manual deployment:**

```bash
# On frontend server
su - narro
cd ~/deployment
docker compose -f docker-compose.web.yml pull
docker compose -f docker-compose.web.yml up -d

# On backend server
su - narro
cd ~/deployment
docker compose -f docker-compose.api.yml pull
docker compose -f docker-compose.api.yml up -d
```

### Step 7: Verify Deployment

**Check services are running:**

```bash
# On each server
docker compose ps
docker compose logs -f narro-web    # Frontend
docker compose logs -f narro-api    # Backend
```

**Test endpoints:**

```bash
# From your local machine
curl -v https://narro.info/              # Frontend
curl -v https://api.narro.info/api/health  # Backend API

# From frontend server (test backend connectivity)
ssh narro@frontend-server
curl -v https://api.narro.info/api/health
```

---

## Nginx Configuration

### Configuration Files

Nginx configurations are generated by the provisioning script and stored at:

- Frontend: `/etc/nginx/sites-available/narro`
- Backend: `/etc/nginx/sites-available/narro-api`

### Frontend Nginx Config (Generated)

Key settings for frontend server:

```nginx
server {
    listen 80;
    server_name narro.info www.narro.info;

    location / {
        proxy_pass http://localhost:3001;  # Next.js web app
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Proxy API requests to backend
    location /api/ {
        proxy_pass https://api.narro.info;
        proxy_set_header Host api.narro.info;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Backend Nginx Config (Generated)

Key settings for backend server:

```nginx
server {
    listen 80;
    server_name api.narro.info;

    location / {
        proxy_pass http://localhost:3000;  # Go API
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Nginx Commands

```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# View error logs
sudo tail -f /var/log/nginx/error.log

# View access logs
sudo tail -f /var/log/nginx/access.log
```

---

## SSL/TLS Setup

### Let's Encrypt Configuration

SSL certificates are managed by Certbot and stored in:

```
/etc/letsencrypt/live/narro.info/
├── fullchain.pem
├── privkey.pem
├── chain.pem
└── cert.pem
```

### Certificate Auto-Renewal

Certbot automatically renews certificates via systemd timer:

```bash
# Check renewal timer status
sudo systemctl status certbot.timer

# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# List certificates
sudo certbot certificates
```

### Manual Certificate Management

**Renew specific certificate:**

```bash
sudo certbot renew --cert-name narro.info
```

**Revoke and delete certificate:**

```bash
sudo certbot revoke --cert-path /etc/letsencrypt/live/narro.info/cert.pem
sudo certbot delete --cert-name narro.info
```

---

## Service Management

### Docker Compose Commands

**Start services:**

```bash
cd /home/narro/deployment

# Frontend
docker compose -f docker-compose.web.yml up -d

# Backend
docker compose -f docker-compose.api.yml up -d
```

**Stop services:**

```bash
docker compose -f docker-compose.web.yml down
docker compose -f docker-compose.api.yml down
```

**Restart specific service:**

```bash
docker compose -f docker-compose.web.yml restart narro-web
docker compose -f docker-compose.api.yml restart narro-api
```

**View logs:**

```bash
# All logs
docker compose logs -f

# Specific service
docker compose logs -f narro-api
docker compose logs -f narro-web

# Last 100 lines
docker compose logs --tail=100 narro-api
```

**Update containers:**

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate
```

### Scraper Cron Job

The scraper runs on-demand via cron, not as a long-running container. Cron jobs are
automatically configured by `scripts/deploy.sh` based on the `SCRAPER_FREQUENCY_MODE`
setting (defaults to `production`).

**Log files:** Each platform writes to its own log file for easier debugging:

```
logs/cron-scrape-twitter.log
logs/cron-scrape-linkedin.log
logs/cron-scrape-instagram.log
logs/cron-scrape-youtube.log
logs/cron-scrape-tiktok.log
logs/cron-scrape-facebook.log
logs/cron-scrape-reddit.log
logs/cron-frequency.log          # frequency updates (all platforms)
```

**Tail a specific platform's logs:**

```bash
tail -f /home/narro/deployment/logs/cron-scrape-twitter.log
```

**Manual scraper execution:**

```bash
cd /home/narro/deployment
docker compose -f docker-compose.scraper.yml run --rm narro-scraper-api python3 run.py scrape --platform instagram --limit 50
```

---

## Health Checks

### Automated Health Checks

Docker Compose includes health checks for all services:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

**Check health status:**

```bash
docker compose ps

# Output shows health status:
# NAME         STATUS                    PORTS
# narro-api    Up 5 minutes (healthy)    3000/tcp
# narro-web    Up 5 minutes (healthy)    3001/tcp
```

### Manual Health Checks

**API health:**

```bash
curl http://localhost:3000/api/health

# Expected response:
# {"status":"ok"}
```

**Web health:**

```bash
curl -I http://localhost:3001/

# Expected: HTTP 200 OK
```

**Database connectivity:**

```bash
docker compose exec narro-api psql $DATABASE_URL -c "SELECT 1;"
```

---

## Troubleshooting

### Services Won't Start

**Check logs:**

```bash
docker compose logs narro-api
docker compose logs narro-web
```

**Common issues:**

1. **Missing environment variables:**
   ```bash
   # Verify .env.production exists and has all required vars
   cat .env.production | grep DATABASE_URL
   ```

2. **Port conflicts:**
   ```bash
   sudo netstat -tlnp | grep -E '3000|3001'
   ```

3. **Docker daemon issues:**
   ```bash
   sudo systemctl status docker
   sudo systemctl restart docker
   ```

### Frontend Can't Reach Backend

**Verify DNS resolution:**

```bash
# From frontend server
nslookup api.narro.info
curl -v https://api.narro.info/api/health
```

**Check firewall:**

```bash
# On backend server, verify port 443 is open
sudo ufw status
```

**Check logs:**

```bash
# Frontend logs show API connection errors
docker compose logs narro-web | grep -i "error\|failed"
```

### SSL Certificate Issues

**Check certificate status:**

```bash
sudo certbot certificates

# Output shows expiry dates and domains
```

**Renewal failures:**

```bash
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Common issues:
# - Port 80 blocked (Certbot needs HTTP for challenges)
# - DNS not resolving
# - Rate limiting (5 certs per domain per week)
```

### Database Connection Errors

**Verify DATABASE_URL:**

```bash
docker compose exec narro-api env | grep DATABASE_URL
```

**Test connection:**

```bash
psql $DATABASE_URL -c "SELECT version();"
```

**Check Supabase:**
- Verify IP allowlist in Supabase dashboard
- Check database is running
- Verify connection pooling limits

---

## Security

### Environment Files

```bash
# Ensure proper permissions
chmod 600 /home/narro/deployment/.env.production

# Never commit to git
# .env.production is in .gitignore
```

### Firewall Configuration

**Frontend server:**

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

**Backend server:**

```bash
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP (for Let's Encrypt)
sudo ufw allow 443/tcp    # HTTPS
# Optionally restrict 443 to frontend server IP:
# sudo ufw allow from <frontend-ip> to any port 443 proto tcp
sudo ufw enable
```

### Regular Maintenance

- **Rotate secrets** every 90 days
- **Update Docker images** monthly
- **Review logs** for suspicious activity
- **Monitor disk space** (Docker images accumulate)
- **Update system packages** regularly

---

## Backup & Monitoring

### Database Backups

Database is hosted on Supabase, which provides:
- Automatic daily backups (retained 7 days on free tier, 30+ days on paid)
- Point-in-time recovery (paid tiers)
- Manual backups via Supabase dashboard

### Configuration Backups

**Backup critical files:**

```bash
# On each server
cd /home/narro
tar -czf narro-config-backup-$(date +%Y%m%d).tar.gz \
    deployment/.env.production \
    deployment/docker-compose*.yml

# Store securely off-server
scp narro-config-backup-*.tar.gz user@backup-server:/backups/
```

### S3 Storage

Thumbnails and avatars are stored in S3-compatible storage:
- Configure bucket versioning for recovery
- Set lifecycle policies to archive old objects
- Enable bucket access logging

### Monitoring

**Recommended tools:**

- **Uptime:** UptimeRobot, Pingdom
- **Error tracking:** Sentry (already integrated)
- **Logs:** Papertrail, Logtail
- **Resource monitoring:** Vultr dashboard, Netdata

**Manual monitoring:**

```bash
# Disk space
df -h

# Docker resource usage
docker stats

# Container status
docker compose ps

# System resources
htop
```

---

## Related Documentation

- [CI/CD Guide](CICD.md) - Automated deployment workflows
- [Provisioning Scripts](../../deployment/scripts/README.md) - Server setup scripts
- [Security Checklist](../.claude/quick-security-checklist.md) - Pre-deployment security verification

---

## Quick Reference

### Deployment Checklist

- [ ] Provision servers with provision-debian.sh
- [ ] Configure .env.production on each server
- [ ] Set proper file permissions (chmod 600)
- [ ] Configure DNS records
- [ ] Obtain SSL certificates with Certbot
- [ ] Deploy docker-compose files
- [ ] Start containers
- [ ] Verify health checks pass
- [ ] Test frontend → backend connectivity
- [ ] Configure scraper cron job
- [ ] Set up monitoring

### Emergency Contacts

- **Vultr Support:** support.vultr.com
- **Supabase Support:** supabase.com/dashboard (support section)
- **Let's Encrypt:** community.letsencrypt.org

### Useful Commands

```bash
# Service status
docker compose ps

# Tail logs
docker compose logs -f

# Restart service
docker compose restart narro-api

# Update containers
docker compose pull && docker compose up -d --force-recreate

# Check Nginx
sudo nginx -t && sudo systemctl reload nginx

# SSL status
sudo certbot certificates
```

---

**Status:** This guide consolidates all deployment documentation as of February 6, 2026. For the latest updates, check git history.
