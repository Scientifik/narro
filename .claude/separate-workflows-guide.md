# Separate Workflows Deployment Guide

> **Date Updated:** December 11, 2025  
> **Note:** This document describes the legacy separate-repo approach. For the current monorepo CI/CD workflow with staging and production environments, see [CI/CD Workflow Guide](cicd-workflow.md).

## Overview

The Narro project **previously** used **separate independent CI/CD workflows** for each service (backend, web, scraper) when each service was in its own git repository. 

**Current Setup:** The project now uses a unified CI/CD pipeline in the main repository (`.gitea/workflows/build-and-deploy.yml`) that supports staging and production environments. See [CI/CD Workflow Guide](cicd-workflow.md) for current documentation.

## Architecture

### Previous Setup (Monorepo)
```
narro/ (single repo)
├── backend/
├── web/
└── scraper/
└── .gitea/workflows/build-and-deploy.yml  ← Single workflow for all services
```

Push to `main` → Builds & deploys ALL services together

### Current Setup (Multi-Repo with Separate Workflows)
```
narro-backend/ (separate repo)
├── .gitea/workflows/
│   └── build-and-deploy.yml  ← Backend only

narro-web/ (separate repo)
├── .gitea/workflows/
│   └── build-and-deploy.yml  ← Web only

narro-scraper/ (separate repo)
├── .gitea/workflows/
│   └── build-and-deploy.yml  ← Scraper only
```

Push to `main` in any repo → Builds & deploys ONLY that service

## Workflow Breakdown

### Backend Workflow (`backend/.gitea/workflows/build-and-deploy.yml`)

**Trigger:** Push to `main` branch in backend repo

**Steps:**
1. Checkout code
2. Setup Docker Buildx for cross-platform builds
3. Get commit SHA (for versioning)
4. Login to container registry
5. Build Docker image for `narro-api`
   - Tags: `latest` and `{commit-sha}`
   - Context: root of backend repo
   - Platform: linux/amd64
   - Uses layer caching for faster rebuilds
6. SSH into Vultr server
7. Pull latest `narro-api` image from registry
8. Start/restart backend container via docker-compose
9. Verify deployment (check logs and health status)

**Environment Variables Used:**
- `IMAGE_NAME`: Always `narro-api`
- `REGISTRY_URL`: From secrets

**Required Secrets:**
- `REGISTRY_URL`: Container registry URL (e.g., `ord.vultrcr.com/narro`)
- `REGISTRY_USER`: Registry username
- `REGISTRY_PASSWORD`: Registry password
- `VULTR_HOST`: Vultr server IP or hostname
- `VULTR_USER`: SSH username (e.g., `narro`)
- `VULTR_SSH_KEY`: Private SSH key
- `VULTR_DEPLOY_PATH`: Deployment directory (e.g., `/home/narro/deployment`)

### Web Workflow (`web/.gitea/workflows/build-and-deploy.yml`)

**Trigger:** Push to `main` branch in web repo

**Steps:**
1. Checkout code
2. Setup Docker Buildx
3. Get commit SHA
4. Login to container registry
5. Build Docker image for `narro-web`
   - Tags: `latest` and `{commit-sha}`
   - Context: root of web repo
   - Platform: linux/amd64
   - **Build args from secrets:**
     - `NEXT_PUBLIC_API_URL`
     - `NEXT_PUBLIC_SUPABASE_URL`
     - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
     - `NEXT_PUBLIC_SENTRY_DSN`
     - `SENTRY_ORG`
     - `SENTRY_PROJECT`
     - `SENTRY_AUTH_TOKEN`
6. SSH into Vultr server
7. Pull latest `narro-web` image
8. Start/restart web container (waits for healthy API via docker-compose depends_on)
9. Verify deployment

**Required Secrets:**
- `REGISTRY_URL`, `REGISTRY_USER`, `REGISTRY_PASSWORD`
- `VULTR_HOST`, `VULTR_USER`, `VULTR_SSH_KEY`, `VULTR_DEPLOY_PATH`

**Optional Secrets (for build):**
- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_SENTRY_DSN`
- `SENTRY_ORG`
- `SENTRY_PROJECT`
- `SENTRY_AUTH_TOKEN`

### Scraper Workflow (`scraper/.gitea/workflows/build-and-deploy.yml`)

**Trigger:** Push to `main` branch in scraper repo

**Steps:**
1. Checkout code
2. Setup Docker Buildx
3. Get commit SHA
4. Login to container registry
5. Build Docker image for `narro-scraper`
   - Tags: `latest` and `{commit-sha}`
   - Context: root of scraper repo
   - Platform: linux/amd64
6. SSH into Vultr server
7. Pull latest `narro-scraper` image (doesn't auto-start, used by cron jobs)
8. Confirm update

**Required Secrets:** Same as backend/web

**Note:** Scraper doesn't auto-start in containers. It's pulled for use by cron jobs or manual runs.

## Deployment Process

### For Each Service Push

```
Push to main in backend/web/scraper repo
    ↓
Gitea Actions triggered
    ↓
Build Docker image
    ↓
Push to registry with tags (latest + commit-sha)
    ↓
SSH into Vultr server
    ↓
docker compose pull narro-{service}
    ↓
docker compose up -d --force-recreate --no-deps narro-{service}
    ↓
Verify deployment (health checks, logs)
```

### Zero-Downtime Updates

- `--force-recreate` ensures new container with new image
- `--no-deps` prevents restarting dependent services unnecessarily
- Docker-compose waits for health checks before marking as "healthy"
- Web service waits for healthy API before starting (via depends_on)

## Secrets Setup in Gitea

You need to configure these secrets in **each repository** (backend, web, scraper):

### In Gitea Repository Settings:

1. Go to `Repository` → `Settings` → `Secrets and Variables` → `Actions`
2. Add these secrets:

```
REGISTRY_URL          = ord.vultrcr.com/narro
REGISTRY_USER         = your_registry_user
REGISTRY_PASSWORD     = your_registry_password
VULTR_HOST            = your.server.ip.or.hostname
VULTR_USER            = narro  (or your SSH user)
VULTR_SSH_KEY         = (paste your private SSH key)
VULTR_DEPLOY_PATH     = /home/narro/deployment
```

### For Web Service (Additional):

```
NEXT_PUBLIC_API_URL         = https://api.yourdomain.com
NEXT_PUBLIC_SUPABASE_URL    = your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY = your_anon_key
NEXT_PUBLIC_SENTRY_DSN      = (optional)
SENTRY_ORG                  = (optional)
SENTRY_PROJECT              = (optional)
SENTRY_AUTH_TOKEN           = (optional)
```

## Important Notes

### Independent Deployments
- Backend can be deployed without redeploying web
- Web can be deployed without backend changes
- Faster CI/CD pipeline (only changed service builds)

### Potential Risks
- **API/Web Version Mismatch:** Ensure backend and web are compatible
  - If you make breaking API changes, deploy backend first, then web
  - If you add new features to API, deploy backend first
- **Rollback:** Use commit SHA tag to rollback individual services

### Docker-Compose Configuration
The deployment relies on `docker-compose.yml` in `/home/narro/deployment/`:
- Must have `narro-api`, `narro-web`, `narro-scraper` services defined
- Services must use `image: ${REGISTRY_URL}/narro-{service}:${IMAGE_TAG:-latest}`
- Healthchecks should be properly configured

## Rollback Procedure

### Rollback Specific Service
```bash
# SSH into server
ssh narro@your.server.ip

cd /home/narro/deployment

# Set image tag to previous commit SHA
export IMAGE_TAG=abc123def456  # Previous commit SHA

# Pull and deploy previous version
docker compose pull narro-api  # or narro-web or narro-scraper
docker compose up -d --force-recreate --no-deps narro-api
```

### Check Available Image Tags
```bash
# Check what's in your registry
# Backend
docker images | grep narro-api

# Web
docker images | grep narro-web

# Scraper
docker images | grep narro-scraper
```

## Monitoring Deployments

### Check Deployment Status
```bash
ssh narro@your.server.ip
cd /home/narro/deployment

# Check all services
docker compose ps

# Check specific service logs
docker compose logs -f narro-api    # Backend
docker compose logs -f narro-web    # Web
docker compose logs -f narro-scraper # Scraper

# Check health status
docker compose ps | grep healthy
```

### Common Issues

#### Web Container Fails to Start
- Check if API is healthy: `docker compose logs narro-api`
- Web waits for API to be healthy before starting
- Solution: Fix API, redeploy, then web should auto-restart

#### Docker Registry Authentication
- Ensure secrets are correctly set in each repository
- Registry username/password must have pull access
- Test locally: `docker login ord.vultrcr.com`

#### SSH Connection Failures
- Verify SSH key is added to Vultr user's `~/.ssh/authorized_keys`
- Check SSH key format (should be PEM)
- Test SSH locally: `ssh -i private_key narro@server.ip`

## Migration from Old Workflow

If you had the old unified workflow in the main `narro/` repo:

1. **Keep the main repo:** Optionally keep it as a reference or documentation repo
2. **Remove old workflow:** Delete `.gitea/workflows/build-and-deploy.yml` from main repo
3. **Update each sub-repo:** Ensure they have the new workflow files (already created)
4. **Configure secrets:** Add secrets to each service repository in Gitea
5. **Test deployments:** Push to main in one service, verify deployment works
6. **Update documentation:** Update any internal docs to reference new workflows

## Advantages of Separate Workflows

✅ **Faster builds:** Only build changed service
✅ **Independent deployments:** Deploy backend without touching web
✅ **Separate rollbacks:** Rollback individual services by commit SHA
✅ **Better scaling:** Each service can have different build configs
✅ **Cleaner repos:** Each repo only contains what it needs

## Disadvantages / Considerations

⚠️ **Version mismatch:** Need to coordinate API/web versions manually
⚠️ **More complex:** Multiple workflows to manage
⚠️ **Multiple repos:** Must push/manage changes across multiple repos

## File Locations

```
backend/.gitea/workflows/build-and-deploy.yml
web/.gitea/workflows/build-and-deploy.yml
scraper/.gitea/workflows/build-and-deploy.yml

deployment/docker-compose.yml          # Main compose file
deployment/scripts/deploy.sh           # (Optional) Shared deployment script
deployment/.env.production             # Secrets
```

## Next Steps

1. Create/update secrets in Gitea for backend, web, and scraper repos
2. Test by pushing to `main` in one service (e.g., backend)
3. Monitor the workflow execution in Gitea Actions
4. Verify the service deployed successfully on Vultr
5. Repeat for web and scraper
6. Update any team documentation about the new workflow

---

**Questions or Issues?** Check the Gitea Actions logs for detailed error messages.
