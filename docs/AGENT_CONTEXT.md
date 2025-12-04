# Narro - Agent Context Guide

> **Purpose:** This file helps AI agents quickly understand the Narro project structure, current state, and development patterns. For detailed documentation, see the referenced docs.

## Project Overview

Narro is a **$5/month social media curation app** that delivers algorithm-free feeds from social media profiles on multiple platforms. The project consists of four main components:

- **Backend API** (Go) - REST API server handling auth, profiles, feeds, feed customization, profile favoriting, RSS generation, and feed aggregation
- **Web App** (Next.js) - Web interface for managing profiles and viewing feeds
- **Mobile App** (React Native + Expo) - iOS/Android apps (scaffolded, pending implementation)
- **Scraper Service** (Python) - Background service that scrapes social media profiles and stores content

**Current Status:** Backend and web app are fully functional with authentication, feed management, feed customization, profile favoriting, RSS feed generation, and a complete UI overhaul. Scraper service is implemented and ready to run. Feed-centric navigation with Feed Management Hub, Wide Mode, and individual feed views are complete. Route structure has been refactored to use cleaner paths (`/home`, `/feeds`, `/settings`, `/help`). Tutorial system infrastructure is in place for onboarding flows.

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
  - Feed management (organize profiles into feeds with customization)
  - Feed customization (emoji, custom images, colors, descriptions)
  - Profile favoriting within feeds (star/unstar profiles)
  - Home feed configuration (user-selectable default feed)
  - RSS feed generation (RSS 2.0 format per feed)
  - URL parsing (flexible input formats: `twitter.com/user`, `@user`, `twitter/user`, etc.)
  - Database schema (migrations 001-009)
  - GORM-based database layer
  - CORS middleware
  - Error handling middleware
  - Wide mode feed aggregation (all feeds combined)

- **Web App:**
  - Authentication UI (signup, login, logout)
  - Feed-centric navigation (Home, Feeds, Wide Mode, Settings, Help)
  - Clean route structure (`/home`, `/feeds`, `/settings`, `/help` with authenticated route group)
  - Feed Management Hub (grid/list views, feed cards with customization)
  - Individual feed view pages with filtering and profile favoriting
  - Feed configuration UI (view types: list/grid/gallery, card styles, background images)
  - Feed display UI with three view types (list, grid, gallery)
  - Frontend filtering (date range, profile, hashtag, starred)
  - Profile favoriting UI (star/unstar within feeds)
  - RSS feed links and copy-to-clipboard
  - Home feed selection in settings
  - Wide Mode page (aggregated view of all feeds)
  - Feed customization (emoji, colors, custom images, descriptions)
  - Integrated profile management within feeds
  - Feed onboarding for empty feeds
  - Tutorial system infrastructure (react-joyride integration, tutorial hooks)
  - API client with token management
  - Protected routes with authenticated layout
  - Auth context for state management
  - Consistent design system (removed user-selectable themes, fixed design with feed-level customization)

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
- Mobile app UI implementation
- Help page and tutorial system
- Additional feed customization options

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

6. **Default feeds:** Every user gets a default "All Profiles" feed on signup (marked with `is_default = true`).

7. **Shared database:** Backend and scraper use the same Supabase PostgreSQL database.

8. **Feed items metadata:** Feed items store hashtags (JSONB array) and thumbnail URLs for rich display. Thumbnails use `displayUrl` from Apify or first image as fallback.

9. **Single-run mode:** Scraper can run in single-run mode (processes all jobs once and exits) for testing, or continuous mode with scheduler.

10. **Feed customization:** Each feed can be customized with emoji, custom image URL, color, and description. Customization is visual-only and doesn't affect global UI appearance.

11. **Profile favoriting:** Users can star/favorite specific profiles within a feed for visual distinction. Starred profiles are stored in `feed_profile_favorites` table.

12. **Home feed:** Users can set a preferred home feed that loads by default on the dashboard. Stored in `user_profiles.home_feed_id`.

13. **RSS feeds:** Each feed has an RSS feed URL at `/feed/{feed_id}.rss` (or `.xml`). RSS feeds are generated on-demand in RSS 2.0 format.

14. **Frontend filtering:** All feed filtering (by date, profile, hashtag, starred status) is done on the frontend. Backend returns all feed items for the feed, frontend applies filters.

15. **Wide Mode:** Aggregated view showing all posts from all user feeds with feed attribution.

16. **Thumbnail storage:** Scraper uploads thumbnails directly to S3-compatible storage. Files are stored with path structure `{job_id}/{uuid}.jpg`. Frontend constructs full S3 URLs using `NEXT_PUBLIC_S3_BASE_URL` environment variable. Backend no longer serves thumbnails.

## Documentation Map

| Topic | Location | Description |
|-------|----------|-------------|
| Overall architecture | `docs/architecture.md` | Complete system architecture, tech stack decisions |
| Backend implementation | `docs/backend-implementation-plan.md` | Backend API design, endpoints, database schema |
| Scraper service | `docs/scraper-service-architecture.md` | Scraper architecture, scheduling, duplicate detection |
| Frontend-backend connection | `docs/frontend-backend-connection.md` | API client setup, hooks, testing |
| Auth implementation | `docs/signup-login-implementation.md` | Authentication flow, signup/login implementation |
| Deployment guide | `docs/deployment-guide.md` | Complete production deployment setup and instructions |
| Deployment summary | `docs/deployment-summary.md` | Overview of deployment infrastructure and components |
| Nginx setup | `docs/nginx-setup.md` | Nginx configuration and SSL/TLS setup with Let's Encrypt |
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
- `HOST` - Server host (default: 'localhost')

**Web (.env.local):**
- `NEXT_PUBLIC_API_URL` - Backend API URL (default: http://localhost:3030)
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Supabase anonymous key
- `NEXT_PUBLIC_S3_BASE_URL` - Base URL for S3 bucket (e.g., `https://bucket-name.region.digitaloceanspaces.com`)

**Scraper (.env):**
- `DATABASE_URL` - Same as backend (Supabase PostgreSQL)
- `SCRAPERAPI_API_KEY` - ScraperAPI credentials (optional)
- `SCRAPING_API_URL` - ScraperAPI base URL (optional)
- `APIFY_API_TOKEN` - Apify API token (optional)
- `APIFY_API_URL` - Apify API base URL (default: https://api.apify.com/v2)
- `SCRAPER_PROVIDER` - Provider to use: 'scraperapi', 'apify', 'auto', or 'mock' (default: 'auto')
- `SCHEDULER_INTERVAL_MINUTES` - How often to check for profiles (default: 5, not used in single-run mode)
- `MAX_CONCURRENT_JOBS` - Max parallel jobs (default: 10)
- `STORAGE_PROVIDER` - Storage provider: 's3' (default: 's3')
- `STORAGE_ENABLED` - Enable/disable thumbnail storage (default: 'true')
- `STORAGE_S3_BUCKET` - S3 bucket name (required)
- `STORAGE_S3_REGION` - S3 region (required, e.g., 'us-east-1', 'nyc3')
- `STORAGE_S3_ENDPOINT` - Optional custom endpoint for S3-compatible services
- `STORAGE_S3_ACCESS_KEY_ID` - AWS access key or equivalent (required)
- `STORAGE_S3_SECRET_ACCESS_KEY` - AWS secret key or equivalent (required)
- `STORAGE_S3_USE_SSL` - Use SSL (default: 'true')
- `STORAGE_S3_PUBLIC_BASE_URL` - Optional public base URL for constructing thumbnail URLs

### Database Migrations

Migrations are SQL files in each project's `migrations/` directory. Run in Supabase SQL editor:

**Backend migrations:**
- `backend/migrations/001_initial_schema.sql` - Core schema (users, profiles, lists, feed_items)
- `backend/migrations/002_add_deleted_at_columns.sql` - Soft delete support
- `backend/migrations/003_add_youtube_platform.sql` - YouTube platform enum
- `backend/migrations/004_add_hashtags_and_thumbnail.sql` - Hashtags and thumbnail fields for feed_items
- `backend/migrations/005_add_themes_system.sql` - Themes table and user profile theme_id
- `backend/migrations/006_rename_lists_to_feeds.sql` - Renamed lists to feeds throughout schema
- `backend/migrations/007_add_feed_configurations.sql` - Feed configuration table (view types, card styles, etc.)
- `backend/migrations/008_add_feed_customization_fields.sql` - Feed customization (emoji, custom_image_url, description, rss_feed_url)
- `backend/migrations/009_add_home_feed_and_profile_favoriting.sql` - Home feed and profile favoriting tables

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
- **Default feeds:** Every user gets a default "All Profiles" feed on signup (cannot be deleted)
- **Frontend filtering:** All feed filtering (date, profile, hashtag, starred) is done on the frontend, not backend
- **Feed customization:** Feeds can be customized with emoji, colors, custom images, and descriptions (visual only)
- **Profile favoriting:** Users can star profiles within feeds for visual distinction
- **RSS feeds:** Each feed has an RSS feed at `/feed/{feed_id}.rss` format
- **Scraper runs independently:** Background service, not triggered by API calls
- **Database is shared:** Backend and scraper use the same Supabase database
- **URL parsing is flexible:** Backend handles various formats, normalizes to canonical URL
- **Authentication:** Uses Supabase Auth, JWT tokens stored in localStorage (web) or SecureStore (mobile)
- **CORS:** Backend CORS middleware allows all origins in development (restrict in production)
- **Design system:** Removed user-selectable themes; using consistent fixed design with feed-level customization
- **Thumbnail storage:** Thumbnails stored in S3-compatible storage, frontend constructs URLs using `NEXT_PUBLIC_S3_BASE_URL`

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
| Feed management handler | `backend/src/handlers/feed_management_handler.go` |
| Feed management service | `backend/src/services/feed_management_service.go` |
| Feed configuration handler | `backend/src/handlers/feed_configuration_handler.go` |
| Feed configuration service | `backend/src/services/feed_configuration_service.go` |
| Feed profile favorite handler | `backend/src/handlers/feed_profile_favorite_handler.go` |
| Feed profile favorite service | `backend/src/services/feed_profile_favorite_service.go` |
| RSS service | `backend/src/services/rss_service.go` |
| User settings handler | `backend/src/handlers/user_settings_handler.go` |
| User service | `backend/src/services/user_service.go` |
| Theme handler | `backend/src/handlers/theme_handler.go` |
| Theme service | `backend/src/services/theme_service.go` |
| Theme config | `backend/config/themes.json` |
| Web API client | `web/lib/api.ts` |
| Web API endpoints | `web/lib/api-endpoints.ts` |
| Web auth context | `web/lib/auth-context.tsx` |
| Web API hooks | `web/lib/hooks/use-api.ts` |
| Web feed config hooks | `web/lib/hooks/use-feed-config.ts` |
| Web home feed hooks | `web/lib/hooks/use-home-feed.ts` |
| Web feed favorites hooks | `web/lib/hooks/use-feed-favorites.ts` |
| Web wide mode hooks | `web/lib/hooks/use-wide-mode-feed.ts` |
| Web tutorial hooks | `web/lib/hooks/use-tutorial.ts` |
| Web types | `web/types/api.ts` |
| Web feed components | `web/components/feed/` |
| Web feed management components | `web/components/feeds/` |
| Web tutorial components | `web/components/tutorial/Tutorial.tsx` |
| Web navigation | `web/components/navigation/TopNavigation.tsx` |
| Web authenticated routes | `web/app/(authenticated)/` |

## Database Schema Overview

### Key Tables

- **`user_profiles`** - Extends Supabase auth.users with subscription info
- **`social_profiles`** - System-wide registry of profiles (one per platform+username)
- **`user_social_profiles`** - Junction table (users → profiles they follow)
- **`feeds`** - User-defined feeds (everyone gets default feed) with customization fields (emoji, custom_image_url, description, rss_feed_url)
- **`feed_profile_items`** - Junction table (feeds → profiles)
- **`feed_configurations`** - UI configuration for each feed (view type, card style, background image)
- **`feed_profile_favorites`** - Profile favoriting within feeds (user_id, feed_id, user_social_profile_id)
- **`feed_items`** - Scraped posts (system-wide cache) with hashtags and thumbnail URLs
- **`scraping_jobs`** - Job queue for scraper service
- **`feed_item_duplicates`** - Cross-platform duplicate relationships
- **`themes`** - Theme definitions with color palettes (JSONB), supports holiday themes with date ranges

### Important Relationships

- One user → many feeds (via `feeds`)
- One user → one home feed (via `user_profiles.home_feed_id`)
- One feed → many profiles (via `feed_profile_items`)
- One feed → one configuration (via `feed_configurations.feed_id`, unique)
- One user → many starred profiles per feed (via `feed_profile_favorites`)
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
- `GET /api/profiles` - List user's followed profiles (`?feed_id=<uuid>` filter)
- `POST /api/profiles` - Add a profile URL (optional `feed_id` in body)
- `GET /api/profiles/:id` - Get profile details
- `DELETE /api/profiles/:id` - Unfollow a profile

### Feeds
- `GET /api/feeds` - List user's feeds
- `POST /api/feeds` - Create a new feed (with customization: emoji, custom_image_url, description)
- `GET /api/feeds/:id` - Get feed details
- `PATCH /api/feeds/:id` - Update feed (name, color, emoji, custom_image_url, description)
- `DELETE /api/feeds/:id` - Delete feed (cannot delete default)
- `GET /api/feeds/:id/profiles` - Get profiles in feed
- `POST /api/feeds/:id/profiles/:profile_id` - Add profile to feed
- `DELETE /api/feeds/:id/profiles/:profile_id` - Remove profile from feed
- `POST /api/feeds/:id/profiles/:profile_id/star` - Star/favorite a profile in feed
- `DELETE /api/feeds/:id/profiles/:profile_id/star` - Unstar a profile in feed
- `GET /api/feeds/:id/starred-profiles` - Get starred profiles for feed
- `GET /api/feeds/:id/feed-config` - Get feed configuration
- `POST /api/feeds/:id/feed-config` - Create feed configuration
- `PATCH /api/feeds/:id/feed-config` - Update feed configuration
- `DELETE /api/feeds/:id/feed-config` - Delete feed configuration
- `GET /feed/:id.rss` - RSS feed for a feed (RSS 2.0 format)

### Feed Content
- `GET /api/feed` - Get feed items/posts (with pagination: `?page=1&limit=20&feed_id=<uuid>`)
- `GET /api/feed/wide-mode` - Get all posts from all feeds (wide mode aggregation)

### User Settings
- `GET /api/user/home-feed` - Get user's home feed
- `PATCH /api/user/home-feed` - Set user's home feed (body: `{ feed_id: uuid }`)

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
- Thumbnails are served directly from S3, not through the backend API

## When to Update This File

Update this context file when:
- [ ] Major feature is completed
- [ ] Tech stack changes
- [ ] New service/component is added
- [ ] Architecture decision is made
- [ ] Development workflow changes
- [ ] New team member onboarding

**Last Updated:** December 3, 2025

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

