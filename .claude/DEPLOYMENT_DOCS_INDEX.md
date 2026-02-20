# Deployment Documentation Index

**Status:** ✅ CURRENT
**Last Updated:** 2026-02-06

---

## Quick Navigation

Narro's deployment documentation has been consolidated into a clean structure. Use this index to find what you need:

### Primary Documentation (Consolidated)

| Document | Location | Purpose |
|----------|----------|---------|
| **Deployment Guide** | `docs/deployment/DEPLOYMENT.md` | Comprehensive deployment setup (architecture, provisioning, Nginx, SSL/TLS) |
| **CI/CD Guide** | `docs/deployment/CICD.md` | Complete CI/CD workflow documentation (Gitea Actions, staging/production, tag-based releases) |
| **Deployment Scripts** | `deployment/scripts/README.md` | Server provisioning and deployment script reference |

### Component-Specific Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| **Feeds Setup** | `deployment/FEEDS_SETUP.md` | Feed configuration for deployment |
| **Registry Retention** | `deployment/scripts/RETENTION_POLICY.md` | Container registry cleanup policy |
| **Vultr Registry Browser** | `deployment/scripts/VULTR_BROWSER_GUIDE.md` | Browsing Vultr container registry |

### Security Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| **Security Checklist** | `.claude/quick-security-checklist.md` | Pre-deployment security verification |
| **Security Dependencies** | `.claude/security-dependencies.md` | Tracking security updates and patches |

---

## Recommended Reading Order

### First Time Setup
1. Read `docs/deployment/DEPLOYMENT.md` for comprehensive deployment setup
2. Review `docs/deployment/CICD.md` for CI/CD workflow configuration
3. Use `deployment/scripts/README.md` for server provisioning scripts

### Routine Deployments
1. Follow tag-based release process in `docs/deployment/CICD.md`
2. Reference multi-repo coordination sections in `docs/deployment/CICD.md`

### Troubleshooting
1. Check `docs/deployment/DEPLOYMENT.md` for common issues and solutions
2. Review `deployment/scripts/README.md` for script usage and debugging
3. Verify security with `.claude/quick-security-checklist.md`

---

## Documentation Consolidation Status

**Status:** ✅ COMPLETED (2026-02-06)

The deployment documentation has been fully consolidated:

- **Created** `docs/deployment/DEPLOYMENT.md` - Merged deployment-guide.md, deployment-summary.md, nginx-setup.md
- **Created** `docs/deployment/CICD.md` - Merged cicd-workflow.md, separate-workflows-guide.md, workflows-setup-checklist.md, TAG_DEPLOYMENT.md
- **Archived** Old deployment docs to `docs/archive/outdated-deployment/`
- **Preserved** `deployment/scripts/README.md` - Actively maintained and accurate

**Key Improvements:**
- Fixed all GitHub Actions references to Gitea Actions
- Updated outdated server paths and architecture diagrams
- Eliminated 80% redundancy between workflow documents
- Created single source of truth for deployment and CI/CD

---

## Archive Location

Outdated deployment documentation has been archived to:
- `docs/archive/outdated-deployment/`

Files archived include: cicd-workflow.md, deployment-guide.md, deployment-summary.md, separate-workflows-guide.md, workflows-setup-checklist.md, nginx-setup.md, TAG_DEPLOYMENT.md
