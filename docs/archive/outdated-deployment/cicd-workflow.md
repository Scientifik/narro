# CI/CD Workflow Guide

**Status:** CURRENT
**Last Updated:** 2026-01-24

---

## Overview

The Narro project uses **separate CI/CD workflows** for each service repository (backend, web, scraper), each supporting both **staging** and **production** environments with separate deployment triggers. Each repository has its own `.gitea/workflows/build-and-deploy.yml` that runs independently when code is pushed to that repo.

## Architecture

The project uses **3 separate repositories**, each with its own workflow:

- **backend/** - Go API server
- **web/** - Next.js web application
- **scraper/** - Python scraper service

Each repository has its own `.gitea/workflows/build-and-deploy.yml` that runs independently.

## Deployment Flow

```mermaid
graph TD
    A[Push to Backend Repo] --> B1{Backend Branch/Tag?}
    A2[Push to Web Repo] --> B2{Web Branch/Tag?}
    
    B1 -->|staging| C1[Build Backend staging-*]
    B1 -->|main| C2[Build Backend latest]
    B1 -->|v* tag| C3[Build Backend latest]
    
    B2 -->|staging| D1[Build Web staging-*]
    B2 -->|main| D2[Build Web latest]
    B2 -->|v* tag| D3[Build Web latest]
    
    C1 --> E1[Deploy to Staging Server]
    D1 --> E1
    
    C2 --> E2[Deploy to Production Backend]
    C3 --> E2
    
    D2 --> E3[Deploy to Production Frontend]
    D3 --> E3
```

## Workflow Triggers

Each repository (backend, web, scraper) has its own workflow that triggers independently:

### Staging Deployment
- **Trigger:** Push to `staging` branch in any service repo (backend or web)
- **Action:** 
  - Backend: Builds `narro-api:staging-{commit-sha}` and `staging-latest`, deploys to staging server
  - Web: Builds `narro-web:staging-{commit-sha}` and `staging-latest`, deploys to staging server
- **Environment:** Single server hosting both backend and web (uses `docker-compose.staging.yml`)

### Production Deployment
- **Trigger:** Push a tag matching `v*` pattern (e.g., `v1.0.0`) on the `main` branch
- **Action:**
  - Backend: Builds `narro-api:{commit-sha}` and `latest`, deploys to production backend server
  - Web: Builds `narro-web:{commit-sha}` and `latest`, deploys to production frontend server
- **Environment:** Multi-server setup (separate backend and web servers)

**Note:** Only version tags trigger production deployment. Pushes to `main` branch without tags do NOT deploy to production.

## Workflow Variables

These are configured as **CI/CD variables** (not secrets) in Gitea, allowing changes without code modifications:

### Staging Domains
- `STAGING_DOMAIN`: Staging frontend/web domain (e.g., `somerandomdomainforsecurity.narro.info`)
- `STAGING_API`: Staging API/backend domain (e.g., `theapidomainthatslongandrandomforstaging.narro.info`)

### Production Domains
- `PRODUCTION_DOMAIN`: Production frontend/web domain
- `PRODUCTION_API`: Production API/backend domain

### Registry Configuration
- `REGISTRY_URL`: Container registry URL (e.g., `ord.vultrcr.com/narro`)

**Note:** Domains are embedded in Docker images at build time via build args (especially `NEXT_PUBLIC_API_URL` for the web app).

## Required Secrets

These must be configured as **secrets** in Gitea:

### Registry Authentication
- `REGISTRY_USER`: Registry username
- `REGISTRY_PASSWORD`: Registry password

### SSH Access
- `VULTR_SSH_KEY`: SSH private key for production servers
- `VULTR_STAGING_SSH_KEY`: SSH private key for staging server (if different, otherwise uses `VULTR_SSH_KEY`)
- `VULTR_BACKEND_HOST`: Production backend server IP/hostname (backend repo)
- `VULTR_FRONTEND_HOST`: Production frontend server IP/hostname (web repo)
- `VULTR_STAGING_HOST`: Staging server IP/hostname (used by both backend and web repos for staging)
- `VULTR_USER`: SSH username (e.g., `narro`)
- `VULTR_DEPLOY_PATH`: Deployment directory (e.g., `/home/narro/deployment`)

### Application Secrets (for web build)
- `NEXT_PUBLIC_SUPABASE_URL`: Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Supabase anonymous key
- `NEXT_PUBLIC_SENTRY_DSN`: (Optional) Sentry DSN for frontend
- `SENTRY_ORG`: (Optional) Sentry organization
- `SENTRY_PROJECT`: (Optional) Sentry project name
- `SENTRY_AUTH_TOKEN`: (Optional) Sentry auth token for source maps

## Image Tagging Strategy

- **Staging:** `{image-name}:staging-{commit-sha}` and `{image-name}:staging-latest`
- **Production:** `{image-name}:{commit-sha}` and `{image-name}:latest`

## Workflow Structure (Per Repository)

Each repository's workflow follows this pattern:

### Backend Workflow (`backend/.gitea/workflows/build-and-deploy.yml`)

1. **Determine environment** - Detects staging vs production based on branch/tag
2. **Build image** - Builds `narro-api` with appropriate tags:
   - Staging: `staging-{commit-sha}` and `staging-latest`
   - Production: `{commit-sha}` and `latest`
3. **Deploy** - Deploys to appropriate server:
   - Staging: `VULTR_STAGING_HOST` (same server as web)
   - Production: `VULTR_BACKEND_HOST` (separate backend server)

### Web Workflow (`web/.gitea/workflows/build-and-deploy.yml`)

1. **Determine environment** - Detects staging vs production based on branch/tag
2. **Build image** - Builds `narro-web` with appropriate tags and domains:
   - Staging: `staging-{commit-sha}` and `staging-latest`, uses `STAGING_API` for `NEXT_PUBLIC_API_URL`
   - Production: `{commit-sha}` and `latest`, uses `PRODUCTION_API` for `NEXT_PUBLIC_API_URL`
3. **Deploy** - Deploys to appropriate server:
   - Staging: `VULTR_STAGING_HOST` (same server as backend)
   - Production: `VULTR_FRONTEND_HOST` (separate frontend server)

### Scraper Workflow (`scraper/.gitea/workflows/build-and-deploy.yml`)

- Currently only supports production deployments
- Staging support can be added if needed

## Staging Environment Setup

### Server Provisioning

1. Provision a staging server using the provision script:
   ```bash
   sudo DOMAIN=your-staging-domain.narro.info bash provision-debian.sh staging
   ```

2. Get SSL certificate:
   ```bash
   sudo certbot --nginx -d your-staging-domain.narro.info
   ```

3. Configure environment variables:
   - Copy `deployment/scripts/env.staging.example` to `/home/narro/deployment/.env.staging`
   - Fill in all required values
   - Set permissions: `chmod 600 .env.staging`

### Staging Server Architecture

- **Single server** hosting both backend (port 3000) and web (port 3001)
- Nginx proxies both services:
  - Web app on `/`
  - API on `/api/*`
- Uses `docker-compose.staging.yml` for deployment
- Environment file: `.env.staging`

## Production Environment Setup

### Server Provisioning

1. Provision backend server:
   ```bash
   sudo DOMAIN=api.yourdomain.com bash provision-debian.sh backend
   ```

2. Provision frontend server:
   ```bash
   sudo DOMAIN=yourdomain.com bash provision-debian.sh frontend
   ```

3. Get SSL certificates for both servers

4. Configure environment variables on each server

### Production Server Architecture

- **Separate servers** for backend and web
- Backend server runs API on port 3000
- Frontend server runs web app on port 3001 and proxies `/api/*` to backend
- Uses `docker-compose.api.yml` and `docker-compose.web.yml` for deployment
- Environment file: `.env.production`

## Deployment Process

### Deploying to Staging

**For Backend:**
1. Push changes to `staging` branch in backend repo:
   ```bash
   cd backend
   git checkout staging
   git merge main  # or make changes directly
   git push origin staging
   ```

2. Backend workflow automatically:
   - Builds `narro-api:staging-{commit-sha}` and `staging-latest`
   - Deploys to staging server

**For Web:**
1. Push changes to `staging` branch in web repo:
   ```bash
   cd web
   git checkout staging
   git merge main  # or make changes directly
   git push origin staging
   ```

2. Web workflow automatically:
   - Builds `narro-web:staging-{commit-sha}` and `staging-latest` with `STAGING_API` domain
   - Deploys to staging server (same server as backend)

**Note:** Both backend and web deploy to the same staging server, which runs both services using `docker-compose.staging.yml`.

### Deploying to Production

**Option 1: Push to main branch (existing behavior)**
```bash
# In backend repo
cd backend
git checkout main
git push origin main

# In web repo
cd web
git checkout main
git push origin main
```

**Option 2: Push a version tag**
```bash
# In backend repo
cd backend
git checkout main
git tag v1.0.0
git push origin v1.0.0

# In web repo
cd web
git checkout main
git tag v1.0.0
git push origin v1.0.0
```

Both methods trigger production deployment:
- Backend deploys to `VULTR_BACKEND_HOST`
- Web deploys to `VULTR_FRONTEND_HOST`

## Changing Domains

Domains are configured as CI/CD variables in each repository, so they can be changed without code modifications:

1. Go to Gitea: Repository → Settings → Secrets and Variables → Actions → Variables
2. Update the domain variable in the appropriate repo:
   - **Web repo:** Update `STAGING_DOMAIN`, `STAGING_API`, `PRODUCTION_DOMAIN`, `PRODUCTION_API`
   - **Backend repo:** Update `STAGING_API`, `PRODUCTION_API` (if needed)
3. Push to the appropriate branch/tag to trigger a new build
4. The new domain will be embedded in the Docker images (especially `NEXT_PUBLIC_API_URL` for web)

## Troubleshooting

### Staging Deployment Fails

- Check that staging server is provisioned with `provision-debian.sh staging`
- Verify `VULTR_STAGING_HOST` secret is set (or `VULTR_HOST` if using same host)
- Check SSH key has access to staging server
- Verify `.env.staging` file exists on staging server

### Production Deployment Fails

- Verify both backend and frontend servers are provisioned
- Check that `VULTR_HOST` secret points to correct server
- Verify SSH key has access to production servers
- Check that production servers have correct docker-compose files

### Build Succeeds But Deploy Fails

- Check SSH connectivity: `ssh narro@your-server-ip`
- Verify deployment directory exists: `/home/narro/deployment`
- Check docker-compose files are present on server
- Review workflow logs for specific error messages

### Domain Not Updating

- Verify domain variable is set in Gitea (Repository → Settings → Variables)
- Check that workflow is using the variable: `${{ vars.STAGING_DOMAIN }}`
- Rebuild images after changing variables (push to branch/tag)

## Rollback Procedures

### Rollback Staging

1. Find previous commit SHA from staging branch history
2. Manually deploy previous image:
   ```bash
   ssh narro@staging-server
   cd /home/narro/deployment
   export IMAGE_TAG=staging-{previous-commit-sha}
   docker compose -f docker-compose.staging.yml pull
   docker compose -f docker-compose.staging.yml up -d --force-recreate
   ```

### Rollback Production

1. Find previous tag from git history
2. Re-push the previous tag:
   ```bash
   git tag v1.0.0-previous
   git push origin v1.0.0-previous
   ```
   This will trigger a new deployment with the previous code

## Best Practices

1. **Always test in staging first** - Push to `staging` branch before tagging for production
2. **Use semantic versioning** - Tags should follow `v{major}.{minor}.{patch}` format
3. **Monitor deployments** - Check workflow logs and server logs after deployment
4. **Keep secrets secure** - Never commit secrets to git, always use Gitea secrets
5. **Update variables carefully** - Domain changes require rebuilding images
6. **Document changes** - Update this guide when workflow changes

## Repository Structure

```
narro/ (main monorepo - reference only, no CI/CD)
├── backend/ (separate repo)
│   └── .gitea/workflows/build-and-deploy.yml
├── web/ (separate repo)
│   └── .gitea/workflows/build-and-deploy.yml
└── scraper/ (separate repo)
    └── .gitea/workflows/build-and-deploy.yml
```

Each repository is independent and has its own:
- Git history
- CI/CD workflow
- Secrets and variables configuration
- Deployment targets

## Related Documentation

- [Deployment Guide](deployment-guide.md) - Complete deployment setup instructions
- [Separate Workflows Guide](separate-workflows-guide.md) - Additional details on separate repo workflows
- [Provision Script README](../deployment/scripts/README.md) - Server provisioning instructions


