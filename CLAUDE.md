# Narro - Claude Code Instructions

**Status:** ✅ CURRENT
**Last Updated:** 2026-02-06

---

## Project Overview

Narro is a **social media curation app** that delivers algorithm-free feeds from social media profiles on multiple platforms. The project consists of four main components, each component is it's own git repo:

| Component | Location | Technology | Status |
|-----------|----------|------------|--------|
| Backend API | `/backend` | Go + Gin | Production Ready |
| Web App | `/web` | Next.js 16 + React 19 | Production Ready |
| Mobile App | `/mobile` | React Native + Expo | In Development |
| Scraper Service | `/scraper` | Python | Production Ready |

---

## Quick Reference

| Resource | Location | Purpose |
|----------|----------|---------|
| Main Context | `.claude/context.md` | Comprehensive agent guide |
| Architecture | `.claude/architecture.md` | System design document |
| Latest Updates | `update.md` | Development changelog |
| Agent Definitions | `.claude/agents/` | Specialized agent prompts |
| Documentation Audit | `docs/DOCUMENTATION_AUDIT.md` | Documentation status |
| Deployment Guide | `docs/deployment/DEPLOYMENT.md` | Complete deployment setup |
| CI/CD Guide | `docs/deployment/CICD.md` | Gitea Actions workflows |
| Deployment Index | `.claude/DEPLOYMENT_DOCS_INDEX.md` | Navigation for all deployment docs |

---

## Development Commands

```bash
# Backend (Go)
cd backend && go run main.go    # Runs on :3030

# Web (Next.js)
cd web && npm run dev           # Runs on :3000

# Scraper (Python)
cd scraper && python3 run.py scrape --platform twitter --limit 50
cd scraper && python3 run.py avatars --platform instagram --limit 10
cd scraper && python3 run.py update_frequency --platform twitter
cd scraper && python3 run.py serve --port 8000    # HTTP API server
```

---

## Key Architecture Patterns

1. **System-wide profiles** - Profiles scraped once, shared by all users
2. **Database queue** - PostgreSQL for scraper job queue (no Redis)
3. **Frontend filtering** - Backend returns all data, frontend filters
4. **S3 thumbnails** - Scraper uploads to S3, frontend constructs URLs
5. **Feed customization** - Visual customization per feed (emoji, colors, images)
6. **Profile favoriting** - Star profiles within feeds

---

## Database

- **Provider:** Supabase (PostgreSQL)
- **Backend Migrations:** `backend/migrations/001-023`
- **Scraper Migrations:** `scraper/migrations/001-004`

Key tables: `user_profiles`, `social_profiles`, `user_feed_profiles`, `feeds`, `feed_items`

---

## Environment Variables

Each project has `.env.example` files. Key variables:

- `DATABASE_URL` - Supabase PostgreSQL connection string
- `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` - Supabase credentials
- `APIFY_API_TOKEN` - Apify scraping service
- `STORAGE_S3_*` - S3-compatible storage configuration

---

## Current Focus Areas

- Migration to `user_feed_profiles` table (see `MIGRATION_PLAN_USER_FEED_PROFILES.md`)
- Mobile app implementation
- Documentation standardization

---

## Agent Routing

For specialized tasks, reference these agents:

| Task | Agent | File |
|------|-------|------|
| Backend API work | Backend Architect | `.claude/agents/backend-architect.md` |
| Web development | Web Developer | `.claude/agents/narro-web-developer.md` |
| Mobile development | Mobile Architect | `.claude/agents/mobile-app-architect.md` |
| Scraper work | Scraper Architect | `.claude/agents/scraper-architect.md` |
| Cross-component planning | Tech Liaison | `.claude/agents/narro-tech-liaison.md` |

---

## Important Notes

- Always check `update.md` for latest changes before starting work
- Use `.claude/context.md` for comprehensive project understanding
- Backend CORS allows all origins in development (restrict in production)
- Scraper runs independently, not triggered by API calls
- Tutorial system uses custom implementation (no react-joyride)
