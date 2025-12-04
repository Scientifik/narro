# Narro Deployment Guide

This guide covers the complete setup and deployment process for Narro production deployment on Vultr.

> **Note:** Deployment configuration files are located in the `deployment/` directory. This guide explains how to use them.

## Directory Structure

```
deployment/
├── docker-compose.yml              # Single-server setup (API + Web)
├── docker-compose.api.yml          # API only (multi-server)
├── docker-compose.web.yml          # Web only (multi-server)
├── docker-compose.scraper.yml      # Scraper only (for cron)
├── .env.production                 # Production secrets (NOT in git, create manually)
├── nginx/
│   ├── nginx.conf                  # Single-server Nginx config
│   ├── nginx.lb.conf               # Load balancer config (multi-server)
└── scripts/                        # Deployment scripts (copied from .github/deployment-scripts/)
    ├── deploy.sh
    ├── health-check.sh
    └── cron-scraper.sh
```

## Prerequisites

1. **Vultr instance running** (Ubuntu 22.04 LTS recommended)
2. **Docker & Docker Compose installed**
3. **Nginx installed** (for reverse proxy)
4. **Domain configured** (narro.info) pointing to Vultr instance IP
5. **GitHub repository** with deployment scripts

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
git clone https://github.com/Scientifik/narro.git .
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
cp /home/narro/app/.github/deployment-scripts/*.sh /home/narro/deployment/scripts/
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

## Deployment

### Manual Deployment

```bash
cd /home/narro/deployment
bash scripts/deploy.sh
```

### Automated Deployment (GitHub Actions)

Deployment is automatically triggered on every push to `main` branch via GitHub Actions.

**Required GitHub Secrets:**
- `VULTR_HOST` - IP address or hostname of Vultr instance
- `VULTR_USER` - SSH username (usually `root`)
- `VULTR_SSH_KEY` - Private SSH key for authentication
- `VULTR_DEPLOY_PATH` - Path on instance (e.g., `/home/narro`)

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




