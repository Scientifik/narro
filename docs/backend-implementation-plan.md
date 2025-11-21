# Backend Implementation Plan

This document outlines the backend implementation for Narro, covering authentication, profile management, and list organization.

## Overview

The backend implements:
- Basic email/password authentication using Supabase Auth
- System-wide social profile tracking (scraped once, shared by all users)
- User-defined lists for organizing followed profiles
- Minimal user profile data

## Database Schema

See `backend/migrations/001_initial_schema.sql` for the complete SQL schema.

### Key Tables

1. **user_profiles** - Extends Supabase auth.users with minimal additional data
2. **social_profiles** - System-wide registry of profiles being tracked (one record per platform+username)
3. **user_social_profiles** - Junction table linking users to profiles they follow
4. **profile_lists** - User-defined lists (everyone gets a default list on signup)
5. **profile_list_items** - Junction table linking profiles to lists
6. **feed_items** - System-wide cache of scraped posts

## API Endpoints

### Authentication
- `POST /api/auth/signup` - Create account (creates default list automatically)
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Get current user info

### Profiles
- `GET /api/profiles` - List user's followed profiles (optional `?list_id=<uuid>` filter)
- `POST /api/profiles` - Add a profile URL (creates/uses system-wide profile)
- `GET /api/profiles/:id` - Get profile details
- `DELETE /api/profiles/:id` - Unfollow a profile

### Lists
- `GET /api/lists` - List user's lists
- `POST /api/lists` - Create a new list
- `GET /api/lists/:id` - Get list details
- `GET /api/lists/:id/profiles` - Get all profiles in a list
- `PATCH /api/lists/:id` - Update list (name, color)
- `DELETE /api/lists/:id` - Delete list (cannot delete default list)
- `POST /api/lists/:id/profiles/:profile_id` - Add profile to list
- `DELETE /api/lists/:id/profiles/:profile_id` - Remove profile from list

## Implementation Details

### System-Wide Profile Management

When a user adds a profile:
1. URL is parsed to extract platform and username
2. System checks if `(platform, username)` already exists in `social_profiles`
3. If exists: uses existing record
4. If not: creates new `social_profile` record
5. Creates `user_social_profiles` relationship
6. Adds profile to user's default list (or specified list)

This ensures each profile is scraped once, regardless of how many users follow it.

### Default List Creation

On user signup:
- A default list named "All Profiles" is automatically created
- Marked with `is_default = true`
- Cannot be deleted or renamed
- New profiles are added here by default if no list is specified

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
│   └── 001_initial_schema.sql
├── src/
│   ├── db/              # Database layer (client, queries, URL parsing)
│   ├── models/          # Data models (structs)
│   ├── services/        # Business logic (auth, profiles, lists)
│   ├── handlers/        # HTTP handlers
│   ├── middleware/      # Auth, CORS, error handling
│   └── routes/          # Route setup
├── main.go              # Application entry point
├── go.mod
└── env.example
```

## Next Steps

1. Set up Supabase project and run migrations
2. Configure environment variables
3. Test authentication flow
4. Test profile addition and list management
5. Implement scraping integration (future)


