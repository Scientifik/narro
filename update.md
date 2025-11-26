# Narro Development Updates

Daily updates tracking progress on the Narro project. The README contains a rough session outline, but we're moving at our own pace based on what makes sense.

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
