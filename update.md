# Narro Development Updates

Daily updates tracking progress on the Narro project. The README contains a rough session outline, but we're moving at our own pace based on what makes sense.

---

## December 11, 2025

**What we did:**
- **Critical Security Updates (CVE-2025-55182 "React2Shell"):**
  - Updated Next.js from 16.0.3 to 16.0.10 (patched version addressing CVE-2025-55182)
  - Updated React from 19.2.0 to 19.2.3 (patched version addressing CVE-2025-55182)
  - Updated React DOM from 19.2.0 to 19.2.3 (patched version)
  - Updated @sentry/nextjs from 8.43.0 to 10.30.0 (compatible with Next.js 16)
  - Updated eslint-config-next to match Next.js 16.0.10
  - Updated Tailwind CSS and related dependencies to latest versions
  - Updated TypeScript types to match React 19.2.3

- **Tutorial System Refactoring:**
  - Removed `react-joyride` dependency (incompatible with React 19)
  - Created custom `Tutorial` component (`components/tutorial/Tutorial.tsx`)
  - Implemented custom tutorial overlay with:
    - Element highlighting with outline and shadow effects
    - Tooltip positioning (top, bottom, left, right, center)
    - Step navigation (back, next, skip, finish)
    - Progress indicator (step X of Y)
    - Responsive tooltip positioning with viewport clamping
  - Updated tutorial step type definitions (`TutorialStep`, `TutorialStepPlacement`)
  - Updated all tutorial imports across the application:
    - `app/home/feeds/page.tsx`
    - `app/dashboard/feeds/page.tsx`
    - `app/(authenticated)/feeds/page.tsx`
  - Maintained backward compatibility with existing tutorial step definitions

- **Route Cleanup:**
  - Removed duplicate route files that were causing Next.js build conflicts:
    - Removed `app/home/page.tsx` (duplicate of `app/(authenticated)/home/page.tsx`)
    - Removed `app/home/feeds/*` routes (duplicate of authenticated routes)
    - Removed `app/feed/[id]/*` routes (duplicate of authenticated routes)
    - Removed `app/feeds/[id]/*` routes (duplicate of authenticated routes)
    - Removed `app/help/page.tsx` (duplicate of authenticated route)
  - Resolved Next.js route conflict errors during build

- **Docker Build Improvements:**
  - Removed `--legacy-peer-deps` flag from Dockerfile (no longer needed with updated dependencies)
  - Updated `npm ci` command to use standard peer dependency resolution

**Where we are:**
- ✅ All security vulnerabilities patched (CVE-2025-55182 addressed)
- ✅ Next.js and React updated to latest patched versions
- ✅ Tutorial system refactored to use custom implementation (no external dependencies)
- ✅ Route conflicts resolved, build process working correctly
- ✅ Docker builds optimized without legacy peer dependency flags

**Security Impact:**
- CVE-2025-55182 ("React2Shell") was a critical pre-authentication RCE vulnerability affecting React Server Components in Next.js 15.x/16.x and React 19.x
- The vulnerability allowed unauthenticated attackers to execute arbitrary code via unsafe deserialization of payloads sent to React Server Function endpoints
- All affected versions have been updated to patched releases

**Next up:**
- Test tutorial functionality with new custom implementation
- Verify all routes work correctly after cleanup
- Monitor for any additional security advisories
- Continue with feature development

---

## December 10, 2025

**What we did:**
- **Modular Scraper Architecture Refactoring:**
  - Created `src/scrapers/platform_config.py` with base classes for platform-specific configurations
  - Implemented `ApifyPlatformConfig` dataclass (actor_id, input_schema, description, documentation_url)
  - Implemented `ScraperAPIPlatformConfig` dataclass (render, country_code, premium, custom_params)
  - Created `PlatformConfig` abstract base class for platform configuration interface
  - Enables separation of concerns: scrapers are generic, platforms define configuration

- **Scraper Provider Refactoring:**
  - Updated `src/scrapers/base.py` - Added optional `config` parameter to abstract interface
  - Refactored `src/scrapers/scraperapi.py` - Now accepts `ScraperAPIPlatformConfig`, removed hardcoded platform logic
  - Refactored `src/scrapers/apify.py` - Now accepts `ApifyPlatformConfig`, added `_prepare_actor_input_from_config()`
  - Updated `src/scrapers/mock.py` - Signature compatibility with new interface
  - All scrapers now configuration-driven instead of hardcoded

- **Worker Fallback Logic:**
  - Added `_get_platform_config()` method to dynamically load platform configs at runtime
  - Implemented `_scrape_with_fallback()` method with intelligent scraper fallback
  - Tries each scraper in `supported_scrapers` list, automatically falls back to next on error
  - Platform configs determine scraper order and parameters
  - Maintains backward compatibility (falls back to legacy behavior if no config found)

- **Platform Configurations:**
  - Created `src/scrapers/platforms/` directory structure
  - Implemented `InstagramConfig` - Apify only (ScraperAPI doesn't work due to anti-bot)
  - Implemented `TwitterConfig` - Both Apify and ScraperAPI (Apify preferred, fallback supported)
  - Implemented `LinkedinConfig` - Both Apify and ScraperAPI (premium IPs recommended)
  - Each config includes actor IDs, input schemas, and platform-specific parameters

- **create-handler Skill (Complete Implementation):**
  - **Core Generator:** Created `create-handler/generator.py` (600+ lines)
    - `ConfigGenerator` class with generate_config() and write_config() methods
    - Hardcoded ScraperAPI support matrix for known platforms
    - Default ScraperAPI parameters per platform
    - Automatic Python code generation with proper formatting
    - Input validation and error handling

  - **MCP Configuration:** Created `.mcp.json` for Apify MCP Server integration
    - Configured to use `${APIFY_API_TOKEN}` environment variable
    - Enables automatic actor discovery from Apify

  - **Skill Definition:** Created `.claude/skills/create-handler.md`
    - Complete skill reference (500+ lines)
    - Usage examples and discovery process
    - Configuration defaults and error handling
    - Integration with Worker documentation

  - **Testing:** Created `tests/test_generator.py`
    - 30+ comprehensive unit tests (500+ lines)
    - Input validation tests
    - Config generation tests
    - Code generation tests
    - File I/O tests
    - Error handling tests
    - Integration tests
    - All tests passing ✅

  - **Documentation:** Created comprehensive documentation (2,700+ lines total)
    - `SETUP.md` (500 lines) - Complete user setup guide
    - `SKILL.md` (500 lines) - Full skill reference with examples
    - `IMPLEMENTATION.md` (400 lines) - Implementation details
    - `mcp-queries.md` (400 lines) - MCP Server API reference
    - `README.md` (500 lines) - Quick start guide
    - Updated `scraper.md` with architecture diagrams and modular design explanation

- **Configuration Templates:**
  - Created `templates/platform_config_template.py` - Template for creating new configs
  - Created `templates/base.py` - Reference of base classes
  - Created example configs in `templates/examples/`:
    - `instagram.py` - Fully documented example (Apify only)
    - `twitter.py` - Fully documented example (both scrapers)
    - `linkedin.py` - Fully documented example (both scrapers)
  - Created `templates/README.md` - How to use templates and create configs manually

**Where we are:**
- ✅ Modular, configuration-driven scraper architecture implemented
- ✅ Platform configs decouple scraper logic from platform specifics
- ✅ Worker automatically loads and uses platform configurations
- ✅ Intelligent fallback logic between Apify and ScraperAPI
- ✅ create-handler skill fully implemented and production-ready
- ✅ Automatic Apify actor discovery via MCP Server
- ✅ 30+ unit tests with comprehensive coverage
- ✅ 2,700+ lines of documentation
- ✅ Zero external dependencies (generator uses only stdlib)
- ✅ Security best practices: token in env variable, safe to commit .mcp.json

**Key Achievements:**
1. **Architecture:** Scrapers are now generic tools, platforms define configuration
2. **Extensibility:** Add new platforms with one command: `@skill create-handler: "platform"`
3. **Reliability:** Automatic fallback from Apify to ScraperAPI if first fails
4. **Testability:** 30+ unit tests ensure code quality
5. **Documentation:** Complete setup, usage, and implementation guides

- **Plausible Analytics Integration (Completed):**
  - ✅ Added cookieless analytics with Plausible Analytics
  - ✅ Created `lib/hooks/use-analytics.ts` hook for event tracking
  - ✅ Added Plausible script to `app/layout.tsx`
  - ✅ Integrated user event tracking:
    - Feed views (grid/list) with view mode tracking
    - Profile favoriting/unfavoriting
    - Tutorial start and completion
    - Theme changes
  - ✅ No cookie banner required (GDPR compliant)
  - ✅ Automatic page view tracking

- **Sentry.io Error Tracking & Performance Monitoring (Completed):**

  **Frontend (Next.js):**
  - ✅ Installed @sentry/nextjs SDK (`@sentry/nextjs@8.43.0`)
  - ✅ Created three Sentry config files (client, server, edge runtimes)
  - ✅ Updated next.config.ts with withSentryConfig wrapper and source map upload
  - ✅ Created three error boundary components:
    - `app/global-error.tsx` - Root-level error boundary
    - `app/error.tsx` - Route-level error boundary
    - `app/(authenticated)/error.tsx` - Authenticated routes error boundary
  - ✅ Instrumented `lib/api.ts` to capture API errors with context
  - ✅ Added user context tracking to `lib/auth-context.tsx`
  - ✅ Updated `.env.local.example` with Sentry variables
  - ✅ Updated web/Dockerfile with Sentry build args

  **Backend (Go/Gin):**
  - ✅ Updated `main.go` with Sentry initialization
  - ✅ Created `src/middleware/sentry.go` with comprehensive middleware
  - ✅ Updated `src/middleware/error_handler.go` to capture errors in Sentry
  - ✅ Updated `src/routes/routes.go` to add Sentry middleware chain
  - ✅ Updated `env.example` with Sentry configuration
  - ✅ Updated backend/Dockerfile with Sentry release tracking
  - ✅ Updated `deployment/scripts/env.prod` with all Sentry variables

**Key Features Enabled:**
- Error tracking with user context (links errors to specific users)
- Performance monitoring (10% sampling in production)
- Error boundaries prevent unhandled React errors from crashing app
- Source maps automatically uploaded to Sentry for production debugging
- Release tracking with git commit SHAs
- Automatic breadcrumbs for navigation and interactions

**Next up:**
- Use create-handler skill to generate configs for additional platforms as needed
- Monitor Apify MCP Server for new actors and update support matrix
- Consider additional enhancement features (caching, adaptive selection, config validation)
- Test full workflow with Apify actor discovery in production

---

## December 4, 2025

**What we did:**
- **Ubuntu Deployment Infrastructure:**
  - Created `provision-ubuntu.sh` for one-time server provisioning on Ubuntu 22.04 LTS
  - Installs Docker, Docker Compose, Nginx, and Certbot
  - Configures Nginx with reverse proxy for API and web services
  - Sets up `narro` user with proper permissions
  - Creates deployment directory structure
  - Configures firewall rules for SSH, HTTP, and HTTPS
  
- **Container Registry Deployment:**
  - Created `deploy.sh` script for pulling images from container registry and deploying
  - Supports registry authentication with credentials from `.env.production`
  - Pulls images with specific tags (supports commit SHA tagging)
  - Implements zero-downtime deployment with health checks
  - Shows container logs for debugging deployment issues
  
- **Docker Compose Improvements:**
  - Updated health check configuration with improved timeouts and retries
  - Increased `start_period` from 40s to 60s for backend API
  - Increased health check retries from 3 to 5
  - Fixed health check command syntax for proper error handling
  - All services configured to pull from container registry instead of building locally
  
- **Environment Configuration:**
  - Created `env.prod` template with all required production environment variables
  - Includes registry credentials, database URLs, API keys, and S3 storage configuration
  - Documents all required and optional variables
  
- **Documentation:**
  - Added comprehensive README for deployment scripts
  - Documented provisioning and deployment workflows
  - Included troubleshooting steps and common issues

**Where we are:**
- Complete deployment infrastructure for Ubuntu 22.04 LTS servers
- Container registry-based deployment workflow ready
- Health checks improved for better container startup reliability
- All deployment files organized in `deployment/scripts/` directory

**Next up:**
- Test full deployment workflow on production server
- Set up CI/CD pipeline for automated builds and deployments
- Monitor container health and performance in production
- Implement automated health check monitoring

---

## December 3, 2025

**What we did:**
- **Route Structure Refactoring (Web App):**
  - Restructured authenticated routes from `/dashboard/*` to cleaner route structure
  - Created new `(authenticated)` route group with proper layout
  - Moved routes: `/dashboard` → `/home`, `/dashboard/feeds` → `/feeds`, `/dashboard/settings` → `/settings`
  - Removed old dashboard pages and consolidated into new structure
  - Updated navigation to use new route paths
  - Improved route organization for better maintainability
  
- **Tutorial System (Web App):**
  - Added tutorial component using react-joyride library
  - Created `useTutorial` hook for tutorial state management
  - Implemented tutorial completion tracking via localStorage
  - Added tutorial infrastructure ready for onboarding flows
  
- **Thumbnail URL Construction (Backend):**
  - Enhanced feed service with `constructThumbnailURL()` function
  - Added `getAPIBaseURL()` helper to construct base URLs from environment variables
  - Improved thumbnail URL handling for both external URLs and local storage paths
  - Ensures proper URL construction for `/thumbnails/*` endpoint
  - Handles relative paths from scraper and converts to full URLs
  
- **Code Cleanup:**
  - Removed unused admin themes page
  - Removed API test page
  - Cleaned up old dashboard structure
  - Updated package dependencies

**Where we are:**
- Cleaner route structure improves navigation and maintainability
- Tutorial system infrastructure ready for onboarding implementation
- Thumbnail URLs properly constructed for all feed items
- Codebase is more organized with removed unused pages

**Next up:**
- Implement tutorial steps for user onboarding
- Test thumbnail URL construction with real data
- Continue refining UI/UX based on new route structure
- Add help page content

---

## December 3, 2025

**What we did:**
- **Feed Configuration System (Complete Refactor):**
  - Renamed "lists" to "feeds" throughout the entire codebase for consistent terminology
  - Created database migrations to rename tables: `profile_lists` → `feeds`, `profile_list_items` → `feed_profile_items`
  - Added `feed_configurations` table with UI customization options (view type, card style, background image, auto-refresh)
  - Updated all backend models, services, handlers, and routes to use "feed" terminology
  - Updated all frontend types, API endpoints, and hooks to use "feed" terminology
  
- **Backend Changes:**
  - Created `Feed`, `FeedProfileItem`, and `FeedConfiguration` models
  - Created `FeedManagementService` for feed CRUD operations
  - Created `FeedConfigurationService` for feed configuration management
  - Updated `FeedService` to support filtering by `feed_id` parameter
  - Updated all database layer functions to use feed terminology
  - Updated routes: `/api/lists` → `/api/feeds`, added `/api/feeds/:id/feed-config` endpoints
  - Updated profile service to use `feed_id` instead of `list_id`
  
- **Frontend Changes:**
  - Created feed view components: `ListFeedView`, `GridFeedView`, `GalleryFeedView`, `FeedCard`
  - Created `FeedConfigurationModal` for configuring feed settings
  - Created `FeedProfileManager` component for integrated profile management within feeds
  - Created `FeedOnboarding` component for empty feeds
  - Refactored dashboard page to:
    - Support multiple feeds with feed selector
    - Load and apply feed configurations
    - Render appropriate view type (list/grid/gallery) based on configuration
    - Integrate profile management directly under each feed
    - Show onboarding for empty feeds
    - Support auto-refresh based on configuration
    - Apply background images from configuration
  - Updated navigation: removed "Profiles" link, updated "Lists" to "Feeds"
  - Updated all components to use feed terminology
  
- **View Types:**
  - **List**: Infinite scroll vertical list (default)
  - **Grid**: Responsive grid layout with cards
  - **Gallery**: Image-focused wide grid view (TikTok/Instagram style, maximizes image display)
  
- **Configuration Options:**
  - View type (list/grid/gallery)
  - Card style (compact/expanded/minimal)
  - Background image URL
  - Auto-refresh enabled/disabled
  - Auto-refresh interval (seconds)

**Where we are:**
- Complete feed configuration system allows users to customize how each feed displays
- Users can create multiple feeds with different configurations
- Profile management is integrated into each feed view
- Three distinct view types provide different browsing experiences
- Auto-refresh functionality supports real-time updates
- Consistent "feed" terminology throughout the application

**Next up:**
- Test feed creation and configuration
- Test all three view types with real data
- Verify auto-refresh functionality
- Test profile management within feeds
- Consider adding more configuration options (e.g., sorting, filtering)

---

## December 2, 2025

**What we did:**
- **Production Deployment Infrastructure:**
  - Created complete Docker-based deployment system for production on Vultr
  - Built multi-stage Dockerfiles for all three services (backend, web, scraper)
  - Created docker-compose configurations for single-server and multi-server setups
  - Implemented zero-downtime deployment strategy with health checks
  - Set up GitHub Actions CI/CD workflow for automated deployments
  
- **Code Changes:**
  - Moved health endpoint from `/health` to `/api/health` in backend for consistency
  - Updated web app to use `/api/health` endpoint
  - Updated Next.js config for standalone Docker output (optimized builds)
  - Updated all documentation references to new health endpoint
  
- **Docker Infrastructure:**
  - `backend/Dockerfile` - Multi-stage Go build with pinned Alpine 3.19
  - `web/Dockerfile` - Multi-stage Next.js build with standalone output
  - `scraper/Dockerfile` - Python 3.11 slim image
  - Added `.dockerignore` files for all services to optimize builds
  
- **Docker Compose Configuration:**
  - `deployment/docker-compose.yml` - Single-server setup (API + Web running, scraper for cron)
  - `deployment/docker-compose.api.yml` - API only (multi-server ready)
  - `deployment/docker-compose.web.yml` - Web only (multi-server ready)
  - `deployment/docker-compose.scraper.yml` - Scraper only (for on-demand cron execution)
  - Scraper is containerized but NOT deployed as running service (runs on-demand via cron)
  
- **Deployment Scripts:**
  - `deployment-scripts/deploy.sh` - Main deployment script with zero-downtime strategy
  - `deployment-scripts/health-check.sh` - Health check utility for API and Web
  - `deployment-scripts/cron-scraper.sh` - Scraper execution script for cron jobs
  
- **CI/CD Pipeline:**
  - `.github/workflows/deploy.yml` - GitHub Actions workflow
  - Automated deployment on push to `main` branch
  - SSH-based deployment to Vultr instance
  - Health check verification after deployment
  
- **Nginx Configuration:**
  - `deployment/nginx/nginx.conf` - Single-server reverse proxy with SSL/TLS
  - `deployment/nginx/nginx.lb.conf` - Load balancer config for multi-server setup
  - Let's Encrypt/Certbot integration for SSL certificates
  - Security headers and optimized proxy settings
  
- **Documentation:**
  - `docs/deployment-guide.md` - Complete deployment setup instructions
  - `docs/deployment-summary.md` - Overview of deployment infrastructure
  - `docs/nginx-setup.md` - Nginx and SSL configuration guide
  - Updated `docs/AGENT_CONTEXT.md` with deployment documentation references

**Where we are:**
- Complete production deployment infrastructure ready
- Zero-downtime deployment strategy implemented
- Multi-server architecture supported (can start single-server, scale later)
- Scraper runs on-demand via cron (not as long-running service)
- SSL/TLS configured with Let's Encrypt
- Automated CI/CD pipeline ready for GitHub Actions
- All deployment documentation organized in `/docs` folder

**Next up:**
- Set up Vultr instance and configure production environment
- Add GitHub secrets for CI/CD (VULTR_HOST, VULTR_USER, VULTR_SSH_KEY, VULTR_DEPLOY_PATH)
- Test deployment workflow
- Configure SSL certificates with Let's Encrypt
- Set up scraper cron job
- Test end-to-end deployment process

---

## November 29, 2025

**What we did:**
- **Themes System (Backend & Web):**
  - Created complete themes system with database schema (migration 005)
  - Added `themes` table with color palette JSONB storage, holiday theme support, and RLS policies
  - Implemented theme service, handler, and API endpoints (`/api/themes`, `/api/user/theme`, `/api/admin/themes`)
  - Added theme configuration file (`backend/config/themes.json`) with 3 default themes: Modern Vibrant, Cool Professional, Warm Friendly
  - Created theme context provider and hooks in web app (`lib/theme-context.tsx`, `lib/hooks/use-theme.ts`)
  - Built theme selector component with live preview (`components/theme/ThemeSelector.tsx`)
  - Updated user profiles to support `theme_id` foreign key
  - Applied theme colors throughout dashboard UI using CSS variables
  - Added admin endpoints for theme management (create, update, delete)
  
- **Thumbnail Storage System (Scraper & Backend):**
  - Created pluggable storage provider system (`scraper/src/storage/`)
  - Implemented local filesystem storage provider (`LocalStorageProvider`) for downloading and storing thumbnails
  - Updated all parsers (Instagram, Twitter, LinkedIn) to download thumbnails using storage provider
  - Added `download_thumbnail()` method to base parser class
  - Added storage configuration settings (`STORAGE_PROVIDER`, `STORAGE_LOCAL_DIR`, `STORAGE_ENABLED`)
  - Created thumbnail serving endpoint in backend (`GET /thumbnails/*filepath`) with security checks
  - Updated feed service to generate full thumbnail URLs (handles both external URLs and local storage paths)
  - Added `THUMBNAILS_DIR` environment variable support
  - Thumbnails organized by job ID: `thumbnails/{job_id}/{uuid}.jpg`
  
- **Feed Service Enhancements:**
  - Enhanced feed service to construct full thumbnail URLs from relative paths
  - Added `getAPIBaseURL()` helper function to construct backend URLs for thumbnails
  - Supports both external thumbnail URLs (http/https) and local storage paths
  
- **UI Improvements (Web):**
  - Refactored dashboard and auth pages to use theme CSS variables instead of hardcoded colors
  - Updated profile cards, buttons, and UI elements to be theme-aware
  - Improved visual consistency across the application
  - Added theme selector to dashboard layout
  
- **Repository Management:**
  - Added `thumbnails/` directory to root `.gitignore` to exclude generated thumbnail files
  - Added `thumbnails/` to scraper `.gitignore` as well

**Where we are:**
- Complete themes system allows users to customize app appearance
- Thumbnail storage system enables local caching of images from scraped content
- Feed items now display thumbnails with proper URL resolution
- UI is fully theme-aware and customizable
- Storage system is extensible (ready for S3, FTP, etc. in the future)

**Next up:**
- Test thumbnail storage with real scraping jobs
- Verify theme persistence across sessions
- Consider adding more theme options
- Implement thumbnail optimization/compression
- Add thumbnail cleanup for old/unused images

---

## November 25, 2025

**What we did:**
- **Apify Integration:**
  - Added Apify provider support as alternative to ScraperAPI (`scraper/src/scrapers/apify.py`)
  - Fixed Apify API endpoint format (uses `~` instead of `/` in actor IDs for URLs)
  - Integrated Instagram Post Scraper actor (`apify/instagram-post-scraper`)
  - Updated provider factory to support multiple providers with auto-detection
  - Added environment variables: `APIFY_API_TOKEN`, `APIFY_API_URL`, `SCRAPER_PROVIDER`
  
- **Database Schema Updates:**
  - Added `hashtags` JSONB field to `feed_items` table (migration 004)
  - Added `thumbnail` TEXT field to `feed_items` table for image URLs
  - Updated FeedItem models in both Python (scraper) and Go (backend)
  
- **Scraper Service Improvements:**
  - Changed to single-run mode: runs once, processes all jobs, then exits gracefully
  - Added `RESULTS_LIMIT` global parameter (default: 5) for controlling items per request
  - Updated scheduler to only create jobs for profiles followed by users (joins with `user_social_profiles`)
  - Fixed timezone issues: all datetime operations now use timezone-aware datetimes
  - Improved database connection pooling with proper configuration
  - Fixed PostgreSQL enum comparison issue (cast enum to text for comparison)
  - Removed time-based filtering for debugging (scrapes all profiles regardless of last_scraped_at)
  
- **Instagram Parser Enhancements:**
  - Updated to handle both Apify (structured JSON) and ScraperAPI (HTML) formats
  - Fixed content_text population (handles None values, uses `caption` from Apify)
  - Added hashtags extraction and storage (from Apify array or extracted from text)
  - Added thumbnail extraction: uses `displayUrl` from Apify, with fallbacks to `images[0]`, `imageUrls[0]`, `thumbnailUrl`
  - Enhanced debug logging for troubleshooting
  
- **Backend Feed API:**
  - Created feed handler and service (`backend/src/handlers/feed_handler.go`, `backend/src/services/feed_service.go`)
  - Added `GET /api/feed` endpoint with pagination and filtering
  - Updated FeedItem model to include hashtags and thumbnail fields
  
- **CLI Tools:**
  - Created `replay_apify_run.py`: CLI tool to replay completed Apify runs and insert data into database
  - Supports automatic profile detection from run input or explicit profile ID

**Where we are:**
- Scraper supports both ScraperAPI and Apify providers (configurable via environment variables)
- Instagram Post Scraper integration complete with proper field mapping
- Feed items now store hashtags and thumbnail URLs
- Single-run mode makes testing and debugging easier
- Feed API endpoint ready for frontend integration
- Database schema updated with new fields

**Next up:**
- Test scraper with real Instagram profiles
- Verify hashtags and thumbnails are being saved correctly
- Build feed display UI in web app
- Implement image storage/optimization for thumbnails
- Re-enable time-based filtering after debugging

---

## November 22, 2025

**What we did:**
- Improved URL parsing flexibility in backend (`backend/src/db/url_parser.go`):
  - Now handles URLs without protocol (e.g., `twitter.com/username`, `instagram/user`)
  - Supports short formats (e.g., `twitter/username`, `instagram/user`)
  - Accepts just usernames (e.g., `@username` assumes Twitter)
  - Automatically strips query parameters, fragments, and trailing slashes
  - Handles `www.` prefix removal and normalizes `http://` to `https://`
  - Updated placeholder and help text to show flexible format examples
- Fixed frontend validation issue (`web/components/profiles/AddProfileForm.tsx`):
  - Changed input type from `"url"` to `"text"` to remove browser's strict URL validation
  - Users can now enter flexible URL formats without browser blocking submission
  - Backend parser handles all validation and normalization
- **Scraper Service Implementation:**
  - Created ScraperAPI provider implementation (`scraper/src/scrapers/scraperapi.py`):
    - Implements abstract `ScraperProvider` interface
    - Handles JavaScript rendering for dynamic social media pages
    - Includes rate limit tracking, error handling, and retry logic
    - Platform-specific optimizations for Instagram, Twitter, LinkedIn
  - Updated scraper module to auto-detect provider based on configuration
  - Added comprehensive verbose logging throughout the application:
    - Main application with startup/shutdown logging
    - Queue manager with job creation and status tracking
    - Worker with detailed per-job processing logs
    - Scheduler with profile selection reasoning
    - Parsers (Instagram, Twitter, LinkedIn) with per-post parsing details
    - Database queries with operation logging
    - Duplicate detector with similarity matching details
  - Fixed Python 3.13 compatibility issues:
    - Upgraded `psycopg2-binary` → `psycopg[binary]` (v3) for Python 3.13 support
    - Upgraded `sqlalchemy` from 2.0.23 → 2.0.44
    - Upgraded `typing-extensions` from 4.8.0 → 4.15.0
    - Commented out `python-Levenshtein` (optional dependency)
  - Fixed database connection to use `psycopg` driver (converts `postgresql://` to `postgresql+psycopg://`)
  - Fixed enum mapping issue with custom `TypeDecorator` for `PlatformType`:
    - Handles conversion between database strings and Python enum
    - Ensures lowercase values match database enum
  - Fixed dataclass field ordering in `ParsedFeedItem` (default values must come after required fields)
  - Created `run.py` entry point script for easy execution
  - Updated README with proper run instructions
- **Scraper Service Research:**
  - Conducted comprehensive comparison of 5 scraping services:
    - ScraperAPI (selected - cost-effective, reliable, simple integration)
    - Bright Data (enterprise option)
    - Apify (pre-built scrapers)
    - ScrapingBee (AI-powered)
    - Parse.bot (limited info)
  - Created detailed comparison tables with pricing, features, and capabilities

**Where we are:**
- Profile URL input is now user-friendly and accepts various input formats
- Backend parser robustly handles edge cases and normalizes URLs to canonical format
- Users can paste URLs in any common format and the system will parse them correctly
- Scraper service is fully implemented and ready to run
- ScraperAPI integration complete with error handling and retry logic
- All dependencies installed and compatible with Python 3.13
- Comprehensive logging system in place for debugging and monitoring
- Database enum mapping fixed to work with existing PostgreSQL enum
- Service can be run with `python3 run.py` from scraper directory

**Next up:**
- Configure `.env` file with database URL and ScraperAPI credentials
- Test scraper with actual social media profiles
- Verify data is being scraped and stored correctly
- Continue testing profile management with various URL formats
- Build out feed/aggregation functionality
- Implement scraping service integration

---

## November 20, 2025

**What we did:**
- Set up Supabase account and project
- Created comprehensive backend implementation plan (`docs/backend-implementation-plan.md`)
- Implemented backend foundation with GORM:
  - Database schema with SQL migrations (system-wide profile tracking, user lists, feed items)
  - All models with GORM tags and proper relationships
  - Database layer with GORM queries (replaced raw SQL)
  - Authentication service (signup, login, logout) with Supabase Auth
  - Profile service (add/follow profiles, system-wide profile management)
  - List service (create/manage lists, organize profiles)
  - HTTP handlers for all endpoints
  - Middleware (auth, CORS, error handling)
  - Complete route setup
- Refactored from raw SQL to GORM for automatic serialization/deserialization
- Fixed compilation errors and API compatibility issues
- Set up environment variable loading with godotenv
- Resolved database connection configuration (Supabase connection string)
- Initialized git repository (excluding code directories, tracking docs only)

**Where we are:**
- Backend API foundation is implemented and compiles successfully
- Database schema defined and ready to run migrations
- Database connection working
- Core backend structure in place (auth, profiles, lists)

**Next up:**
- Run database migrations in Supabase
- Build user profile functionality (UI for selecting media profiles to follow)
- Define scraping functionality:
  - Select scraping vendor/service
  - Set up periodic scraping jobs
  - Determine which accounts to scrape and how frequently
  - Implement scraping scheduling logic

---

## November 19, 2025

**What we did:**
- Finalized system architecture and tech stack decisions (Go + Gin, Next.js, React Native + Expo, Supabase)
- Scaffolded all three projects (backend, web, mobile) with proper structure
- Created draft/mockup of front-end design (landing page, auth pages, dashboard/feed view with mock data)
- Created architecture documentation

**Where we are:**
- All projects are scaffolded and runnable locally
- Front-end design draft/mockup provides visual reference (needs to be built out properly)
- Ready to start building authentication system

**Next up:**
- Backend authentication implementation (email auth, magic links, passkeys)
- Connect front-end to backend APIs

---
