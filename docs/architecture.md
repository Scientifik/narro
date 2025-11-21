# NARRO - System Architecture Document
**Session 1 Deliverable**  
**Date:** December 2024  
**Status:** ✅ Finalized

---

## 1. TECHNOLOGY STACK

### 1.1 Backend API
- **Language:** Go 1.21+
- **Framework:** Gin
- **Database Client:** Supabase Go client or direct PostgreSQL driver (pgx)
- **Deployment:** Railway
- **Rationale:** Maximum AI training data, excellent performance, simple deployment, standard library compatibility

### 1.2 Web Application
- **Framework:** Next.js 14+ (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **State Management:** React Context + TanStack Query (React Query)
- **Deployment:** Vercel
- **Rationale:** Maximum AI training data, excellent DX, built-in optimizations, can share patterns with React Native

### 1.3 Mobile Application
- **Framework:** React Native + Expo (managed workflow)
- **Language:** TypeScript
- **Navigation:** Expo Router (file-based routing)
- **State Management:** React Context + TanStack Query
- **Deployment:** Expo EAS Build
- **Rationale:** Maximum AI training data, easier setup than bare React Native, OTA updates, can share code patterns with Next.js

### 1.4 Database
- **Provider:** Supabase (PostgreSQL)
- **ORM/Query Builder:** Supabase Client (or direct SQL queries via Go driver)
- **Rationale:** Free tier, built-in auth, real-time capabilities, auto-generated REST API, standard PostgreSQL

### 1.5 Authentication
- **Provider:** Supabase Auth
- **Methods:** 
  - Email magic link (primary)
  - Passkey (WebAuthn)
  - Traditional password (optional)
- **Rationale:** Built into Supabase, handles all auth complexity, works across web and mobile

### 1.6 Payment Processing
- **Provider:** Stripe
- **Model:** Subscription ($5/month)
- **Webhooks:** Stripe webhooks to backend for subscription events

### 1.7 Web Scraping
- **Approach:** Third-party scraping API (microservice - to be defined in later session)
- **Integration:** Backend will call scraping API to trigger/fetch content
- **Rationale:** Saves development time, handles complexity, cost-effective

### 1.8 Monitoring & Analytics
- **Error Tracking:** Sentry (free tier: 5K events/month)
- **Analytics:** PostHog (free tier: 1M events/month)
- **Logging:** Structured logging in Go backend

---

## 2. REPOSITORY STRUCTURE

```
narro/
├── README.md
├── backend/              # Go API server
│   ├── src/
│   │   ├── routes/      # Gin route handlers
│   │   ├── handlers/    # Request handlers
│   │   ├── services/    # Business logic
│   │   ├── middleware/  # Auth, CORS, error handling
│   │   ├── models/      # Data models
│   │   ├── db/          # Database connection & queries
│   │   ├── types/       # TypeScript types (if needed)
│   │   └── main.go      # Entry point
│   ├── go.mod
│   ├── go.sum
│   └── .env.example
│
├── web/                  # Next.js web application
│   ├── app/             # Next.js App Router
│   │   ├── (auth)/      # Auth routes
│   │   ├── dashboard/   # Main app
│   │   ├── api/         # API routes (if needed)
│   │   └── layout.tsx
│   ├── components/      # React components
│   ├── lib/             # Utilities, Supabase client
│   ├── types/           # TypeScript types
│   ├── package.json
│   ├── tailwind.config.js
│   ├── next.config.js
│   └── .env.local.example
│
├── mobile/               # React Native + Expo app
│   ├── app/             # Expo Router pages
│   │   ├── (auth)/      # Auth screens
│   │   ├── (tabs)/      # Main app tabs
│   │   └── _layout.tsx
│   ├── components/      # React Native components
│   ├── lib/             # Utilities, API client
│   ├── types/           # TypeScript types
│   ├── package.json
│   ├── app.json
│   └── .env.example
│
└── docs/
    ├── architecture.md  # This document
    ├── api.md           # API documentation
    └── database-schema.md # Database schema
```

---

## 3. DATABASE SCHEMA

### 3.1 Tables

#### `users` (Supabase Auth - managed)
- `id` (UUID, primary key)
- `email` (string, unique)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### `user_profiles` (custom table)
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key → users.id)
- `display_name` (string, nullable)
- `avatar_url` (string, nullable)
- `subscription_status` (enum: 'active', 'canceled', 'past_due')
- `stripe_customer_id` (string, unique, nullable)
- `stripe_subscription_id` (string, unique, nullable)
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### `social_profiles` (profiles users follow)
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key → users.id)
- `platform` (enum: 'twitter', 'linkedin', 'instagram')
- `platform_username` (string) - e.g., "@elonmusk" or "elonmusk"
- `platform_user_id` (string, nullable) - platform's internal ID if available
- `display_name` (string, nullable)
- `avatar_url` (string, nullable)
- `is_active` (boolean, default: true)
- `last_scraped_at` (timestamp, nullable)
- `created_at` (timestamp)
- `updated_at` (timestamp)
- **Unique constraint:** (user_id, platform, platform_username)

#### `feed_items` (scraped posts)
- `id` (UUID, primary key)
- `social_profile_id` (UUID, foreign key → social_profiles.id)
- `platform` (enum: 'twitter', 'linkedin', 'instagram')
- `platform_post_id` (string) - unique ID from platform
- `content_text` (text) - post text content
- `content_html` (text, nullable) - original HTML if needed
- `media_urls` (jsonb, nullable) - array of image/video URLs
- `post_url` (string) - link to original post
- `author_username` (string)
- `author_display_name` (string, nullable)
- `author_avatar_url` (string, nullable)
- `posted_at` (timestamp) - when post was originally posted
- `scraped_at` (timestamp) - when we scraped it
- `created_at` (timestamp)
- **Unique constraint:** (platform, platform_post_id)

#### `subscription_events` (Stripe webhook events log)
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key → users.id)
- `stripe_event_id` (string, unique)
- `event_type` (string) - e.g., "customer.subscription.created"
- `event_data` (jsonb) - full event payload
- `processed` (boolean, default: false)
- `created_at` (timestamp)

### 3.2 Indexes
- `feed_items.posted_at` (DESC) - for chronological feed ordering
- `feed_items.social_profile_id` - for filtering by profile
- `social_profiles.user_id` - for user's followed profiles
- `social_profiles.last_scraped_at` - for scraping job queries
- `user_profiles.user_id` - for user profile lookups

---

## 4. API ARCHITECTURE

### 4.1 Backend API Structure

**Base URL:** `https://api.narro.app` (or Railway URL)

#### Authentication
- Uses Supabase JWT tokens
- All protected routes require `Authorization: Bearer <token>`
- Token validated via Supabase Go client or direct JWT verification

#### Endpoints

**Auth (handled by Supabase, but custom endpoints for mobile):**
- `POST /api/auth/signup` - Create account
- `POST /api/auth/login` - Login (magic link or password)
- `POST /api/auth/verify` - Verify magic link token
- `POST /api/auth/logout` - Logout

**User Profile:**
- `GET /api/user/profile` - Get current user profile
- `PATCH /api/user/profile` - Update profile

**Social Profiles:**
- `GET /api/social-profiles` - List user's followed profiles
- `POST /api/social-profiles` - Add a profile to follow
- `DELETE /api/social-profiles/:id` - Unfollow a profile
- `GET /api/social-profiles/search` - Search for profiles (optional)

**Feed:**
- `GET /api/feed` - Get unified feed
  - Query params: `?page=1&limit=20&before=<timestamp>`
- `GET /api/feed/refresh` - Trigger manual refresh

**Subscription:**
- `POST /api/subscription/create-checkout` - Create Stripe checkout session
- `GET /api/subscription/status` - Get subscription status
- `POST /api/subscription/cancel` - Cancel subscription
- `POST /api/subscription/webhook` - Stripe webhook handler

**Admin/Internal:**
- `POST /api/internal/scrape` - Trigger scraping via third-party API (internal)

### 4.2 Data Flow

1. **User adds profile:** Frontend → Backend API → Database
2. **Scraping:** Backend → Third-party Scraping API → Backend → Database
3. **Feed request:** Frontend → Backend API → Database → Aggregated response
4. **Payment:** Frontend → Stripe Checkout → Webhook → Backend → Database

---

## 5. WEB SCRAPING ARCHITECTURE

### 5.1 Scraping Strategy

**Approach:** Third-party scraping API (separate microservice)
- **Rationale:** Saves development time, handles complexity, cost-effective
- **Integration:** Backend will call scraping API to trigger/fetch content
- **To be defined:** Specific provider and integration details in later session

### 5.2 Scraping Flow (TBD - depends on API provider)

**General approach:**
1. User adds social profile
2. Backend calls scraping API to add profile to scraping queue
3. Scraping API periodically fetches content
4. Backend polls or receives webhooks from scraping API
5. Backend stores scraped content in database
6. Feed aggregates content from database

**Details to be determined:**
- Scraping API provider selection
- Integration method (REST API, webhooks, polling)
- Scheduling/triggering mechanism
- Data format and normalization

---

## 6. AUTHENTICATION FLOW

### 6.1 Web Flow
1. User enters email on login page
2. Click "Send magic link"
3. Supabase sends email with magic link
4. User clicks link → redirected to app with token
5. Token stored in localStorage/cookies
6. Token sent with all API requests

### 6.2 Mobile Flow
1. User enters email
2. Click "Send magic link"
3. Supabase sends email
4. User clicks link → deep link to app (or manual code entry)
5. Token stored in secure storage (Expo SecureStore)
6. Token sent with all API requests

### 6.3 Passkey Flow (Future)
- WebAuthn API
- Supabase handles implementation
- Same token-based auth after verification

---

## 7. MOBILE + WEB ARCHITECTURE

### 7.1 Shared Code Strategy

**TypeScript Types:**
- Shared types in each repo's `types/` directory
- Can be synced manually or via npm package (future)
- Same type definitions for API responses

**API Client:**
- Each platform has its own API client
- Same endpoints, different HTTP libraries
- Web: `fetch` or `axios`
- Mobile: `fetch` or `axios`

**State Management:**
- React Query for server state (both platforms)
- React Context for client state
- Same patterns, platform-specific UI components

### 7.2 Communication Patterns

**Web → Backend:**
- Direct API calls from Next.js
- Can use Next.js API routes as proxy if needed

**Mobile → Backend:**
- Direct API calls to backend URL
- Handle offline state with React Query cache

---

## 8. DEPLOYMENT ARCHITECTURE

### 8.1 Web (Vercel)
- **Build:** `npm run build`
- **Deploy:** Automatic on git push to main branch
- **Environment Variables:** Set in Vercel dashboard
- **Domain:** `narro.app` or `app.narro.app`

### 8.2 Backend (Railway)
- **Build:** `go build -o server`
- **Start:** `./server` or `go run main.go`
- **Environment Variables:** Set in Railway dashboard
- **Domain:** `api.narro.app` or Railway-provided URL

### 8.3 Mobile (Expo)
- **Development:** Expo Go app
- **Production:** EAS Build
- **Distribution:** App Store + Play Store
- **OTA Updates:** Expo Updates for JS bundle

---

## 9. ENVIRONMENT VARIABLES

### Backend (.env)
```
NODE_ENV=production
PORT=3000
DATABASE_URL=<supabase-connection-string>
SUPABASE_URL=<supabase-project-url>
SUPABASE_SERVICE_KEY=<supabase-service-key>
STRIPE_SECRET_KEY=<stripe-secret-key>
STRIPE_WEBHOOK_SECRET=<stripe-webhook-secret>
SENTRY_DSN=<sentry-dsn>
SCRAPING_API_URL=<scraping-api-url> (TBD)
SCRAPING_API_KEY=<scraping-api-key> (TBD)
```

### Web (.env.local)
```
NEXT_PUBLIC_SUPABASE_URL=<supabase-project-url>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<supabase-anon-key>
NEXT_PUBLIC_API_URL=<backend-api-url>
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=<stripe-publishable-key>
```

### Mobile (.env)
```
EXPO_PUBLIC_SUPABASE_URL=<supabase-project-url>
EXPO_PUBLIC_SUPABASE_ANON_KEY=<supabase-anon-key>
EXPO_PUBLIC_API_URL=<backend-api-url>
EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY=<stripe-publishable-key>
```

---

## 10. COST ESTIMATES

### Free Tier (First 100-200 users)
- **Supabase:** Free (500MB DB, 2GB bandwidth)
- **Vercel:** Free (hobby plan)
- **Railway:** Free tier or ~$5-10/month
- **Stripe:** 2.9% + $0.30 per transaction
- **Sentry:** Free (5K events/month)
- **PostHog:** Free (1M events/month)
- **Scraping API:** TBD (estimate $50-200/month)
- **Total:** ~$55-210/month

### Growth Tier (200-1000 users)
- **Supabase:** $25/month (Pro plan)
- **Vercel:** Free or $20/month (Pro)
- **Railway:** $20-50/month
- **Scraping API:** $200-500/month (scales with usage)
- **Total:** ~$265-595/month

---

## 11. SECURITY CONSIDERATIONS

1. **API Authentication:** All endpoints require Supabase JWT
2. **Rate Limiting:** Implement on backend (gin-rate-limit middleware)
3. **CORS:** Configure for web and mobile domains only
4. **Input Validation:** Validate all user inputs
5. **SQL Injection:** Use parameterized queries (Supabase/Go drivers handle this)
6. **XSS:** Sanitize scraped HTML content
7. **Secrets:** Never commit .env files, use platform secrets
8. **HTTPS:** Enforce HTTPS everywhere

---

## 12. DEVELOPMENT WORKFLOW

### 12.1 Local Development

**Backend:**
```bash
cd backend
go mod download
go run main.go
# Runs on http://localhost:3000
```

**Web:**
```bash
cd web
npm install
npm run dev
# Runs on http://localhost:3000
```

**Mobile:**
```bash
cd mobile
npm install
npx expo start
# Opens Expo Go app
```

### 12.2 AI-First Development Approach

- Use Claude Code to generate boilerplate and initial implementations
- Review and understand all generated code
- Iterate with AI to refine and fix issues
- Manual testing and debugging as needed

---

## 13. NEXT STEPS (Session 2)

1. Initialize three repositories (backend, web, mobile)
2. Set up Supabase project
3. Create database schema
4. Set up basic CI/CD
5. Get "Hello World" running on all three platforms

---

## DECISIONS LOG

| Date | Decision | Rationale |
|------|----------|-----------|
| [Today] | Go + Gin for backend | Maximum AI training data, excellent performance, standard library compatibility |
| [Today] | Next.js 14+ for web | Maximum AI training data, excellent DX, can share patterns with React Native |
| [Today] | React Native + Expo for mobile | Maximum AI training data, easier setup, OTA updates, shares patterns with Next.js |
| [Today] | Supabase for database | Free tier, built-in auth, real-time capabilities, standard PostgreSQL |
| [Today] | Third-party scraping API | Saves development time, handles complexity, cost-effective |
| [Today] | Separate repos | Clear separation, easier to manage |
| [Today] | Vercel for web | Optimized for Next.js, free tier |
| [Today] | Railway for backend | Simple deployment, good free tier, Go-friendly |
| [Today] | Expo EAS Build for mobile | Managed workflow, OTA updates |

---

## OPEN QUESTIONS / TODOs

- [ ] Select third-party scraping API provider
- [ ] Define scraping API integration details
- [ ] Set up Supabase project
- [ ] Purchase domain name
- [ ] Set up Stripe account
- [ ] Configure Sentry project
- [ ] Configure PostHog project

---

**Status:** ✅ Ready for Session 2 (Project Scaffolding)


