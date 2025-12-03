# Backend Implementation Plan

This document outlines the backend implementation for Narro, covering authentication, profile management, feed organization, and feed configuration.

## Overview

The backend implements:
- Basic email/password authentication using Supabase Auth
- System-wide social profile tracking (scraped once, shared by all users)
- User-defined feeds for organizing followed profiles
- Feed configuration system for customizing feed display (view types, UI options, auto-refresh)
- Minimal user profile data

## Database Schema

See `backend/migrations/001_initial_schema.sql` for the complete SQL schema.

### Key Tables

1. **user_profiles** - Extends Supabase auth.users with minimal additional data
2. **social_profiles** - System-wide registry of profiles being tracked (one record per platform+username)
3. **user_social_profiles** - Junction table linking users to profiles they follow
4. **feeds** - User-defined feeds (everyone gets a default feed on signup)
5. **feed_profile_items** - Junction table linking profiles to feeds
6. **feed_items** - System-wide cache of scraped posts
7. **feed_configurations** - UI configuration for each feed (view type, card style, background image, auto-refresh)

## API Endpoints

### Authentication
- `POST /api/auth/signup` - Create account (creates default list automatically)
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Get current user info

### Profiles
- `GET /api/profiles` - List user's followed profiles (optional `?feed_id=<uuid>` filter)
- `POST /api/profiles` - Add a profile URL (creates/uses system-wide profile, optional `feed_id` in body)
- `GET /api/profiles/:id` - Get profile details
- `DELETE /api/profiles/:id` - Unfollow a profile

### Feeds
- `GET /api/feeds` - List user's feeds
- `POST /api/feeds` - Create a new feed
- `GET /api/feeds/:id` - Get feed details
- `GET /api/feeds/:id/profiles` - Get all profiles in a feed
- `PATCH /api/feeds/:id` - Update feed (name, color)
- `DELETE /api/feeds/:id` - Delete feed (cannot delete default feed)
- `POST /api/feeds/:id/profiles/:profile_id` - Add profile to feed
- `DELETE /api/feeds/:id/profiles/:profile_id` - Remove profile from feed

### Feed Configurations
- `GET /api/feeds/:id/feed-config` - Get feed configuration (returns defaults if not configured)
- `POST /api/feeds/:id/feed-config` - Create feed configuration
- `PATCH /api/feeds/:id/feed-config` - Update feed configuration
- `DELETE /api/feeds/:id/feed-config` - Delete feed configuration

### Feed Content
- `GET /api/feed` - Get feed items/posts (optional `?feed_id=<uuid>` filter)
  - Query params: `page`, `limit`, `feed_id`, `profile_ids`, `start_date`, `end_date`, `hashtag`

## Implementation Details

### System-Wide Profile Management

When a user adds a profile:
1. URL is parsed to extract platform and username
2. System checks if `(platform, username)` already exists in `social_profiles`
3. If exists: uses existing record
4. If not: creates new `social_profile` record
5. Creates `user_social_profiles` relationship
6. Adds profile to user's default feed (or specified feed)

This ensures each profile is scraped once, regardless of how many users follow it.

### Default Feed Creation

On user signup:
- A default feed named "All Profiles" is automatically created
- Marked with `is_default = true`
- Cannot be deleted or renamed
- New profiles are added here by default if no feed is specified

### Feed Configuration

Each feed can have a configuration that controls:
- **View Type**: How items are displayed (`list`, `grid`, `gallery`)
  - `list`: Infinite scroll vertical list (default)
  - `grid`: Responsive grid layout with cards
  - `gallery`: Image-focused wide grid view (TikTok/Instagram style)
- **Card Style**: Card appearance (`compact`, `expanded`, `minimal`)
- **Background Image**: Optional background image URL for the feed view
- **Auto-Refresh**: Enable/disable automatic feed updates
- **Auto-Refresh Interval**: Refresh interval in seconds (minimum 10)

If a feed doesn't have a configuration, default values are returned:
- View type: `list`
- Card style: `compact`
- Auto-refresh: `true`
- Auto-refresh interval: `60` seconds

### URL Parsing

Supported platforms:
- **Twitter/X**: `twitter.com/username` or `x.com/username`
- **LinkedIn**: `linkedin.com/in/username` or `linkedin.com/company/username`
- **Instagram**: `instagram.com/username`

The parser extracts platform and username, then constructs a canonical URL.

### Authentication Flow

1. User signs up/logs in via Supabase Auth
2. JWT token is returned
3. Token is validated on protected routes via middleware
4. User ID is extracted from JWT claims and stored in context

## Environment Variables

Required environment variables (see `env.example`):
- `DATABASE_URL` - PostgreSQL connection string
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment (development/production)

## Running the Backend

1. Set up Supabase project and run migrations:
   ```bash
   # Run migrations/001_initial_schema.sql in Supabase SQL editor
   ```

2. Copy environment variables:
   ```bash
   cp env.example .env
   # Edit .env with your values
   ```

3. Install dependencies:
   ```bash
   go mod download
   ```

4. Run the server:
   ```bash
   go run main.go
   ```

The server will start on `http://localhost:3000` (or the port specified in `PORT`).

## Project Structure

```
backend/
├── migrations/
│   ├── 001_initial_schema.sql
│   ├── 002_add_deleted_at_columns.sql
│   ├── 003_add_youtube_platform.sql
│   ├── 004_add_hashtags_and_thumbnail.sql
│   ├── 005_add_themes_system.sql
│   ├── 006_rename_lists_to_feeds.sql
│   └── 007_add_feed_configurations.sql
├── src/
│   ├── db/              # Database layer (client, queries, URL parsing)
│   │   ├── feeds.go
│   │   ├── feed_profile_items.go
│   │   ├── feed_configurations.go
│   │   └── feed_items.go (supports feed_id filtering)
│   ├── models/          # Data models (structs)
│   │   ├── feed.go
│   │   ├── feed_profile_item.go
│   │   └── feed_configuration.go
│   ├── services/        # Business logic
│   │   ├── feed_management_service.go
│   │   ├── feed_configuration_service.go
│   │   └── feed_service.go (content/posts)
│   ├── handlers/        # HTTP handlers
│   │   ├── feed_management_handler.go
│   │   ├── feed_configuration_handler.go
│   │   └── feed_handler.go (content/posts)
│   ├── middleware/      # Auth, CORS, error handling
│   └── routes/          # Route setup
├── main.go              # Application entry point
├── go.mod
└── env.example
```

## Feed Filtering

The feed content endpoint (`GET /api/feed`) supports filtering by `feed_id`:
- When `feed_id` is provided, only posts from profiles in that feed are returned
- Filtering works by joining through `feed_profile_items` to get profiles in the feed
- Supports all other filters (date range, hashtags, specific profiles) in combination with feed filtering

## Feed Configuration Defaults

When a feed is created, no configuration is automatically created. The system returns default values:
- View type: `list`
- Card style: `compact`
- Auto-refresh: `true`
- Auto-refresh interval: `60` seconds

Users can create a configuration via `POST /api/feeds/:id/feed-config` to customize these settings.

## Next Steps

1. Set up Supabase project and run migrations (001-007)
2. Configure environment variables
3. Test authentication flow
4. Test feed creation and management
5. Test feed configuration system
6. Test feed filtering by feed_id
7. Implement additional scraping features (future)


