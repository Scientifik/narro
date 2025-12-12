# CI/CD Workflows Setup Checklist

## Pre-Deployment Configuration

### 1. Verify Workflow Files Exist

- [ ] `backend/.gitea/workflows/build-and-deploy.yml` exists
- [ ] `web/.gitea/workflows/build-and-deploy.yml` exists
- [ ] `scraper/.gitea/workflows/build-and-deploy.yml` exists

### 2. Configure Gitea Secrets (Backend Repo)

In Gitea: `backend` repo → Settings → Secrets and Variables → Actions

- [ ] `REGISTRY_URL` - e.g., `ord.vultrcr.com/narro`
- [ ] `REGISTRY_USER` - Your registry username
- [ ] `REGISTRY_PASSWORD` - Your registry password
- [ ] `VULTR_HOST` - Server IP or hostname
- [ ] `VULTR_USER` - SSH username (usually `narro`)
- [ ] `VULTR_SSH_KEY` - Private SSH key (full content)
- [ ] `VULTR_DEPLOY_PATH` - e.g., `/home/narro/deployment`

### 3. Configure Gitea Secrets (Web Repo)

In Gitea: `web` repo → Settings → Secrets and Variables → Actions

- [ ] All secrets from step 2 (REGISTRY_* and VULTR_*)
- [ ] `NEXT_PUBLIC_API_URL` - e.g., `https://api.yourdomain.com`
- [ ] `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anon key
- [ ] `NEXT_PUBLIC_SENTRY_DSN` - (Optional) Sentry DSN
- [ ] `SENTRY_ORG` - (Optional) Sentry organization
- [ ] `SENTRY_PROJECT` - (Optional) Sentry project
- [ ] `SENTRY_AUTH_TOKEN` - (Optional) Sentry auth token

### 4. Configure Gitea Secrets (Scraper Repo)

In Gitea: `scraper` repo → Settings → Secrets and Variables → Actions

- [ ] All secrets from step 2 (REGISTRY_* and VULTR_*)

### 5. Verify Dockerfiles

- [ ] `backend/Dockerfile` exists and builds correctly
- [ ] `web/Dockerfile` exists and builds correctly
- [ ] `scraper/Dockerfile` exists and builds correctly

Test locally:
```bash
cd backend && docker build -t test-api .
cd web && docker build -t test-web .
cd scraper && docker build -t test-scraper .
```

### 6. Verify Container Registry Access

Test registry credentials:
```bash
docker login ord.vultrcr.com -u USERNAME -p PASSWORD
docker pull ord.vultrcr.com/narro/narro-api:latest
```

### 7. Verify SSH Access to Vultr Server

Test SSH connection:
```bash
ssh -i /path/to/private/key narro@your.server.ip "echo 'SSH works!'"
```

### 8. Verify docker-compose.yml on Server

On Vultr server:
```bash
cd /home/narro/deployment
# Check file exists
ls -l docker-compose.yml

# Validate syntax
docker-compose config

# Check required services are defined
grep "narro-api\|narro-web\|narro-scraper" docker-compose.yml
```

### 9. Verify Environment File

On Vultr server:
```bash
cd /home/narro/deployment

# Check file exists and permissions
ls -l .env.production
# Should be readable (600 or 644 permissions)

# Check required variables are set
grep "REGISTRY_URL\|DATABASE_URL" .env.production
```

### 10. Test Workflow Manually (Recommended)

#### Test Backend Workflow:
1. Make a small change to backend (e.g., update README or comment)
2. Commit and push to `main` branch
3. Go to Gitea → backend repo → Actions
4. Watch the workflow execute
5. Expected result:
   - Image builds and pushes to registry
   - Server pulls new image
   - `narro-api` container starts/restarts
   - Health check passes

#### Monitor Deployment:
```bash
# SSH into server
ssh narro@your.server.ip
cd /home/narro/deployment

# Watch container status
watch docker compose ps

# Check logs
docker compose logs -f narro-api
```

#### Test Web Workflow:
Repeat steps 1-5 with web repo changes

#### Test Scraper Workflow:
Repeat steps 1-5 with scraper repo changes

## Post-Deployment Verification

### Health Checks

```bash
# SSH into server
ssh narro@your.server.ip
cd /home/narro/deployment

# Check all services are healthy
docker compose ps
# Should show "healthy" status for narro-api and narro-web

# Check API is responding
curl http://localhost:3000/api/health

# Check web is responding
curl -I http://localhost:3001/

# Check nginx reverse proxy (if configured)
curl https://yourdomain.com/api/health
curl https://yourdomain.com/
```

### Log Review

```bash
# Check for errors in API logs
docker compose logs --tail=50 narro-api | grep -i error

# Check for errors in web logs
docker compose logs --tail=50 narro-web | grep -i error

# Check for errors in scraper logs
docker compose logs --tail=50 narro-scraper | grep -i error
```

### Database Connectivity

```bash
# Check API can connect to database
docker compose logs narro-api | grep -i "connected\|database"

# Or execute test query
docker compose exec narro-api psql $DATABASE_URL -c "SELECT 1;"
```

## Troubleshooting

### Workflow Fails to Run

- [ ] Check Gitea Actions page for error details
- [ ] Verify workflow file syntax (check YAML formatting)
- [ ] Ensure all required secrets are configured
- [ ] Check if service has `.gitea/workflows/` directory

### Build Fails

- [ ] Check Docker build logs in Gitea Actions
- [ ] Verify Dockerfile is correct
- [ ] Test build locally: `docker build -t test .`
- [ ] Check dependencies are available

### Push to Registry Fails

- [ ] Verify `REGISTRY_URL` is correct
- [ ] Verify `REGISTRY_USER` and `REGISTRY_PASSWORD` are correct
- [ ] Test locally: `docker login ord.vultrcr.com`
- [ ] Check image name matches expected pattern

### Deployment Fails

- [ ] Check SSH key is correct
- [ ] Verify SSH key is added to Vultr user's authorized_keys
- [ ] Check `VULTR_HOST` and `VULTR_USER` are correct
- [ ] Test SSH locally: `ssh -i key narro@host "echo test"`
- [ ] Check deployment directory exists

### Container Fails to Start

- [ ] Check `docker-compose.yml` syntax
- [ ] Verify image exists in registry
- [ ] Check `.env.production` has all required variables
- [ ] Review container logs: `docker compose logs narro-{service}`
- [ ] Check health check configuration

### Web Container Fails While API is Healthy

- [ ] Web waits for healthy API before starting
- [ ] This is normal and expected behavior
- [ ] Check web logs for real errors
- [ ] Verify web container can reach API at configured URL

## Rollback Procedure

### Quick Rollback (to Previous Version)

```bash
ssh narro@your.server.ip
cd /home/narro/deployment

# Get list of available image tags
docker images | grep narro-api

# Roll back to specific tag (previous commit SHA)
export IMAGE_TAG=abc123def456
docker compose pull narro-api
docker compose up -d --force-recreate --no-deps narro-api

# Verify
docker compose ps narro-api
docker compose logs narro-api
```

## Maintenance

### Regular Tasks

- [ ] Monitor Gitea Actions page for failed workflows
- [ ] Check container logs weekly for errors
- [ ] Monitor disk space on Vultr server
- [ ] Update secrets if registry credentials change
- [ ] Archive old docker images to save space

### Cleanup Old Images

```bash
# Remove unused images
docker image prune -a

# Remove dangling layers
docker system prune

# Check disk usage
docker system df
```

## Documentation

- [ ] Share `SEPARATE-WORKFLOWS-GUIDE.md` with team
- [ ] Update team wiki/docs with new workflow info
- [ ] Document any custom deployment procedures
- [ ] Record secrets location and rotation schedule

---

**Last Updated:** December 11, 2025
