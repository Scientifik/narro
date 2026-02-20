# Tag-Based Deployment Guide

**Status:** CURRENT
**Last Updated:** 2026-01-31

---

## Overview

Narro uses **git tags** for production deployments. When you push a tag (e.g., `v1.0.0`), the CI/CD pipeline automatically builds, tests, and deploys that specific version to production.

## Deployment Methods

| Method | Trigger | Use Case | Workflow File |
|--------|---------|----------|---------------|
| **Tag-based** | `git push --tags` | Production releases | `.github/workflows/deploy-tag.yml` |
| **Continuous** | `git push origin main` | Development/staging | `.github/workflows/deploy.yml` |

---

## Creating a Production Release

### 1. Prepare Your Release

Ensure all changes are committed and pushed to `main`:

```bash
git add .
git commit -m "Prepare release v1.0.0"
git push origin main
```

### 2. Create and Push a Tag

Create a new tag following semantic versioning (`vMAJOR.MINOR.PATCH`):

```bash
# Create tag
git tag v1.0.0

# Push tag to trigger deployment
git push origin v1.0.0
```

### 3. Monitor Deployment

Watch the deployment progress on GitHub Actions:
- Go to: https://github.com/your-org/narro/actions
- Click on the "Deploy Tagged Release" workflow
- Monitor the build and deployment stages

### 4. Verify Production

Once deployment completes, verify the services:

```bash
# Check API health
curl https://alpha.narro.info/api/health

# Check Web health
curl https://alpha.narro.info/

# SSH to server and verify containers
ssh narro@your-server
docker ps --filter "name=narro-"
```

---

## What Happens During Tag Deployment

### Build & Push Stage

1. **Extracts tag name** (e.g., `v1.0.0`)
2. **Builds Docker images** for:
   - Backend API (`narro-api`)
   - Web app (`narro-web`)
   - Scraper service (`narro-scraper`)
3. **Pushes to Vultr Container Registry** with tags:
   - `ord.vultrcr.com/narro/narro-api:v1.0.0`
   - `ord.vultrcr.com/narro/narro-api:latest`
   - (Same for web and scraper)

### Deploy Stage

1. **SSH to production server**
2. **Login to container registry**
3. **Pull images** with the specific tag
4. **Update `.env.production`** to set `IMAGE_TAG=v1.0.0`
5. **Deploy API** using `docker-compose -f docker-compose.api.yml`
6. **Deploy Web** using `docker-compose -f docker-compose.web.yml`
7. **Run health checks** to verify deployment

---

## Semantic Versioning

Follow [semantic versioning](https://semver.org/) for tags:

| Version | Format | Example | When to Use |
|---------|--------|---------|-------------|
| Major | `vX.0.0` | `v2.0.0` | Breaking changes, major features |
| Minor | `vX.Y.0` | `v1.1.0` | New features, backwards compatible |
| Patch | `vX.Y.Z` | `v1.0.1` | Bug fixes, minor changes |

### Examples

```bash
# Initial release
git tag v1.0.0

# Bug fix
git tag v1.0.1

# New feature
git tag v1.1.0

# Breaking change
git tag v2.0.0
```

---

## Rollback to Previous Version

If a deployment fails or has issues, you can rollback:

### Option 1: SSH and Manually Rollback

```bash
ssh narro@your-server
cd /home/narro/deployment

# Update IMAGE_TAG to previous version
sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=v1.0.0/' .env.production

# Redeploy
IMAGE_TAG=v1.0.0 docker-compose -f docker-compose.api.yml up -d
IMAGE_TAG=v1.0.0 docker-compose -f docker-compose.web.yml up -d
```

### Option 2: Create a New Tag

```bash
# Create a new tag pointing to the old commit
git tag v1.0.2 <old-commit-sha>
git push origin v1.0.2
```

This triggers a fresh deployment of the old code with a new tag.

---

## GitHub Secrets Required

Ensure these secrets are configured in GitHub:
- `REGISTRY_USER` - Vultr registry username
- `REGISTRY_PASSWORD` - Vultr registry password
- `VULTR_SSH_KEY` - SSH private key for server access
- `VULTR_HOST` - Server hostname/IP
- `VULTR_USER` - SSH username (usually `narro`)
- `NEXT_PUBLIC_API_URL` - API URL for frontend
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anonymous key

---

## Troubleshooting

### Tag deployment not triggering

**Check:**
- Tag matches pattern `v*` (must start with `v`)
- Tag was pushed: `git push origin <tagname>`
- GitHub Actions workflow file exists: `.github/workflows/deploy-tag.yml`

### Build fails

**Check:**
- Dockerfiles are valid in `backend/`, `web/`, `scraper/`
- All build-time environment variables are set in GitHub secrets
- Registry credentials are correct

### Deployment fails health check

**Check:**
- Services are running: `docker ps`
- Check logs: `docker-compose logs narro-api`, `docker-compose logs narro-web`
- Database connectivity
- Environment variables in `.env.production`

### Wrong version running

**Check:**
```bash
# On server
cat /home/narro/deployment/.env.production | grep IMAGE_TAG

# Should show: IMAGE_TAG=v1.0.0 (or your expected version)

# Check running containers
docker ps --format "table {{.Names}}\t{{.Image}}"
```

---

## Best Practices

1. **Always test on staging first** - Use the continuous deployment workflow to test on staging
2. **Tag after merging** - Only tag commits that are on `main` branch
3. **Use descriptive commit messages** - Makes it easier to track what's in each release
4. **Keep changelog** - Update `CHANGELOG.md` before tagging
5. **Verify before tagging** - Ensure all tests pass on `main` before creating release tag
6. **One tag per release** - Don't reuse or move tags
7. **Document breaking changes** - Clearly note breaking changes in tag messages

---

## Tag Naming Convention

```bash
# Good ✅
v1.0.0
v1.2.3
v2.0.0-beta.1

# Bad ❌
1.0.0           # Missing 'v' prefix
release-1.0.0   # Non-standard format
v1.0            # Missing patch version
```

---

## Advanced: Pre-release Tags

For beta/RC releases, use semantic versioning pre-release format:

```bash
# Beta release
git tag v2.0.0-beta.1
git push origin v2.0.0-beta.1

# Release candidate
git tag v2.0.0-rc.1
git push origin v2.0.0-rc.1

# Stable release
git tag v2.0.0
git push origin v2.0.0
```

The workflow will still trigger, but you can modify it to deploy to a different environment based on tag format.

---

## Continuous Deployment vs Tag Deployment

| Feature | Continuous (Main Branch) | Tag-based (Releases) |
|---------|--------------------------|----------------------|
| Trigger | Every push to `main` | Pushing a git tag |
| Purpose | Staging/development | Production releases |
| Image Tags | `latest` or commit SHA | Semantic version (e.g., `v1.0.0`) |
| Rollback | Manual or git revert | Redeploy previous tag |
| Control | Automatic | Manual/intentional |

---

## Example Release Workflow

```bash
# 1. Develop features on branches
git checkout -b feature/new-feed-filters
# ... make changes ...
git commit -m "Add new feed filtering options"
git push origin feature/new-feed-filters

# 2. Create PR and merge to main
# (via GitHub UI)

# 3. Pull latest main
git checkout main
git pull origin main

# 4. Update version in package.json/version files if needed
# ... edit version files ...
git commit -m "Bump version to 1.1.0"
git push origin main

# 5. Create and push release tag
git tag v1.1.0 -m "Release v1.1.0: Add feed filtering"
git push origin v1.1.0

# 6. Monitor deployment in GitHub Actions
# 7. Verify production: https://alpha.narro.info
```

---

## Questions?

- Check workflow logs: GitHub Actions → Deploy Tagged Release
- Check deployment scripts: `.github/workflows/deploy-tag.yml`
- Check server logs: `ssh narro@server` → `docker-compose logs`
