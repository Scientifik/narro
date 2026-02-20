# Narro System Diagrams -- AI Image Generation Prompts

**Purpose:** Each section below is a self-contained prompt for an image-generating AI to produce a professional system architecture diagram. Feed each section individually into the image generation tool. All diagrams should use a clean, modern style with clear labels, consistent spacing, and high contrast text on all backgrounds.

**Global Style Notes:**
- Use a dark charcoal (#1a1a2e) or deep navy (#16213e) background for all diagrams
- White or light gray text (#e0e0e0) for all labels
- Rounded rectangles for services and components
- Use subtle drop shadows for depth
- Monospaced font for technical labels (ports, file paths)
- Sans-serif font for headings and descriptions
- Minimum font size should ensure readability at 1200px wide
- All arrows should have labeled descriptions of what flows along them
- Include a small legend in the bottom-right corner of each diagram

---

## 1. Overall System Architecture

**Diagram Title:** "Narro -- System Architecture Overview"

**Description:** Create a system architecture diagram showing four main application components, their shared database, external services, and client devices. The layout should flow from left (clients) to right (external services), with the core infrastructure in the center.

**Components (Rounded Rectangles):**

1. **Web App** -- Color: Blue (#4361ee)
   - Label: "Web App"
   - Subtitle: "Next.js 16 / React 19 / TypeScript"
   - Sub-label: "Port 3000"
   - Icon suggestion: Globe or browser icon

2. **Mobile App** -- Color: Purple (#7209b7)
   - Label: "Mobile App"
   - Subtitle: "React Native / Expo / TypeScript"
   - Sub-label: "iOS + Android"
   - Icon suggestion: Smartphone icon

3. **Backend API** -- Color: Teal (#2ec4b6)
   - Label: "Backend API"
   - Subtitle: "Go / Gin Framework"
   - Sub-label: "Port 3030"
   - Icon suggestion: Server or gear icon

4. **Scraper Service** -- Color: Orange (#e76f51)
   - Label: "Scraper Service"
   - Subtitle: "Python 3.11+ / SQLAlchemy"
   - Sub-label: "Background Process"
   - Icon suggestion: Spider or download icon

**Infrastructure Components (Different Shape -- Cylinders for Storage, Rounded Rectangles for Services):**

5. **Database** -- Cylinder shape, Color: Green (#06d6a0)
   - Label: "Supabase PostgreSQL"
   - Subtitle: "Shared Database"
   - This should be positioned centrally, as both Backend and Scraper connect to it

6. **S3 Storage** -- Cylinder shape, Color: Gold (#ffd166)
   - Label: "S3-Compatible Storage"
   - Subtitle: "Thumbnails + Avatars"
   - Sub-label: "DigitalOcean Spaces / AWS S3"

7. **Supabase Auth** -- Rounded rectangle with lock icon, Color: Green (#06d6a0) lighter shade
   - Label: "Supabase Auth"
   - Subtitle: "JWT Authentication"

8. **Nginx Reverse Proxy** -- Rounded rectangle, Color: Dark Gray (#3d405b)
   - Label: "Nginx"
   - Subtitle: "Reverse Proxy / SSL"
   - Position between clients and Backend/Web

**External Services (Dashed Border Rounded Rectangles):**

9. **Apify** -- Color: Light Blue (#90e0ef), dashed border
   - Label: "Apify"
   - Subtitle: "Scraping Provider"

10. **ScraperAPI** -- Color: Light Blue (#90e0ef), dashed border
    - Label: "ScraperAPI"
    - Subtitle: "Scraping Provider (Fallback)"

11. **Stripe** -- Color: Light Purple (#c77dff), dashed border
    - Label: "Stripe"
    - Subtitle: "Payments (Planned)"

**Client Devices (Left Side):**

12. **Browser** -- Simple monitor icon, Color: White outline
    - Label: "Web Browser"

13. **Phone** -- Simple phone icon, Color: White outline
    - Label: "iOS / Android"

14. **RSS Reader** -- Simple RSS icon, Color: White outline (#f48c06)
    - Label: "RSS Reader"

**Arrows and Connections:**

- Browser --> Nginx: "HTTPS Requests"
- Phone --> Nginx: "HTTPS Requests"
- Nginx --> Web App: "Proxy :3000"
- Nginx --> Backend API: "Proxy :3030"
- Web App --> Backend API: "REST API Calls" (dashed arrow, internal)
- Mobile App --> Backend API: "REST API Calls"
- Backend API --> Database: "GORM Queries"
- Backend API --> Supabase Auth: "JWT Validation"
- Scraper Service --> Database: "SQLAlchemy Queries"
- Scraper Service --> Apify: "Scraping Requests"
- Scraper Service --> ScraperAPI: "Fallback Requests" (dashed arrow)
- Scraper Service --> S3 Storage: "Upload Thumbnails + Avatars"
- Web App --> S3 Storage: "Fetch Thumbnails" (dashed arrow, direct CDN)
- Mobile App --> S3 Storage: "Fetch Thumbnails" (dashed arrow, direct CDN)
- RSS Reader --> Backend API: "/feed/{id}.rss"
- Backend API --> Stripe: "Webhooks" (dashed arrow, both directions)

**Layout Notes:**
- Clients on the far left
- Nginx as the gateway, slightly left of center
- Web App and Backend API in the center
- Database between Backend and Scraper
- Scraper on the right side
- External services (Apify, ScraperAPI, Stripe) on the far right
- S3 Storage below center, accessible by Scraper, Web, and Mobile

**Legend:**
- Solid arrow: Direct communication
- Dashed arrow: Indirect or CDN-based communication
- Solid border: Internal service
- Dashed border: External third-party service
- Cylinder: Data storage
- Rounded rectangle: Application service

---

## 2. Data Flow Diagram -- User Adds a Profile

**Diagram Title:** "Narro -- Data Flow: Adding a Social Profile"

**Description:** Create a sequence-style data flow diagram showing what happens when a user adds a social media profile to follow. The flow progresses from left to right, top to bottom, showing the complete lifecycle from user input to scraped content appearing in their feed.

**Swim Lanes (Horizontal Bands):**

1. **User Layer** -- Color: Blue (#4361ee), top band
2. **Frontend Layer** -- Color: Purple (#7209b7), second band
3. **Backend Layer** -- Color: Teal (#2ec4b6), third band
4. **Database Layer** -- Color: Green (#06d6a0), fourth band
5. **Scraper Layer** -- Color: Orange (#e76f51), bottom band

**Steps (Numbered Circles Connected by Arrows):**

Step 1: User enters a profile URL
- Location: User Layer
- Shape: Circle with "1"
- Label: "User enters URL"
- Sub-label: "Flexible formats: @user, twitter.com/user, etc."

Step 2: Frontend sends POST request
- Location: Frontend Layer
- Shape: Circle with "2"
- Label: "POST /api/profiles"
- Sub-label: "{ url: '...', feed_id: '...' }"
- Arrow from Step 1 to Step 2: "Submit form"

Step 3: Backend parses URL
- Location: Backend Layer
- Shape: Circle with "3"
- Label: "URL Parser"
- Sub-label: "Normalize to canonical URL"
- Arrow from Step 2 to Step 3: "HTTP Request"

Step 4: Check if profile exists in database
- Location: Backend Layer
- Shape: Diamond (decision) with "4"
- Label: "Profile exists?"
- Arrow from Step 3 to Step 4: "Lookup (platform, username)"

Step 4a: Profile exists -- reuse it
- Location: Database Layer
- Shape: Circle with "4a"
- Label: "Return existing social_profile"
- Arrow from Step 4 to Step 4a: "YES -- reuse"

Step 4b: Profile does not exist -- create it
- Location: Database Layer
- Shape: Circle with "4b"
- Label: "INSERT into social_profiles"
- Arrow from Step 4 to Step 4b: "NO -- create new"

Step 5: Create user-profile relationship
- Location: Database Layer
- Shape: Circle with "5"
- Label: "INSERT into user_feed_profiles"
- Sub-label: "Links user + profile + feed"
- Arrow from Step 4a to Step 5
- Arrow from Step 4b to Step 5

Step 6: Return profile data to frontend
- Location: Frontend Layer
- Shape: Circle with "6"
- Label: "Display profile in feed"
- Arrow from Step 5 to Step 6: "JSON Response"

Step 7: Scraper picks up new profile (asynchronous, shown below a time divider)
- Location: Scraper Layer
- Shape: Circle with "7"
- Label: "Scheduler creates job"
- Sub-label: "Checks scrape_frequency_hours"
- Arrow from Step 5 to Step 7: "Async (next scheduler run)" -- dashed line

Step 8: Scraper fetches content
- Location: Scraper Layer
- Shape: Circle with "8"
- Label: "Apify / ScraperAPI"
- Sub-label: "Platform-specific scraping"
- Arrow from Step 7 to Step 8: "Process job"

Step 9: Parse and store results
- Location: Database Layer
- Shape: Circle with "9"
- Label: "INSERT feed_items"
- Sub-label: "Content, hashtags, thumbnails"
- Arrow from Step 8 to Step 9: "Parsed data"

Step 10: Upload media to S3
- Location: Scraper Layer (with arrow going to a small S3 icon)
- Shape: Circle with "10"
- Label: "Upload to S3"
- Sub-label: "Thumbnails + avatars"
- Arrow from Step 8 to Step 10: "Media files"

Step 11: User sees content in feed
- Location: User Layer
- Shape: Circle with "11"
- Label: "Feed populated"
- Sub-label: "Chronological posts appear"
- Arrow from Step 9 to Step 11: "Next page load" -- dashed line

**Style Notes:**
- Use a timeline progression from left to right
- Clearly separate the synchronous flow (Steps 1-6) from the asynchronous flow (Steps 7-11) with a vertical dashed line labeled "Asynchronous Boundary"
- Each arrow should have a small label
- Use consistent circle sizes for steps and a diamond for the decision point

---

## 3. Database Schema Diagram (Entity-Relationship)

**Diagram Title:** "Narro -- Database Schema (Entity-Relationship Diagram)"

**Description:** Create an entity-relationship diagram showing the key database tables, their columns, data types, and relationships. Use crow's foot notation for cardinality. Group related tables visually.

**Color Coding by Domain:**

- User Domain: Blue (#4361ee)
- Social Profile Domain: Teal (#2ec4b6)
- Feed Domain: Purple (#7209b7)
- Content Domain: Orange (#e76f51)
- Scraper Domain: Red (#e63946)
- Platform Domain: Gray (#6c757d)

**Tables (Rectangles with Header Bar):**

### User Domain (Blue)

**auth.users** (managed by Supabase -- shown with dashed border)
| Column | Type | Constraints |
| id | UUID | PK |
| email | TEXT | UNIQUE |
| created_at | TIMESTAMPTZ | |

**user_profiles**
| Column | Type | Constraints |
| id | UUID | PK, FK -> auth.users.id |
| home_feed_id | UUID | FK -> feeds.id, NULLABLE |
| homepage_display_mode | VARCHAR(20) | DEFAULT 'specific_feed' |
| is_admin | BOOLEAN | DEFAULT false |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE (soft delete) |

### Platform Domain (Gray)

**platforms**
| Column | Type | Constraints |
| id | UUID | PK |
| name | TEXT | UNIQUE, NOT NULL |
| display_name | TEXT | NOT NULL |
| description | TEXT | NULLABLE |
| is_active | BOOLEAN | DEFAULT true |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### Social Profile Domain (Teal)

**social_profiles**
| Column | Type | Constraints |
| id | UUID | PK |
| platform | UUID | FK -> platforms.id, NOT NULL |
| username | TEXT | NOT NULL |
| url | TEXT | NOT NULL |
| display_name | TEXT | NULLABLE |
| avatar_url | TEXT | NULLABLE |
| follower_count | INTEGER | NULLABLE |
| last_scraped_at | TIMESTAMPTZ | NULLABLE |
| scrape_frequency_hours | INTEGER | DEFAULT 24 |
| is_active | BOOLEAN | DEFAULT true |
| rss_feed_url | TEXT | NULLABLE |
| categorization_status | TEXT | DEFAULT 'pending' |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE |
- UNIQUE(platform, username)

### Feed Domain (Purple)

**feeds**
| Column | Type | Constraints |
| id | UUID | PK |
| user_id | UUID | FK -> user_profiles.id, NOT NULL |
| name | TEXT | NOT NULL |
| color | TEXT | NULLABLE |
| emoji | TEXT | NULLABLE |
| custom_image_url | TEXT | NULLABLE |
| description | TEXT | NULLABLE |
| rss_feed_url | TEXT | NULLABLE |
| is_default | BOOLEAN | DEFAULT false |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE |
- UNIQUE(user_id, name)

**user_feed_profiles** (Consolidated Junction Table)
| Column | Type | Constraints |
| id | UUID | PK |
| user_id | UUID | FK -> user_profiles.id, NOT NULL |
| social_profile_id | UUID | FK -> social_profiles.id, NOT NULL |
| feed_id | UUID | FK -> feeds.id, NULLABLE |
| is_favorited | BOOLEAN | DEFAULT false |
| import_job_id | UUID | FK -> profile_import_jobs.id, NULLABLE |
| source_social_profile_id | UUID | FK -> social_profiles.id, NULLABLE |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE |
- Note: feed_id = NULL means "unassigned" (followed but not in any feed)
- UNIQUE(user_id, social_profile_id) WHERE feed_id IS NULL
- UNIQUE(user_id, social_profile_id, feed_id) WHERE feed_id IS NOT NULL

**feed_configurations**
| Column | Type | Constraints |
| id | UUID | PK |
| feed_id | UUID | FK -> feeds.id, UNIQUE |
| view_type | ENUM | 'list', 'grid', 'gallery' |
| card_style | ENUM | 'compact', 'expanded', 'minimal' |
| background_image_url | TEXT | NULLABLE |
| auto_refresh_enabled | BOOLEAN | DEFAULT true |
| auto_refresh_interval_seconds | INTEGER | DEFAULT 60 |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE |

### Content Domain (Orange)

**feed_items**
| Column | Type | Constraints |
| id | UUID | PK |
| social_profile_id | UUID | FK -> social_profiles.id, NOT NULL |
| platform_post_id | TEXT | NOT NULL |
| content_text | TEXT | NOT NULL |
| content_html | TEXT | NULLABLE |
| media_urls | JSONB | NULLABLE |
| hashtags | JSONB | NULLABLE |
| thumbnail | TEXT | NULLABLE |
| post_url | TEXT | NOT NULL |
| posted_at | TIMESTAMPTZ | NOT NULL |
| scraped_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE |
- UNIQUE(social_profile_id, platform_post_id)

**feed_item_duplicates**
| Column | Type | Constraints |
| id | UUID | PK |
| feed_item_id_1 | UUID | FK -> feed_items.id |
| feed_item_id_2 | UUID | FK -> feed_items.id |
| similarity_score | FLOAT | |
| match_reason | TEXT | |
| detected_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | |
- UNIQUE(feed_item_id_1, feed_item_id_2)
- CHECK(feed_item_id_1 != feed_item_id_2)

### Scraper Domain (Red)

**scraping_jobs**
| Column | Type | Constraints |
| id | UUID | PK |
| social_profile_id | UUID | FK -> social_profiles.id, NOT NULL |
| status | VARCHAR(20) | 'pending', 'processing', 'completed', 'failed' |
| priority | INTEGER | DEFAULT 0 |
| scheduled_at | TIMESTAMPTZ | NOT NULL |
| started_at | TIMESTAMPTZ | NULLABLE |
| completed_at | TIMESTAMPTZ | NULLABLE |
| error_message | TEXT | NULLABLE |
| retry_count | INTEGER | DEFAULT 0 |
| max_retries | INTEGER | DEFAULT 3 |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| deleted_at | TIMESTAMPTZ | NULLABLE |

**profile_import_jobs**
| Column | Type | Constraints |
| id | UUID | PK |
| user_id | UUID | FK -> user_profiles.id, NOT NULL |
| source_social_profile_id | UUID | FK -> social_profiles.id, NOT NULL |
| platform_id | UUID | FK -> platforms.id, NOT NULL |
| assignment_method | ENUM | 'all_to_feed', 'cherry_pick' |
| target_feed_id | UUID | FK -> feeds.id, NULLABLE |
| source_url | TEXT | NOT NULL |
| skip_existing | BOOLEAN | DEFAULT true |
| status | ENUM | 'pending', 'processing', 'completed', 'failed', 'private' |
| error_message | TEXT | NULLABLE |
| profiles_discovered | INTEGER | DEFAULT 0 |
| profiles_added | INTEGER | DEFAULT 0 |
| skipped_existing | INTEGER | DEFAULT 0 |
| retry_count | INTEGER | DEFAULT 0 |
| max_retries | INTEGER | DEFAULT 3 |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| completed_at | TIMESTAMPTZ | NULLABLE |

**Relationships (Crow's Foot Notation):**

- auth.users ||--o| user_profiles : "1:1 extends"
- user_profiles ||--o{ feeds : "1:many owns"
- user_profiles |o--o| feeds : "1:0..1 home_feed_id"
- user_profiles ||--o{ user_feed_profiles : "1:many"
- social_profiles ||--o{ user_feed_profiles : "1:many"
- feeds |o--o{ user_feed_profiles : "0..1:many (NULL = unassigned)"
- feeds ||--o| feed_configurations : "1:0..1"
- social_profiles ||--o{ feed_items : "1:many"
- social_profiles ||--o{ scraping_jobs : "1:many"
- feed_items ||--o{ feed_item_duplicates : "1:many (as item_1 or item_2)"
- platforms ||--o{ social_profiles : "1:many"
- user_profiles ||--o{ profile_import_jobs : "1:many"
- social_profiles ||--o{ profile_import_jobs : "1:many (source)"
- platforms ||--o{ profile_import_jobs : "1:many"
- feeds |o--o{ profile_import_jobs : "0..1:many (target)"
- profile_import_jobs |o--o{ user_feed_profiles : "0..1:many (import tracking)"

**Layout Notes:**
- Place auth.users and user_profiles at the top left
- Place platforms at the top center
- Place social_profiles below platforms, in the center
- Place feeds to the left of social_profiles
- Place user_feed_profiles between feeds and social_profiles (this is the core junction)
- Place feed_items below social_profiles
- Place scraping_jobs and profile_import_jobs at the bottom
- Place feed_configurations attached to feeds
- Place feed_item_duplicates attached to feed_items
- Emphasize user_feed_profiles as the central hub with a slightly larger or highlighted border -- it connects users, profiles, and feeds

---

## 4. Authentication Flow Diagram

**Diagram Title:** "Narro -- Authentication Flow"

**Description:** Create a flow diagram showing how authentication works across web and mobile clients, using Supabase Auth with JWT tokens. Show two parallel flows side by side: Web (left) and Mobile (right), converging at the shared backend.

**Left Side -- Web Authentication Flow:**

Color theme: Blue (#4361ee)

Step W1: "User visits login page"
- Shape: Rounded rectangle
- Label: "/login route"

Step W2: "User enters email + password"
- Shape: Rounded rectangle
- Label: "Login form submission"

Step W3: "Supabase Auth SDK"
- Shape: Rounded rectangle with lock icon
- Label: "supabase.auth.signInWithPassword()"
- Sub-label: "Client-side SDK call"

Step W4: "Supabase returns JWT"
- Shape: Rounded rectangle
- Label: "Access token + Refresh token"

Step W5: "Token stored in localStorage"
- Shape: Rounded rectangle
- Label: "Browser localStorage"
- Sub-label: "Managed by Auth Context"

Step W6: "API requests include Bearer token"
- Shape: Rounded rectangle
- Label: "Authorization: Bearer <jwt>"

**Right Side -- Mobile Authentication Flow:**

Color theme: Purple (#7209b7)

Step M1: "User opens app"
- Shape: Rounded rectangle
- Label: "Auth screen"

Step M2: "User enters email + password"
- Shape: Rounded rectangle
- Label: "Login form submission"

Step M3: "Supabase Auth SDK"
- Shape: Rounded rectangle with lock icon
- Label: "supabase.auth.signInWithPassword()"
- Sub-label: "React Native SDK call"

Step M4: "Supabase returns JWT"
- Shape: Rounded rectangle
- Label: "Access token + Refresh token"

Step M5: "Token stored in SecureStore"
- Shape: Rounded rectangle
- Label: "Expo SecureStore"
- Sub-label: "Encrypted device storage"

Step M6: "API requests include Bearer token"
- Shape: Rounded rectangle
- Label: "Authorization: Bearer <jwt>"

**Shared Backend Flow (Center-Bottom):**

Color theme: Teal (#2ec4b6)

Step B1: "Nginx receives request"
- Shape: Rounded rectangle, dark gray
- Label: "SSL Termination + Proxy"

Step B2: "Auth Middleware"
- Shape: Diamond (decision)
- Label: "Valid JWT?"

Step B2a: "Extract user_id from 'sub' claim"
- Shape: Rounded rectangle
- Label: "Parse JWT claims"
- Sub-label: "ParseUnverified (trusts Supabase)"

Step B2b: "Return 401 Unauthorized"
- Shape: Rounded rectangle, red (#e63946)
- Label: "Reject request"

Step B3: "Set user_id in request context"
- Shape: Rounded rectangle
- Label: "c.Set('user_id', userID)"

Step B4: "Handler processes request"
- Shape: Rounded rectangle
- Label: "Authorized endpoint"

**External Service:**

Step S1: "Supabase Auth Service"
- Shape: Cloud shape, Green (#06d6a0)
- Label: "Supabase Auth"
- Sub-label: "auth.users table, JWT signing"
- Position: Top center, between Web and Mobile flows

**Arrows:**

- W1 -> W2: "User interaction"
- W2 -> W3: "Credentials"
- W3 -> S1: "Authentication request" (arrow going up to cloud)
- S1 -> W4: "JWT tokens" (arrow coming down from cloud)
- W4 -> W5: "Persist"
- W5 -> W6: "Attach to requests"
- W6 -> B1: "HTTPS"

- M1 -> M2: "User interaction"
- M2 -> M3: "Credentials"
- M3 -> S1: "Authentication request" (arrow going up to cloud)
- S1 -> M4: "JWT tokens" (arrow coming down from cloud)
- M4 -> M5: "Persist"
- M5 -> M6: "Attach to requests"
- M6 -> B1: "HTTPS"

- B1 -> B2: "Forward request"
- B2 -> B2a: "YES -- valid token"
- B2 -> B2b: "NO -- invalid/missing"
- B2a -> B3: "User identified"
- B3 -> B4: "Proceed"

**Key Callout Box (Bottom):**
- "JWT Structure: { sub: user_uuid, exp: timestamp, ... }"
- "Token refresh handled automatically by Supabase SDK"
- "Backend uses ParseUnverified -- trusts Supabase-issued tokens"

---

## 5. Scraping Pipeline Diagram

**Diagram Title:** "Narro -- Scraping Pipeline"

**Description:** Create a pipeline diagram showing the complete lifecycle of how social media content gets scraped, processed, stored, and eventually served to users. This should look like an industrial pipeline with stages flowing left to right.

**Pipeline Stages (Large Rounded Rectangles Connected by Thick Arrows):**

### Stage 1: Scheduling
Color: Blue (#4361ee)
Shape: Large rounded rectangle

Internal components (smaller boxes inside):
- "Scheduler" -- checks social_profiles table
- "Frequency Check" -- compares last_scraped_at vs scrape_frequency_hours
- "Job Creation" -- inserts into scraping_jobs table
- "Priority Queue" -- orders by priority and scheduled_at

Labels on exit arrow: "Pending Jobs"

Annotation below: "Formula: scrape_frequency_hours = 84 / posts_per_week"

### Stage 2: Job Processing
Color: Teal (#2ec4b6)
Shape: Large rounded rectangle

Internal components:
- "Worker Pool" -- MAX_CONCURRENT_JOBS workers
- "Platform Config Loader" -- loads platform-specific settings
- "Provider Selection" -- decision diamond inside
  - Path A: "Apify" (primary)
  - Path B: "ScraperAPI" (fallback)
- "Fallback Logic" -- if primary fails, try secondary

Labels on exit arrow: "Raw HTML / JSON Data"

Annotation below: "Supports: Twitter, Instagram, LinkedIn, Reddit, Facebook"

### Stage 3: Parsing
Color: Purple (#7209b7)
Shape: Large rounded rectangle

Internal components:
- "Platform Router" -- selects correct parser
- "Instagram Parser" -- handles Apify JSON format
- "Twitter Parser" -- handles both Apify and ScraperAPI formats
- "LinkedIn Parser" -- handles both formats
- "Base Parser Interface" -- shared extraction methods

Output boxes:
- "Content Text"
- "Media URLs"
- "Hashtags"
- "Thumbnails"
- "Post Metadata"

Labels on exit arrow: "ParsedFeedItem objects"

### Stage 4: Storage
Color: Orange (#e76f51)
Shape: Large rounded rectangle split into two sub-sections

Sub-section A: "Database Storage"
- "Upsert feed_items" -- ON CONFLICT DO UPDATE
- "Update social_profiles.last_scraped_at"
- "Mark scraping_job as completed"
- Icon: Cylinder (database)

Sub-section B: "Media Storage"
- "Download thumbnails"
- "Download avatars"
- "Upload to S3" -- path: {job_id}/{uuid}.jpg
- Icon: Cloud with up arrow

Labels on exit arrow: "Stored Content"

### Stage 5: Duplicate Detection
Color: Red (#e63946)
Shape: Large rounded rectangle

Internal components:
- "Cross-Platform Scanner" -- compares new items with existing
- "Similarity Scoring" -- text comparison
- "Relationship Storage" -- inserts into feed_item_duplicates
- "Threshold Check" -- similarity_score evaluation

Labels on exit arrow: "Clean, deduplicated content"

Annotation below: "Duplicates preserved but linked -- frontend decides presentation"

### Stage 6: Serving
Color: Green (#06d6a0)
Shape: Large rounded rectangle

Internal components:
- "GET /api/feed" -- paginated feed endpoint
- "GET /api/feed/wide-mode" -- all feeds aggregated
- "GET /feed/{id}.rss" -- RSS 2.0 generation
- "Frontend Filtering" -- date, profile, hashtag, starred
- "S3 CDN" -- direct thumbnail access

Labels: "To Users"

**Below the Pipeline -- Data Sources (Top) and Outputs (Bottom):**

Data Sources (above Stage 2, with arrows pointing down into it):
- Twitter/X icon
- Instagram icon
- LinkedIn icon
- Reddit icon
- Facebook icon
- Label: "Social Media Platforms"

Outputs (below Stage 6, with arrows pointing down from it):
- "Web App Feed View"
- "Mobile App Feed View"
- "RSS Feed Readers"

**Timing Annotations (Above the Pipeline):**
- Between Stage 1 and Stage 2: "Every SCHEDULER_INTERVAL_MINUTES (default: 5)"
- Above Stage 2: "MAX_CONCURRENT_JOBS (default: 10)"
- Above Stage 4: "Batch insert with ON CONFLICT"

**CLI Commands (Small Box at Bottom-Left):**
```
python3 run.py scrape --platform twitter --limit 50
python3 run.py avatars --platform instagram --limit 10
python3 run.py update_frequency --platform twitter
python3 run.py serve --port 8000
```

---

## 6. Feed Customization System Diagram

**Diagram Title:** "Narro -- Feed Customization System"

**Description:** Create a diagram showing how users create, organize, and customize their feeds. This should illustrate the relationship between users, feeds, profiles, and customization options. Use a combination of structural layout (showing data relationships) and visual examples (showing what each customization looks like).

**Top Section -- User's Feed Library:**

Show a user icon on the far left with lines branching out to multiple feed cards arranged in a horizontal row:

Feed Card 1 (Default):
- Color: Gray border
- Label: "All Profiles"
- Badge: "Default"
- Sub-label: "Auto-created on signup, cannot be deleted"

Feed Card 2:
- Color: Blue border
- Emoji: Sports emoji
- Label: "Sports News"
- Sub-label: "12 profiles"

Feed Card 3:
- Color: Green border
- Custom image icon
- Label: "Tech Leaders"
- Sub-label: "8 profiles, 3 starred"

Feed Card 4:
- Color: Purple border
- Emoji: Art emoji
- Label: "Design Inspiration"
- Sub-label: "5 profiles"

**Middle Section -- Customization Options Panel:**

Show a settings panel expanding from one of the feed cards with these configurable properties:

Group A: "Feed Identity"
- Name: text input
- Emoji: emoji picker
- Custom Image URL: image upload
- Color: color picker
- Description: text area

Group B: "Display Configuration" (from feed_configurations table)
- View Type: Radio buttons showing "List | Grid | Gallery"
- Card Style: Radio buttons showing "Compact | Expanded | Minimal"
- Background Image: URL input
- Auto-Refresh: Toggle switch (ON/OFF)
- Auto-Refresh Interval: Number input (seconds)

Group C: "Profile Management"
- List of profiles in the feed
- Star icon next to each (favoriting)
- Add/Remove profile buttons
- Import profiles button

**Bottom Section -- View Type Examples:**

Show three side-by-side mockup boxes representing the three view types:

View Type: List
- Vertical stack of content cards
- Full text content visible
- Small thumbnail on the right
- Profile avatar and name on each card
- Label: "List View -- Best for text-heavy content"

View Type: Grid
- 2x2 or 3x3 grid of cards
- Thumbnails prominent
- Truncated text
- Label: "Grid View -- Balanced layout"

View Type: Gallery
- Large image tiles
- Minimal text overlay
- Instagram/Pinterest-like layout
- Label: "Gallery View -- Image-focused browsing"

**Data Flow Arrows (Right Side):**

Show the data flow for how customization is stored:

"Feed Identity" --> feeds table
- Arrow label: "PATCH /api/feeds/{id}"
- Fields: name, emoji, custom_image_url, color, description

"Display Configuration" --> feed_configurations table
- Arrow label: "PATCH /api/feeds/{id}/feed-config"
- Fields: view_type, card_style, background_image_url, etc.

"Profile Starring" --> user_feed_profiles table
- Arrow label: "POST /api/feeds/{id}/profiles/{pid}/star"
- Field: is_favorited = true

"Home Feed Selection" --> user_profiles table
- Arrow label: "PATCH /api/user/home-feed"
- Field: home_feed_id

**Key Relationships Box:**

Show a small ER snippet emphasizing:
- One user owns many feeds
- Each feed has zero or one configuration
- Each feed contains many profiles (via user_feed_profiles)
- Profiles can be in multiple feeds (same social_profile_id, different feed_id)
- Profiles not in any feed have feed_id = NULL (unassigned)
- A user can star a profile per-feed (is_favorited on user_feed_profiles)
- One feed can be designated as the home feed (user_profiles.home_feed_id)

**RSS Integration Callout:**

Small box in the corner:
- "Each feed generates an RSS 2.0 endpoint"
- "URL: /feed/{feed_id}.rss"
- "Compatible with any RSS reader"
- RSS icon in orange (#f48c06)

---

## 7. Deployment Architecture Diagram

**Diagram Title:** "Narro -- Deployment Architecture"

**Description:** Create a deployment infrastructure diagram showing how the application is deployed across servers with Docker containers, CI/CD pipeline, and external services.

**Left Side -- Developer Workflow:**

Step D1: "Developer"
- Icon: Person with laptop
- Arrow to: "Git Push to main"

Step D2: "Gitea Repository"
- Shape: Rounded rectangle, dark gray
- Label: "Source Code"
- Sub-label: "Separate repos: backend, web, scraper"

Step D3: "Gitea Actions"
- Shape: Rounded rectangle, blue (#4361ee)
- Label: "CI/CD Pipeline"
- Internal steps shown as small boxes:
  - "Build Docker Image"
  - "Tag: latest + commit SHA"
  - "Push to Registry"
  - "Deploy via SSH"

**Center -- Container Registry:**

Step R1: "Vultr Container Registry"
- Shape: Cylinder, gold (#ffd166)
- Label: "Container Registry"
- Internal items:
  - "narro-backend:latest"
  - "narro-web:latest"
  - "narro-scraper:latest"

**Right Side -- Production Servers:**

Server 1: "Backend Server"
- Shape: Large rectangle with server icon
- Label: "Ubuntu 22.04 LTS"
- Sub-label: "Vultr VPS"
- Internal Docker containers (smaller rounded rectangles):
  - "narro-backend" -- Teal (#2ec4b6), Port 3030
  - "Nginx" -- Dark gray, Ports 80/443
- Health check indicator (small green circle)

Server 2: "Frontend Server"
- Shape: Large rectangle with server icon
- Label: "Ubuntu 22.04 LTS"
- Sub-label: "Vultr VPS"
- Internal Docker containers:
  - "narro-web" -- Blue (#4361ee), Port 3000
  - "Nginx" -- Dark gray, Ports 80/443
- Health check indicator (small green circle)

Standalone: "Scraper (Cron)"
- Shape: Small rectangle with clock icon, Orange (#e76f51)
- Label: "Runs on-demand via cron"
- Sub-label: "Not a long-running service"

**External Services (Bottom):**

Row of service boxes with dashed borders:
- "Supabase" -- Green, label: "PostgreSQL + Auth"
- "DigitalOcean Spaces" -- Blue, label: "S3 Storage"
- "Apify" -- Light blue, label: "Scraping"
- "Let's Encrypt" -- Blue, label: "SSL Certificates"
- "Plausible" -- Purple, label: "Analytics"
- "Sentry" -- Red, label: "Error Tracking"

**Connections:**

- D1 -> D2: "git push"
- D2 -> D3: "Triggers workflow"
- D3 -> R1: "Push images"
- D3 -> Server 1: "SSH deploy"
- D3 -> Server 2: "SSH deploy"
- R1 -> Server 1: "docker pull"
- R1 -> Server 2: "docker pull"
- "Internet" cloud -> Server 1 Nginx: "api.narro.app"
- "Internet" cloud -> Server 2 Nginx: "app.narro.app"
- Server 1 -> Supabase: "Database queries"
- Scraper -> Supabase: "Database queries"
- Scraper -> DigitalOcean Spaces: "Upload media"
- Scraper -> Apify: "Scraping API"
- Server 2 -> Server 1: "API calls (internal)"

**Annotations:**
- "Zero-downtime deployment with health checks"
- "Images tagged with both 'latest' and commit SHA"
- "Docker Compose manages container lifecycle"

---

## 8. Wide Mode and Feed Aggregation Diagram

**Diagram Title:** "Narro -- Feed Aggregation and Display Modes"

**Description:** Create a diagram showing how content from multiple feeds is aggregated and displayed in different viewing modes. This should illustrate the difference between individual feed view, home feed view, and wide mode.

**Top Section -- User's Profile Library:**

Show a horizontal row of social media profile icons grouped by platform:
- Twitter profiles (3-4 icons, blue)
- Instagram profiles (3-4 icons, pink/purple)
- LinkedIn profiles (2-3 icons, blue)
- Reddit profiles (2-3 icons, orange)

Arrows flow down from profiles into feeds.

**Middle Section -- Feed Organization:**

Show three feed containers side by side:

Feed A: "Tech News"
- Contains: 4 Twitter profiles, 2 LinkedIn profiles
- Color: Blue

Feed B: "Photography"
- Contains: 3 Instagram profiles, 1 Twitter profile
- Color: Green

Feed C: "Industry"
- Contains: 2 LinkedIn profiles, 2 Reddit profiles
- Color: Purple

Note: Some profiles appear in multiple feeds (show with dotted connectors)
Note: Some profiles are unassigned (shown floating above feeds with "Unassigned" label)

**Bottom Section -- Three Display Modes (Side by Side):**

Mode 1: "Individual Feed View"
- Endpoint: "GET /api/feed?feed_id={id}"
- Shows a single feed's content in a scrollable list
- Posts labeled with profile avatar and name
- Starred profiles have a star icon
- Filter bar: Date | Profile | Hashtag | Starred
- Label: "Single feed -- user chooses view type (list/grid/gallery)"

Mode 2: "Home Feed"
- Endpoint: "GET /api/feed?feed_id={home_feed_id}"
- Shows the user's designated home feed
- Loads automatically on dashboard
- Setting: "Set via PATCH /api/user/home-feed"
- Label: "Default landing page -- configurable per user"

Mode 3: "Wide Mode"
- Endpoint: "GET /api/feed/wide-mode"
- Shows ALL posts from ALL feeds combined
- Each post has a feed attribution badge showing which feed it belongs to
- Chronological ordering across all feeds
- Label: "All feeds combined -- unified chronological view"

**Arrows and Flow:**
- Feed A, B, C all have arrows into Mode 1 (one at a time)
- A single feed (highlighted) has an arrow into Mode 2 with "home_feed_id" label
- All feeds have arrows converging into Mode 3

**Frontend Filtering Callout Box:**
- "All filtering happens client-side"
- "Backend returns complete dataset"
- "Filters: Date range, Profile, Hashtag, Starred status"
- "Applied after data loads in the browser"

---

## General Notes for All Diagrams

1. **Consistency:** Use the same color for each component across all diagrams (e.g., Backend API is always Teal, Scraper is always Orange).

2. **Color Palette Summary:**
   - Web App: #4361ee (Blue)
   - Mobile App: #7209b7 (Purple)
   - Backend API: #2ec4b6 (Teal)
   - Scraper Service: #e76f51 (Orange)
   - Database: #06d6a0 (Green)
   - S3 Storage: #ffd166 (Gold)
   - External Services: #90e0ef (Light Blue)
   - Error/Alert: #e63946 (Red)
   - Neutral/Infrastructure: #3d405b (Dark Gray)
   - Background: #1a1a2e (Dark Charcoal)
   - Text: #e0e0e0 (Light Gray)

3. **Typography:**
   - Titles: Bold, 24-28px equivalent
   - Component names: Semi-bold, 16-18px equivalent
   - Subtitles and labels: Regular, 12-14px equivalent
   - All text must be readable against the dark background

4. **Resolution:** Target 2400x1600 pixels minimum for print quality, or 1200x800 for web use.

5. **Branding:** Include "Narro" in the title of each diagram. No logos needed -- text only.
