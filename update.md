# Narro Development Updates

Daily updates tracking progress on the Narro project. The README contains a rough session outline, but we're moving at our own pace based on what makes sense.

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
