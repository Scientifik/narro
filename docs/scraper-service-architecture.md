# Scraper Service Architecture Plan

## Overview

Create a Python-based background service that manages scraping jobs, schedules periodic scraping, integrates with third-party scraping APIs, parses responses, and saves data to the database. The service is designed to be flexible and evolvable, with pluggable scheduling strategies and intelligent cross-platform duplicate detection.

## Technology Stack

### Language & Framework
- **Language:** Python 3.11+
- **Framework:** FastAPI (for health checks/admin endpoints) or pure Python script
- **Job Scheduling:** APScheduler (Advanced Python Scheduler)
- **Database:** PostgreSQL via Supabase (same database as backend)
- **ORM:** SQLAlchemy (matches backend's GORM approach)
- **HTTP Client:** `httpx` or `requests` for third-party API calls
- **Text Similarity:** `difflib` or `fuzzywuzzy` for content matching
- **Logging:** Python `logging` module with structured logging

### Rationale
- Python excels at data processing and parsing
- Rich ecosystem for scraping-related tasks
- APScheduler provides robust in-app scheduling
- Database queue keeps it simple (no additional services)
- Can reuse database connection patterns from backend
- SQLAlchemy provides similar ORM capabilities to GORM

## Architecture

### Service Structure
```
scraper/
├── src/
│   ├── scheduler/          # Pluggable job scheduling logic
│   │   ├── __init__.py
│   │   ├── base.py         # Abstract scheduling strategy interface
│   │   ├── default.py      # Default scheduling strategy
│   │   └── factory.py      # Strategy factory/registry
│   ├── queue/              # Job queue management (database-based)
│   │   ├── __init__.py
│   │   ├── manager.py      # Queue operations
│   │   └── worker.py       # Job processor
│   ├── scrapers/           # Third-party API integrations
│   │   ├── __init__.py
│   │   ├── base.py         # Abstract scraper provider interface
│   │   └── [provider].py   # Specific provider implementations
│   ├── parsers/            # Data parsing/normalization
│   │   ├── __init__.py
│   │   ├── base.py         # Base parser interface
│   │   ├── twitter.py      # Twitter-specific parser
│   │   ├── linkedin.py     # LinkedIn-specific parser
│   │   └── instagram.py    # Instagram-specific parser
│   ├── duplicate/          # Cross-platform duplicate detection
│   │   ├── __init__.py
│   │   ├── detector.py     # Main duplicate detection logic
│   │   └── matcher.py      # Content similarity matching
│   ├── db/                 # Database connection and queries
│   │   ├── __init__.py
│   │   ├── connection.py   # SQLAlchemy setup
│   │   └── queries.py      # Database query functions
│   ├── models/             # Data models (matching backend schema)
│   │   ├── __init__.py
│   │   ├── social_profile.py
│   │   ├── feed_item.py
│   │   ├── scraping_job.py
│   │   └── feed_item_duplicate.py
│   ├── config/             # Configuration management
│   │   ├── __init__.py
│   │   └── settings.py     # Environment variable loading
│   └── main.py             # Entry point
├── requirements.txt
├── .env.example
├── README.md
└── .gitignore
```

### Core Components

**1. Scheduler (`scheduler/`) - Pluggable Design**
- **Abstract Strategy Interface:** `SchedulingStrategy` base class defines contract
- **Default Strategy:** Time-based scheduling (scans every N minutes)
- **Future Strategies:** Can implement ML-based, priority-based, or activity-based scheduling
- Uses APScheduler to run periodic jobs
- Strategy can be swapped via configuration without changing core service
- **Key Methods:**
  - `get_profiles_to_scrape()` - Returns list of profiles needing scraping
  - `calculate_priority(profile)` - Determines scraping priority
  - `should_scrape(profile)` - Boolean check if profile needs scraping

**2. Queue Manager (`queue/`)**
- Database-based job queue (table: `scraping_jobs`)
- Job states: `pending`, `processing`, `completed`, `failed`
- Retry logic for failed jobs
- Priority handling
- Concurrency control (max concurrent jobs)

**3. Scraper Integrations (`scrapers/`)**
- Abstract base class for scraper providers
- Implementations for different third-party services
- Handles API authentication, rate limiting, retries
- Returns raw scraped data in provider-specific format

**4. Parsers (`parsers/`)**
- Platform-specific parsers (Twitter, LinkedIn, Instagram)
- Normalizes data into unified format
- Extracts: text, images, links, metadata, hashtags, timestamps
- Handles different response formats from scraping services
- Returns normalized `FeedItem` objects

**5. Duplicate Detection (`duplicate/`)**
- **Cross-platform duplicate detection:**
  - Identifies same content posted across different platforms
  - Uses content similarity, timestamps, hashtags, originating profile
  - Stores duplicate relationships (not discards - both posts saved)
  - Flexible matching algorithm (fuzzy matching, not exact)
- **Same-platform duplicate prevention:**
  - Checks `(social_profile_id, platform_post_id)` uniqueness
  - Skips insertion if duplicate found on same platform

**6. Database Layer (`db/`)**
- Connects to same Supabase PostgreSQL database
- Queries `social_profiles` to find profiles needing scraping
- Updates `last_scraped_at` timestamps
- Inserts `feed_items` records
- Manages `scraping_jobs` queue table
- Inserts `feed_item_duplicates` relationships

## Database Schema Additions

### `scraping_jobs` Table
```sql
CREATE TABLE scraping_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    social_profile_id UUID NOT NULL REFERENCES social_profiles(id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
    priority INTEGER DEFAULT 0,
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_scraping_jobs_status ON scraping_jobs(status, scheduled_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_scraping_jobs_profile ON scraping_jobs(social_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_scraping_jobs_deleted_at ON scraping_jobs(deleted_at);
```

### `feed_item_duplicates` Table (Cross-Platform Duplicate Detection)
```sql
CREATE TABLE feed_item_duplicates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id_1 UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    feed_item_id_2 UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    similarity_score FLOAT, -- 0.0 to 1.0, how similar the content is
    match_reason TEXT, -- e.g., "content_similarity", "hashtag_match", "timestamp_proximity", "profile_match"
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(feed_item_id_1, feed_item_id_2),
    CHECK (feed_item_id_1 != feed_item_id_2)
);

CREATE INDEX idx_feed_item_duplicates_item1 ON feed_item_duplicates(feed_item_id_1);
CREATE INDEX idx_feed_item_duplicates_item2 ON feed_item_duplicates(feed_item_id_2);
CREATE INDEX idx_feed_item_duplicates_similarity ON feed_item_duplicates(similarity_score DESC);
```

**Note:** This table stores relationships between posts, not discards. Both posts remain in `feed_items`. The frontend can use this data to group or display related posts.

## Workflow

### 1. Scheduling Flow (Pluggable Strategy)
1. Scheduler runs every N minutes (e.g., every 5 minutes)
2. **Current Strategy (Default):** Queries `social_profiles` for profiles where:
   - `is_active = true`
   - `deleted_at IS NULL`
   - `last_scraped_at` is NULL OR
   - `last_scraped_at + scrape_frequency_hours < NOW()`
3. **Future Strategies:** Can implement:
   - ML-based frequency prediction
   - Activity-based scheduling (more active profiles scraped more often)
   - User priority weighting
   - Time-of-day optimization
4. Creates `scraping_jobs` records for profiles needing scraping
5. Prioritizes based on: time since last scrape, user count following profile

### 2. Job Processing Flow
1. Worker picks up `pending` jobs from queue (ordered by priority, scheduled_at)
2. Marks job as `processing`
3. Calls third-party scraping API with profile URL
4. Receives raw scraped data
5. Parses data into normalized format (platform-specific parser)
6. **Same-platform duplicate check:** Verify `(social_profile_id, platform_post_id)` doesn't exist
7. Saves `feed_items` to database (batch insert for efficiency)
8. **Cross-platform duplicate detection:** After insertion, check for similar content
9. Updates `social_profiles.last_scraped_at`
10. Marks job as `completed` or `failed` (with retry logic)

### 3. Data Parsing Flow
1. Receive raw data from scraping API (format depends on provider)
2. Extract platform-specific fields:
   - Post ID, content text, HTML
   - Media URLs (images, videos)
   - Author info, timestamps
   - Hashtags, mentions, engagement metrics (optional)
3. Normalize to `feed_items` schema
4. **Same-platform deduplication:**
   - Check if `(social_profile_id, platform_post_id)` already exists
   - Skip insertion if duplicate found (same post, same profile, same platform)
5. Batch insert to database
6. **Cross-platform duplicate detection (after insertion):**
   - For each newly inserted post, query recent posts from other platforms
   - Compare content text (fuzzy matching, similarity threshold ~0.85)
   - Check timestamp proximity (within X hours, e.g., 24 hours)
   - Match hashtags if present (exact match on hashtag sets)
   - Match originating profile (if same user posts to multiple platforms - requires profile matching logic)
   - Store duplicate relationships in `feed_item_duplicates` table
   - Both posts remain in `feed_items` (no deletion)

### 4. Cross-Platform Duplicate Detection Algorithm

**Matching Criteria (all must be met for a match):**
1. **Content Similarity:** Text similarity score >= 0.85 (using fuzzy matching)
2. **Timestamp Proximity:** Posted within 24 hours of each other
3. **Profile Match (optional but preferred):** Same user posting to multiple platforms (requires profile matching logic)

**Additional Signals (increase confidence):**
- Hashtag overlap (if both posts have hashtags)
- Media similarity (if both posts have images/videos)
- Link similarity (if both posts contain links)

**Implementation:**
```python
def detect_duplicates(new_feed_item: FeedItem, similarity_threshold: float = 0.85):
    # Query recent posts from other platforms (within 24 hours)
    recent_posts = get_recent_posts_from_other_platforms(
        exclude_platform=new_feed_item.platform,
        time_window_hours=24
    )
    
    for post in recent_posts:
        # Calculate similarity score
        similarity = calculate_content_similarity(
            new_feed_item.content_text,
            post.content_text
        )
        
        # Check timestamp proximity
        time_diff = abs((new_feed_item.posted_at - post.posted_at).total_seconds())
        within_window = time_diff <= 24 * 3600  # 24 hours
        
        # Check hashtag overlap
        hashtag_match = check_hashtag_overlap(
            new_feed_item.hashtags,
            post.hashtags
        )
        
        # If similarity high and within time window, create duplicate relationship
        if similarity >= similarity_threshold and within_window:
            create_duplicate_relationship(
                feed_item_1=new_feed_item.id,
                feed_item_2=post.id,
                similarity_score=similarity,
                match_reason="content_similarity" + ("+hashtag_match" if hashtag_match else "")
            )
```

## Third-Party Scraping API Integration

### Provider Options (to be selected)
- **ScraperAPI** - General purpose scraping
- **Bright Data** - Enterprise scraping platform
- **Apify** - Scraping platform with actors
- **ScrapingBee** - Simple API for web scraping
- **Custom solution** - Build on top of Playwright/Puppeteer

### Integration Pattern
```python
from abc import ABC, abstractmethod

class ScraperProvider(ABC):
    @abstractmethod
    def scrape_profile(self, platform: str, username: str, url: str) -> ScrapedData:
        """Scrape a profile and return raw data"""
        pass
    
    @abstractmethod
    def get_rate_limit(self) -> RateLimit:
        """Get current rate limit status"""
        pass
    
    @abstractmethod
    def handle_errors(self, error: Exception) -> bool:
        """Handle errors and determine if retry is needed"""
        pass
```

## Configuration

### Environment Variables
```
DATABASE_URL=postgresql://... (same as backend)
SCRAPING_API_KEY=... (third-party API key)
SCRAPING_API_URL=... (third-party API endpoint)
SCHEDULER_INTERVAL_MINUTES=5
SCHEDULER_STRATEGY=default  # Can be changed to future strategies
MAX_CONCURRENT_JOBS=10
DUPLICATE_SIMILARITY_THRESHOLD=0.85
DUPLICATE_TIME_WINDOW_HOURS=24
LOG_LEVEL=INFO
```

## Deployment Options

1. **Standalone Process** - Run as long-running Python process
2. **Docker Container** - Containerized service
3. **Cron + Script** - Cron triggers Python script periodically
4. **Cloud Functions** - Serverless (AWS Lambda, Google Cloud Functions)

## Implementation Steps

1. **Project Setup**
   - Create `scraper/` directory
   - Initialize Python project with `requirements.txt`
   - Set up database connection (SQLAlchemy)
   - Create `.gitignore` and basic structure

2. **Database Layer**
   - Create `scraping_jobs` and `feed_item_duplicates` table migrations
   - Implement database queries (get profiles needing scraping, queue management)
   - Models matching backend schema (SQLAlchemy ORM)

3. **Scheduler (Pluggable Design)**
   - Create abstract `SchedulingStrategy` interface
   - Implement default time-based strategy
   - Set up APScheduler with strategy injection
   - Create strategy factory/registry for easy swapping

4. **Queue Manager**
   - Implement job queue operations (create, update, retry)
   - Worker that processes pending jobs
   - Concurrency control

5. **Scraper Integration**
   - Abstract scraper interface
   - Implement first third-party provider
   - Error handling and retries

6. **Parsers**
   - Platform-specific parsers
   - Data normalization
   - Extract hashtags, timestamps, media

7. **Duplicate Detection**
   - Implement content similarity matching
   - Cross-platform duplicate detection logic
   - Store duplicate relationships
   - Same-platform duplicate prevention

8. **Main Application**
   - Wire everything together
   - Health check endpoint (optional)
   - Graceful shutdown handling

## Key Design Decisions

- **Database Queue:** Simple, no additional infrastructure, uses existing database
- **In-App Scheduler:** Self-contained, easier deployment, full control
- **Pluggable Scheduler Strategy:** Interface-based design allows scheduling logic to evolve without refactoring core service
- **Python:** Best tool for data processing/parsing, rich ecosystem
- **Separate Service:** Isolated from main backend, can scale independently
- **Idempotent Jobs:** Jobs can be safely retried without duplicates
- **Cross-Platform Duplicate Detection:** Identifies but doesn't discard - stores relationships for frontend presentation
- **Flexible Matching:** Fuzzy content matching with configurable thresholds (not exact matches)
- **Same-Platform Deduplication:** Prevents storing the same post twice from the same profile on the same platform
- **Relationship Storage:** Duplicate relationships stored separately, allowing frontend to group/display related posts

## Future Enhancements

- **Scheduling Strategies:**
  - ML-based frequency prediction
  - Activity-based scheduling
  - User priority weighting
  - Time-of-day optimization
  
- **Duplicate Detection:**
  - Profile matching across platforms (identify same user on different platforms)
  - Media similarity detection (image/video comparison)
  - Link similarity detection
  
- **Other:**
  - Dynamic scraping frequency based on posting patterns
  - Priority queue for popular profiles
  - Batch processing for efficiency
  - Webhook support from scraping providers
  - Metrics and monitoring dashboard
  - Distributed workers (multiple instances)
  - Real-time duplicate detection (as posts are scraped)

