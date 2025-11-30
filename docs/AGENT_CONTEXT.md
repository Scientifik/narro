# Narro - Agent Context Guide

> **Purpose:** This file helps AI agents quickly understand the Narro project structure, current state, and development patterns. For detailed documentation, see the referenced docs.

## Project Overview

Narro is a **$5/month social media curation app** that delivers algorithm-free feeds from social media profiles on multiple platforms. The project consists of four main components:

- **Backend API** (Go) - REST API server handling auth, profiles, lists, and feed aggregation
- **Web App** (Next.js) - Web interface for managing profiles and viewing feeds
- **Mobile App** (React Native + Expo) - iOS/Android apps (scaffolded, pending implementation)
- **Scraper Service** (Python) - Background service that scrapes social media profiles and stores content

**Current Status:** Backend and web app are functional with authentication, profile management, and list organization. Scraper service is implemented and ready to run. Feed aggregation and display are next priorities.

## Project Structure

```
narro/
├── backend/          # Go API (Gin framework, Supabase PostgreSQL)
│   ├── src/
│   │   ├── db/       # Database layer (GORM, URL parsing)
│   │   ├── models/   # Data models
│   │   ├── services/ # Business logic (auth, profiles, lists)
│   │   ├── handlers/ # HTTP handlers
│   │   ├── middleware/ # Auth, CORS, error handling
│   │   └── routes/   # Route definitions
│   ├── migrations/   # SQL migrations
│   └── main.go       # Entry point
│
├── web/              # Next.js 14+ web app (TypeScript, Tailwind)
│   ├── app/          # Next.js App Router
│   │   ├── (auth)/   # Auth pages (login, signup)
│   │   └── dashboard/ # Main app (profiles, lists, feed)
│   ├── components/   # React components
│   ├── lib/          # API client, hooks, utilities
│   └── types/        # TypeScript types
│
├── mobile/           # React Native + Expo (TypeScript)
│   ├── app/          # Expo Router pages
│   └── components/   # React Native components
│
├── scraper/          # Python background service
│   ├── src/
│   │   ├── scheduler/ # Pluggable scheduling strategies
│   │   ├── queue/    # Job queue management
│   │   ├── scrapers/ # Third-party API integrations (ScraperAPI)
│   │   ├── parsers/  # Platform-specific parsers (Twitter, LinkedIn, Instagram)
│   │   ├── duplicate/ # Cross-platform duplicate detection
│   │   ├── db/       # Database connection and queries
│   │   └── models/   # Data models (SQLAlchemy)
│   └── run.py        # Entry point
│
└── docs/             # Architecture and implementation documentation
```

## Tech Stack Quick Reference

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Backend API | Go 1.21+, Gin | REST API server |
| Database | Supabase (PostgreSQL) | Data storage + Auth |
| Web App | Next.js 14+, TypeScript, Tailwind | Web interface |
| Mobile App | React Native + Expo | iOS/Android apps |
| Scraper | Python 3.11+, SQLAlchemy | Background scraping service |
| Scraping Provider | ScraperAPI, Apify | Third-party scraping APIs (configurable) |

## Current Implementation Status

### ✅ Completed
- **Backend:**
  - Authentication system (Supabase Auth integration)
  - Profile management (add/remove social profiles)
  - List management (organize profiles into lists)
  - URL parsing (flexible input formats: `twitter.com/user`, `@user`, `twitter/user`, etc.)
  - Database schema (migrations 001-005)
  - GORM-based database layer
  - CORS middleware
  - Error handling middleware
  - Themes system (user-customizable color palettes)
  - Thumbnail serving endpoint (`/thumbnails/*`)

- **Web App:**
  - Authentication UI (signup, login, logout)
  - Profile management UI (add/remove profiles)
  - List management UI (create/manage lists)
  - API client with token management
  - Protected routes
  - Auth context for state management
  - Theme system UI (theme selector, context provider, hooks)
  - Theme-aware UI components using CSS variables

- **Scraper Service:**
  - ScraperAPI provider implementation
  - Apify provider implementation (Instagram Post Scraper)
  - Pluggable scheduler architecture
  - Database-based job queue
  - Platform parsers (Twitter, LinkedIn, Instagram)
  - Cross-platform duplicate detection
  - Comprehensive logging system
  - Python 3.13 compatibility
  - Single-run mode for testing
  - CLI tool for replaying Apify runs (`replay_apify_run.py`)
  - Storage provider system (local filesystem storage for thumbnails)
  - Thumbnail downloading and caching in parsers

### 🚧 In Progress / Next Up
- Feed aggregation engine
- Feed display UI
- Scraper testing with real profiles
- Mobile app UI implementation

### ⏳ Planned
- Stripe integration
- Production deployment
- Additional platform support (YouTube, etc.)

## Key Architecture Decisions

1. **System-wide profiles:** Profiles are scraped once, shared by all users who follow them. When a user adds a profile, the system checks if `(platform, username)` already exists in `social_profiles` table.

2. **Database queue:** Scraper uses PostgreSQL for job queue (no Redis needed). Jobs stored in `scraping_jobs` table.

3. **Pluggable scheduler:** Scraper scheduling strategies can be swapped via configuration without refactoring core service.

4. **Multiple scraping providers:** Supports ScraperAPI and Apify, with auto-detection based on available credentials. Can be explicitly set via `SCRAPER_PROVIDER` environment variable.

4. **Cross-platform duplicate detection:** Identifies duplicate posts across platforms but doesn't discard them - stores relationships in `feed_item_duplicates` table for frontend presentation.

5. **Flexible URL parsing:** Backend accepts various URL formats and normalizes to canonical form. Examples:
   - `twitter.com/username` → `https://twitter.com/username`
   - `@username` → `https://twitter.com/username` (assumes Twitter)
   - `twitter/username` → `https://twitter.com/username`

6. **Default lists:** Every user gets a default "All Profiles" list on signup (marked with `is_default = true`).

7. **Shared database:** Backend and scraper use the same Supabase PostgreSQL database.

8. **Feed items metadata:** Feed items store hashtags (JSONB array) and thumbnail URLs for rich display. Thumbnails use `displayUrl` from Apify or first image as fallback.

9. **Single-run mode:** Scraper can run in single-run mode (processes all jobs once and exits) for testing, or continuous mode with scheduler.

10. **Themes system:** Users can customize app appearance with themes. Themes are stored in database with JSONB color palettes. Default themes are seeded from `backend/config/themes.json`. User theme preference stored in `user_profiles.theme_id`.

11. **Thumbnail storage:** Scraper downloads and stores thumbnails locally using pluggable storage providers. Local storage saves files to `thumbnails/{job_id}/{uuid}.jpg`. Backend serves thumbnails via `/thumbnails/*` endpoint. Feed service constructs full URLs for thumbnails.

## Documentation Map

| Topic | Location | Description |
|-------|----------|-------------|
| Overall architecture | `docs/architecture.md` | Complete system architecture, tech stack decisions |
| Backend implementation | `docs/backend-implementation-plan.md` | Backend API design, endpoints, database schema |
| Scraper service | `docs/scraper-service-architecture.md` | Scraper architecture, scheduling, duplicate detection |
| Frontend-backend connection | `docs/frontend-backend-connection.md` | API client setup, hooks, testing |
| Auth implementation | `docs/signup-login-implementation.md` | Authentication flow, signup/login implementation |
| Recent updates | `update.md` | Daily progress updates (check this first!) |
| Project roadmap | `README.md` | Original project plan and session outline |
| Backend setup | `backend/README.md` | Backend setup instructions |
| Web app setup | `web/README.md` | Web app setup instructions |
| Mobile app setup | `mobile/README.md` | Mobile app setup instructions |
| Scraper setup | `scraper/README.md` | Scraper service setup instructions |

## Development Workflow

### Running Locally

**Backend:**
```bash
cd backend
go mod download
go run main.go  # Runs on :3000 (or PORT from .env)
```

**Web:**
```bash
cd web
npm install
npm run dev  # Runs on :3000
```

**Scraper:**
```bash
cd scraper
pip install -r requirements.txt
python3 run.py
```

### Environment Setup

Each project has its own `.env.example` file. Copy to `.env` (or `.env.local` for web) and configure:

**Backend (.env):**
- `DATABASE_URL` - Supabase PostgreSQL connection string
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_KEY` - Supabase service key
- `PORT` - Server port (default: 3000)
- `THUMBNAILS_DIR` - Directory for serving thumbnails (default: './thumbnails')
- `API_BASE_URL` - Base URL for API (for constructing thumbnail URLs, optional)
- `HOST` - Server host (default: 'localhost')

**Web (.env.local):**
- `NEXT_PUBLIC_API_URL` - Backend API URL (default: http://localhost:3030)
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anonymous key

**Scraper (.env):**
- `DATABASE_URL` - Same as backend (Supabase PostgreSQL)
- `SCRAPERAPI_API_KEY` - ScraperAPI credentials (optional)
- `SCRAPING_API_URL` - ScraperAPI base URL (optional)
- `APIFY_API_TOKEN` - Apify API token (optional)
- `APIFY_API_URL` - Apify API base URL (default: https://api.apify.com/v2)
- `SCRAPER_PROVIDER` - Provider to use: 'scraperapi', 'apify', 'auto', or 'mock' (default: 'auto')
- `SCHEDULER_INTERVAL_MINUTES` - How often to check for profiles (default: 5, not used in single-run mode)
- `MAX_CONCURRENT_JOBS` - Max parallel jobs (default: 10)
- `STORAGE_PROVIDER` - Storage provider: 'local', 's3', 'ftp' (default: 'local')
- `STORAGE_LOCAL_DIR` or `THUMBNAILS_DIR` - Directory for local storage (default: './thumbnails')
- `STORAGE_ENABLED` - Enable/disable thumbnail storage (default: 'true')

### Database Migrations

Migrations are SQL files in each project's `migrations/` directory. Run in Supabase SQL editor:

**Backend migrations:**
- `backend/migrations/001_initial_schema.sql` - Core schema (users, profiles, lists, feed_items)
- `backend/migrations/002_add_deleted_at_columns.sql` - Soft delete support
- `backend/migrations/003_add_youtube_platform.sql` - YouTube platform enum
- `backend/migrations/004_add_hashtags_and_thumbnail.sql` - Hashtags and thumbnail fields for feed_items
- `backend/migrations/005_add_themes_system.sql` - Themes table and user profile theme_id

**Scraper migrations:**
- `scraper/migrations/001_scraping_jobs.sql` - Job queue table
- `scraper/migrations/002_feed_item_duplicates.sql` - Duplicate detection table

## Common Patterns

### Adding a New API Endpoint (Backend)

1. Define route in `backend/src/routes/routes.go`:
   ```go
   api.GET("/api/endpoint", handler.HandleEndpoint)
   ```

2. Create handler in `backend/src/handlers/`:
   ```go
   func HandleEndpoint(c *gin.Context) {
       // Extract user from context (set by auth middleware)
       userID := c.GetString("user_id")
       // Call service
       // Return response
   }
   ```

3. Add service logic in `backend/src/services/`:
   ```go
   func (s *Service) DoSomething(userID string) error {
       // Business logic
       // Call database layer
   }
   ```

4. Add database queries in `backend/src/db/`:
   ```go
   func GetSomething(db *gorm.DB, userID string) ([]Model, error) {
       // GORM queries
   }
   ```

### Adding a New Scraper Parser

1. Create parser in `scraper/src/parsers/`:
   ```python
   from .base import BaseParser
   
   class NewPlatformParser(BaseParser):
       def parse(self, raw_data: dict) -> ParsedFeedItem:
           # Extract platform-specific fields
           # Normalize to ParsedFeedItem format
   ```

2. Register in parser factory or update platform detection logic

### Adding a New Platform

1. Add enum value to database `platform_type` enum (run migration)
2. Update URL parser in `backend/src/db/url_parser.go`
3. Create parser in `scraper/src/parsers/`
4. Update frontend platform icons/filters

### Frontend API Calls

**Using the API client directly:**
```typescript
import { apiClient } from '@/lib/api';
import { API_ENDPOINTS } from '@/lib/api-endpoints';

// GET request
const data = await apiClient.get(API_ENDPOINTS.profiles.list);

// POST request
const result = await apiClient.post(API_ENDPOINTS.profiles.create, { url: '...' });
```

**Using React hooks:**
```typescript
import { useGet } from '@/lib/hooks/use-api';

function MyComponent() {
  const { data, loading, error, execute } = useGet(API_ENDPOINTS.profiles.list);
  
  useEffect(() => {
    execute();
  }, []);
  
  // Use data, loading, error states
}
```

## Important Notes for Agents

- **Always check `update.md`** for the most recent changes and current state
- **System-wide profiles:** When a user adds a profile, check if it exists in `social_profiles` first
- **Default lists:** Every user gets a default "All Profiles" list on signup (cannot be deleted)
- **Scraper runs independently:** Background service, not triggered by API calls
- **Database is shared:** Backend and scraper use the same Supabase database
- **URL parsing is flexible:** Backend handles various formats, normalizes to canonical URL
- **Authentication:** Uses Supabase Auth, JWT tokens stored in localStorage (web) or SecureStore (mobile)
- **CORS:** Backend CORS middleware allows all origins in development (restrict in production)

## Quick Reference: File Locations

| What | Where |
|------|-------|
| Backend routes | `backend/src/routes/routes.go` |
| Auth middleware | `backend/src/middleware/auth_middleware.go` |
| Profile service | `backend/src/services/profile_service.go` |
| URL parser | `backend/src/db/url_parser.go` |
| Database models | `backend/src/models/` |
| Scraper main | `scraper/src/main.py` |
| Scraper entry point | `scraper/run.py` |
| Scraper replay tool | `scraper/replay_apify_run.py` |
| Scraper scheduler | `scraper/src/scheduler/` |
| Scraper parsers | `scraper/src/parsers/` |
| Scraper queue | `scraper/src/queue/` |
| Scraper providers | `scraper/src/scrapers/` (ScraperAPI, Apify, Mock) |
| Scraper storage | `scraper/src/storage/` (LocalStorageProvider, base StorageProvider) |
| Feed handler | `backend/src/handlers/feed_handler.go` |
| Feed service | `backend/src/services/feed_service.go` |
| Theme handler | `backend/src/handlers/theme_handler.go` |
| Theme service | `backend/src/services/theme_service.go` |
| Theme config | `backend/config/themes.json` |
| Web theme context | `web/lib/theme-context.tsx` |
| Web theme hooks | `web/lib/hooks/use-theme.ts` |
| Web theme selector | `web/components/theme/ThemeSelector.tsx` |
| Web API client | `web/lib/api.ts` |
| Web API endpoints | `web/lib/api-endpoints.ts` |
| Web auth context | `web/lib/auth-context.tsx` |
| Web API hooks | `web/lib/hooks/use-api.ts` |
| Web types | `web/types/api.ts` |

## Database Schema Overview

### Key Tables

- **`user_profiles`** - Extends Supabase auth.users with subscription info
- **`social_profiles`** - System-wide registry of profiles (one per platform+username)
- **`user_social_profiles`** - Junction table (users → profiles they follow)
- **`profile_lists`** - User-defined lists (everyone gets default list)
- **`profile_list_items`** - Junction table (lists → profiles)
- **`feed_items`** - Scraped posts (system-wide cache) with hashtags and thumbnail URLs
- **`scraping_jobs`** - Job queue for scraper service
- **`feed_item_duplicates`** - Cross-platform duplicate relationships
- **`themes`** - Theme definitions with color palettes (JSONB), supports holiday themes with date ranges

### Important Relationships

- One user → many lists (via `profile_lists`)
- One list → many profiles (via `profile_list_items`)
- One profile → many users (via `user_social_profiles`)
- One profile → many feed items (via `feed_items.social_profile_id`)
- Feed items can have duplicate relationships (via `feed_item_duplicates`)

## API Endpoints Quick Reference

### Authentication
- `POST /api/auth/signup` - Create account
- `POST /api/auth/login` - Login
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Get current user

### Profiles
- `GET /api/profiles` - List user's followed profiles (`?list_id=<uuid>` filter)
- `POST /api/profiles` - Add a profile URL
- `GET /api/profiles/:id` - Get profile details
- `DELETE /api/profiles/:id` - Unfollow a profile

### Lists
- `GET /api/lists` - List user's lists
- `POST /api/lists` - Create a new list
- `GET /api/lists/:id` - Get list details
- `PATCH /api/lists/:id` - Update list
- `DELETE /api/lists/:id` - Delete list (cannot delete default)
- `POST /api/lists/:id/profiles/:profile_id` - Add profile to list
- `DELETE /api/lists/:id/profiles/:profile_id` - Remove profile from list

### Feed
- `GET /api/feed` - Get unified feed (with pagination: `?page=1&limit=20&before=<timestamp>`)

### Themes
- `GET /api/themes` - List all active themes (`?include_inactive=true` for all)
- `GET /api/themes/:id` - Get theme by ID
- `GET /api/user/theme` - Get current user's theme (protected)
- `PATCH /api/user/theme` - Update user's theme (protected, body: `{ theme_id: uuid }`)
- `GET /api/admin/themes` - List all themes including inactive (admin)
- `POST /api/admin/themes` - Create new theme (admin)
- `PATCH /api/admin/themes/:id` - Update theme (admin)
- `DELETE /api/admin/themes/:id` - Delete theme (admin)

### Thumbnails
- `GET /thumbnails/*filepath` - Serve thumbnail files (public, with security checks)

## When to Update This File

Update this context file when:
- [ ] Major feature is completed
- [ ] Tech stack changes
- [ ] New service/component is added
- [ ] Architecture decision is made
- [ ] Development workflow changes
- [ ] New team member onboarding

**Last Updated:** November 29, 2025

---

## Quick Start Checklist for New Agents

1. ✅ Read this file (`docs/AGENT_CONTEXT.md`)
2. ✅ Check `update.md` for latest changes
3. ✅ Review `docs/architecture.md` for system overview
4. ✅ Read relevant implementation docs based on task
5. ✅ Check project-specific README files for setup
6. ✅ Understand the database schema (see `docs/backend-implementation-plan.md`)
7. ✅ Familiarize yourself with common patterns (above)

For specific tasks, refer to the detailed documentation in the `docs/` directory.

