# Migration Plan: Consolidate to user_feed_profiles

## Overview

Consolidate three tables into one:
- `user_social_profiles` (user → social profile relationship)
- `feed_profile_items` (profile → feed relationship)
- `feed_profile_favorites` (profile → feed favoriting)

INTO: `user_feed_profiles` (single source of truth)

## New Schema Design

```sql
CREATE TABLE user_feed_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    social_profile_id UUID NOT NULL REFERENCES social_profiles(id) ON DELETE CASCADE,
    feed_id UUID REFERENCES feeds(id) ON DELETE CASCADE,  -- NULL = library (followed but not in feed)
    is_favorited BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Only one library entry (feed_id IS NULL) per user per profile
CREATE UNIQUE INDEX idx_user_feed_profiles_library
ON user_feed_profiles(user_id, social_profile_id)
WHERE feed_id IS NULL AND deleted_at IS NULL;

-- Prevent same profile appearing twice in same feed
CREATE UNIQUE INDEX idx_user_feed_profiles_feed
ON user_feed_profiles(user_id, social_profile_id, feed_id)
WHERE feed_id IS NOT NULL AND deleted_at IS NULL;

-- Performance indexes for common queries
-- For "get all profiles for a user" (library view)
CREATE INDEX idx_user_feed_profiles_user_library 
ON user_feed_profiles(user_id) 
WHERE feed_id IS NULL AND deleted_at IS NULL;

-- For "get all profiles in a feed"
CREATE INDEX idx_user_feed_profiles_feed_active 
ON user_feed_profiles(feed_id) 
WHERE deleted_at IS NULL;

-- For "get all feeds containing a profile"
CREATE INDEX idx_user_feed_profiles_social_profile 
ON user_feed_profiles(social_profile_id) 
WHERE deleted_at IS NULL;

-- Composite for starred profiles in feed
CREATE INDEX idx_user_feed_profiles_feed_starred 
ON user_feed_profiles(feed_id, is_favorited) 
WHERE is_favorited = true AND deleted_at IS NULL;

-- Composite for user + feed queries
CREATE INDEX idx_user_feed_profiles_user_feed 
ON user_feed_profiles(user_id, feed_id) 
WHERE deleted_at IS NULL;
```

### Row Level Security (RLS) Policies

```sql
-- Enable RLS
ALTER TABLE user_feed_profiles ENABLE ROW LEVEL SECURITY;

-- Users can view their own feed profiles
CREATE POLICY "Users can view their own feed profiles"
ON user_feed_profiles FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert their own feed profiles
CREATE POLICY "Users can insert their own feed profiles"
ON user_feed_profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can update their own feed profiles
CREATE POLICY "Users can update their own feed profiles"
ON user_feed_profiles FOR UPDATE
USING (auth.uid() = user_id);

-- Users can delete their own feed profiles
CREATE POLICY "Users can delete their own feed profiles"
ON user_feed_profiles FOR DELETE
USING (auth.uid() = user_id);
```

## Query Improvements

### Before (3 joins)
```sql
SELECT sp.*
FROM feed_profile_items fpi
JOIN user_social_profiles usp ON fpi.user_social_profile_id = usp.id
JOIN social_profiles sp ON usp.social_profile_id = sp.id
WHERE fpi.feed_id = ?
```

### After (1 join)
```sql
SELECT sp.* FROM user_feed_profiles ufp
JOIN social_profiles sp ON ufp.social_profile_id = sp.id
WHERE ufp.feed_id = ?
```

---

## Migration SQL Strategy

The migration SQL should handle data migration with conflict resolution:

```sql
-- Migrate feed_profile_items → user_feed_profiles
INSERT INTO user_feed_profiles (user_id, social_profile_id, feed_id, is_favorited, created_at)
SELECT 
    usp.user_id,
    usp.social_profile_id,
    fpi.feed_id,
    COALESCE((SELECT true FROM feed_profile_favorites fpf 
              WHERE fpf.user_social_profile_id = fpi.user_social_profile_id 
              AND fpf.feed_id = fpi.feed_id 
              AND fpf.deleted_at IS NULL), false),
    fpi.created_at
FROM feed_profile_items fpi
JOIN user_social_profiles usp ON fpi.user_social_profile_id = usp.id
WHERE fpi.deleted_at IS NULL AND usp.deleted_at IS NULL
ON CONFLICT DO NOTHING;

-- Migrate profiles not in any feed (library entries)
INSERT INTO user_feed_profiles (user_id, social_profile_id, feed_id, created_at)
SELECT 
    usp.user_id,
    usp.social_profile_id,
    NULL, -- library entry
    usp.created_at
FROM user_social_profiles usp
WHERE usp.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM feed_profile_items fpi 
    WHERE fpi.user_social_profile_id = usp.id 
    AND fpi.deleted_at IS NULL
  )
ON CONFLICT DO NOTHING;
```

### Data Validation Queries

After migration, run these to verify data integrity:

```sql
-- Verify all feed_profile_items migrated
SELECT 
  (SELECT COUNT(*) FROM feed_profile_items WHERE deleted_at IS NULL) as old_count,
  (SELECT COUNT(*) FROM user_feed_profiles WHERE feed_id IS NOT NULL AND deleted_at IS NULL) as new_count;

-- Verify all user_social_profiles have library entries
SELECT 
  (SELECT COUNT(DISTINCT user_id, social_profile_id) FROM user_social_profiles WHERE deleted_at IS NULL) as old_count,
  (SELECT COUNT(*) FROM user_feed_profiles WHERE feed_id IS NULL AND deleted_at IS NULL) as new_count;

-- Verify favorites migrated
SELECT 
  (SELECT COUNT(*) FROM feed_profile_favorites WHERE deleted_at IS NULL) as old_favorites,
  (SELECT COUNT(*) FROM user_feed_profiles WHERE is_favorited = true AND deleted_at IS NULL) as new_favorites;

-- Check for orphaned entries (should be 0)
SELECT COUNT(*) as orphaned_count
FROM user_feed_profiles ufp
WHERE ufp.feed_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM feeds f WHERE f.id = ufp.feed_id AND f.deleted_at IS NULL
  )
  AND ufp.deleted_at IS NULL;
```

---

## Files Already Created

These files have been created and are ready:

### 1. SQL Migration
**File:** `backend/migrations/023_consolidate_user_feed_profiles.sql`

### 2. Go Model
**File:** `backend/src/models/user_feed_profile.go`

### 3. Database Operations
**File:** `backend/src/db/user_feed_profiles.go`

---

## Files That Need Updates

### Backend Services

#### 1. `backend/src/services/profile_service.go`

**Current `ProfileWithFeed` struct:**
```go
type ProfileWithFeed struct {
    models.UserSocialProfile
    SocialProfile models.SocialProfile `json:"social_profile"`
    FeedID        *uuid.UUID           `json:"feed_id,omitempty"`
}
```

**Change to:**
```go
type ProfileWithFeed struct {
    models.UserFeedProfile
    SocialProfile models.SocialProfile `json:"social_profile"`
}
```

**Functions to update:**

| Function | Change |
|----------|--------|
| `AddProfile()` | Use `db.FollowProfile()` then `db.AddProfileToFeedNew()` instead of `db.CreateUserSocialProfile()` + `db.AddProfileToFeed()` |
| `GetUserProfiles()` | Use `db.GetFeedProfilesNew()` or `db.GetAllUserProfiles()` |
| `UnfollowProfile()` | Change signature to use `socialProfileID` instead of `userSocialProfileID`, use `db.UnfollowProfile()` |

#### 2. `backend/src/services/feed_management_service.go`

**Current `FeedWithProfiles` struct:**
```go
type FeedWithProfiles struct {
    models.Feed
    Profiles []models.FeedProfileItem `json:"profiles,omitempty"`
}
```

**Change to:**
```go
type FeedWithProfiles struct {
    models.Feed
    Profiles []models.UserFeedProfile `json:"profiles,omitempty"`
}
```

**Functions to update:**

| Function | Change |
|----------|--------|
| `AddProfileToFeed()` | Change param from `userSocialProfileID` to `socialProfileID`, use `db.AddProfileToFeedNew()` |
| `RemoveProfileFromFeed()` | Change param from `userSocialProfileID` to `socialProfileID`, use `db.RemoveProfileFromFeedNew()` |
| `GetFeedProfiles()` | Use `db.GetFeedProfilesNew()`, return `[]models.UserFeedProfile` |

#### 3. `backend/src/services/feed_profile_favorite_service.go`

**Functions to update:**

| Function | Change |
|----------|--------|
| `StarProfile()` | Change param from `userSocialProfileID` to `socialProfileID`, use `db.StarProfileNew()` |
| `UnstarProfile()` | Change param from `userSocialProfileID` to `socialProfileID`, use `db.UnstarProfileNew()` |
| `GetStarredProfiles()` | Use `db.GetStarredProfilesNew()`, return `[]models.UserFeedProfile` instead of `[]uuid.UUID` |

#### 4. `backend/src/db/feed_items.go`

**Critical function to update:** `GetFeedItemsForUser()`

**Current logic (lines 43-92):** Does multiple queries:
1. Get `feed_profile_items` for feed
2. Extract `user_social_profile_ids`
3. Query `user_social_profiles` with those IDs
4. Extract `social_profile_ids`
5. Filter by starred if needed (another query to `feed_profile_favorites`)

**New logic:** Direct query to `user_feed_profiles`:
```go
// If feed_id provided, query directly
if feedID != nil {
    var userFeedProfiles []models.UserFeedProfile
    query := d.WithContext(ctx).
        Where("feed_id = ? AND user_id = ? AND deleted_at IS NULL", *feedID, userID)
    
    // If starredOnly, add filter
    if starredOnly {
        query = query.Where("is_favorited = true")
    }
    
    // If specific profiles requested
    if len(profileIDs) > 0 {
        query = query.Where("social_profile_id IN ?", profileIDs)
    }
    
    query.Find(&userFeedProfiles)
    
    // Extract social_profile_ids directly
    socialProfileIDs := make([]uuid.UUID, len(userFeedProfiles))
    for i, ufp := range userFeedProfiles {
        socialProfileIDs[i] = ufp.SocialProfileID
    }
    // ... continue with feed_items query
}
```

**Lines to update:** 43-106 (feed filtering logic), 70-92 (starred filtering logic)

#### 5. `backend/src/services/feed_service.go`

**Function to update:** Showcase feed query (lines 250-292)

**Current joins (lines 257-264):**
```go
INNER JOIN user_social_profiles ON social_profiles.id = user_social_profiles.social_profile_id
INNER JOIN feed_profile_items ON user_social_profiles.id = feed_profile_items.user_social_profile_id
```

**New joins:**
```go
INNER JOIN user_feed_profiles ON social_profiles.id = user_feed_profiles.social_profile_id
WHERE user_feed_profiles.feed_id = ? 
  AND user_feed_profiles.deleted_at IS NULL
```

---

### Backend Handlers

#### 6. `backend/src/handlers/profile_handler.go`

Update any references to `UserSocialProfile` to use `UserFeedProfile`.

**Route changes:**
- `GET /api/profiles/:id` - Change from `userSocialProfileID` to `socialProfileID`
- `DELETE /api/profiles/:id` - Change from `userSocialProfileID` to `socialProfileID`

#### 7. `backend/src/handlers/feed_management_handler.go`

**Route parameter change:**
- Before: `/feeds/:feedId/profiles/:userSocialProfileId`
- After: `/feeds/:feedId/profiles/:socialProfileId`

Update handler to extract `socialProfileId` instead of `userSocialProfileId`.

#### 8. `backend/src/handlers/feed_profile_favorite_handler.go`

Same route parameter change as above.

---

### Frontend TypeScript

#### 9. `web/types/api.ts`

**Add new interface:**
```typescript
export interface UserFeedProfile {
  id: string;
  user_id: string;
  social_profile_id: string;
  feed_id?: string | null;  // null = library
  is_favorited: boolean;
  created_at: string;
  deleted_at?: string | null;
  social_profile?: SocialProfile;
  feed?: Feed;
}
```

**Update `ProfileWithFeed`:**
```typescript
// Before
export interface ProfileWithFeed extends UserSocialProfile {
  social_profile: SocialProfile;
  feed_id?: string;
}

// After
export interface ProfileWithFeed extends UserFeedProfile {
  social_profile: SocialProfile;
}
```

#### 10. `web/lib/hooks/use-profiles.ts`

Update API response type handling. The response shape changes slightly:
- `user_social_profile_id` becomes `id` (the UserFeedProfile id)
- Access social profile via `social_profile` (unchanged)
- `feed_id` is now directly on `UserFeedProfile` object (not separate field)

**Search for all references:**
```bash
# Find components using user_social_profile_id
grep -r "user_social_profile_id" web/
# Find components using feed_id from ProfileWithFeed
grep -r "feed_id" web/components/
```

**Components to check:**
- Profile list components
- Feed profile management components
- Profile filtering logic
- Any components that display `feed_id` separately

#### 11. `web/lib/hooks/use-feed-favorites.ts`

Update API calls to use `socialProfileId` instead of `userSocialProfileId` in URLs.

**Also update:**
- Any components that reference starred/favorited profiles
- Profile card components that show favorite status

---

### Scraper

#### 12. `scraper/src/scheduler/default.py`

**Change lines 58-65:**

```python
# Before:
user_profile_subquery = select(1).select_from(
    text("user_social_profiles")
).where(
    and_(
        text("user_social_profiles.social_profile_id = social_profiles.id"),
        text("user_social_profiles.deleted_at IS NULL")
    )
)

# After:
user_profile_subquery = select(1).select_from(
    text("user_feed_profiles")
).where(
    and_(
        text("user_feed_profiles.social_profile_id = social_profiles.id"),
        text("user_feed_profiles.deleted_at IS NULL")
    )
)
```

**Audit all scraper files:**
```bash
# Search for all references to user_social_profiles in scraper
grep -r "user_social_profiles" scraper/
```

**Files to check:**
- `scraper/src/scheduler/default.py` (already identified)
- Any other scheduler implementations
- Any database query files in scraper

---

### Supabase Edge Functions

#### 13. `supabase/functions/rss-feed/database.ts`

**Function to update:** `getFeedItemsForFeed()`

**Current logic (lines 29-60):** 3-step process:
1. Get `feed_profile_items` for feed
2. Get `user_social_profiles` to map IDs
3. Extract `social_profile_ids`

**New logic:** Direct query:
```typescript
// Step 1: Get social_profile_ids directly from user_feed_profiles
const { data: userFeedProfiles, error } = await supabase
  .from('user_feed_profiles')
  .select('social_profile_id')
  .eq('feed_id', feedId)
  .eq('user_id', userId)
  .is('deleted_at', null);

if (error || !userFeedProfiles?.length) {
  return [];
}

const socialProfileIds = userFeedProfiles.map(
  (ufp: any) => ufp.social_profile_id
);

// Step 2: Call Postgres function (unchanged)
const { data: feedItems, error: itemsError } = await supabase
  .rpc('get_feed_items_with_authors', {
    p_social_profile_ids: socialProfileIds,
    p_limit: limit,
  });
```

**Lines to update:** 29-60 (entire function body)

---

## Files to Delete (After Migration Complete)

Once everything is working:

1. `backend/src/models/user_social_profile.go`
2. `backend/src/models/feed_profile_item.go`
3. `backend/src/models/feed_profile_favorite.go`
4. `backend/src/db/user_social_profiles.go`
5. `backend/src/db/feed_profile_items.go`
6. `backend/src/db/feed_profile_favorites.go`

And uncomment the DROP TABLE statements in the migration.

---

## API Breaking Changes

The API signature changes from `userSocialProfileID` to `socialProfileID`:

| Before | After |
|--------|-------|
| `GET /api/profiles/:userSocialProfileId` | `GET /api/profiles/:socialProfileId` |
| `DELETE /api/profiles/:userSocialProfileId` | `DELETE /api/profiles/:socialProfileId` |
| `POST /feeds/:feedId/profiles/:userSocialProfileId` | `POST /feeds/:feedId/profiles/:socialProfileId` |
| `DELETE /feeds/:feedId/profiles/:userSocialProfileId` | `DELETE /feeds/:feedId/profiles/:socialProfileId` |
| `POST /feeds/:feedId/profiles/:userSocialProfileId/star` | `POST /feeds/:feedId/profiles/:socialProfileId/star` |
| `DELETE /feeds/:feedId/profiles/:userSocialProfileId/star` | `DELETE /feeds/:feedId/profiles/:socialProfileId/star` |

**Response shape changes:**
- `ProfileWithFeed` now includes `feed_id` directly on the object (not separate field)
- `id` field now refers to `UserFeedProfile.id` (not `UserSocialProfile.id`)

**Deployment strategy:**
- **Option A (Recommended):** Deploy frontend and backend together in coordinated release
- **Option B (Safer):** Support both parameter names temporarily, deprecate old one, remove in next release

**Frontend and backend must be deployed together.**

---

## Implementation Order

1. **Run SQL migration** (creates new table, migrates data, keeps old tables)
   - Run migration script
   - Verify no errors

2. **✅ VERIFY: Run data validation queries**
   - Execute all validation queries from "Data Validation Queries" section
   - Ensure counts match between old and new tables
   - Check for orphaned entries (should be 0)

3. **Update backend database layer**
   - Update `backend/src/db/feed_items.go::GetFeedItemsForUser()`
   - Update `backend/src/db/user_feed_profiles.go` (if needed)
   - Test database queries in isolation

4. **Update backend services**
   - Update `profile_service.go`
   - Update `feed_management_service.go`
   - Update `feed_profile_favorite_service.go`
   - Update `feed_service.go` (showcase feed query)

5. **Update backend handlers**
   - Update route parameters in all handlers
   - Update response types
   - Test API endpoints

6. **Update frontend types**
   - Add `UserFeedProfile` interface
   - Update `ProfileWithFeed` interface
   - Update all type references

7. **Update frontend hooks and components**
   - Update `use-profiles.ts`
   - Update `use-feed-favorites.ts`
   - Search and update all components using `user_social_profile_id`
   - Update components that reference `feed_id` separately

8. **Update scraper**
   - Update `scheduler/default.py`
   - Audit all scraper files for `user_social_profiles` references
   - Test scraper queries

9. **Update Supabase Edge Functions**
   - Update `rss-feed/database.ts`
   - Test RSS feed generation

10. **✅ TEST: Run integration tests**
    - Test profile management (add, remove, list)
    - Test feed management (add profile to feed, remove from feed)
    - Test favoriting (star/unstar)
    - Test feed items retrieval
    - Test RSS feed generation
    - Test scraper scheduling

11. **Deploy all together**
    - Deploy backend
    - Deploy frontend
    - Deploy scraper
    - Deploy Supabase functions

12. **✅ VERIFY: Monitor and smoke test**
    - Monitor application logs for errors
    - Run smoke tests on critical paths
    - Check database query performance
    - Verify RSS feeds work
    - Monitor scraper jobs

13. **Remove old code and drop old tables**
    - Delete old model files
    - Delete old DB operation files
    - Uncomment DROP TABLE statements in migration
    - Run final migration to drop old tables

---

## Rollback Plan

- Old tables are preserved (not dropped in migration)
- If issues: revert code, old tables still work
- Only drop old tables after confirming stability

**Rollback steps:**
1. Revert code changes (git revert or rollback deployment)
2. Old tables still contain all data
3. Application will work with old schema
4. Fix issues and re-attempt migration

**Note:** Once old tables are dropped (step 13), rollback becomes more complex and may require data restoration from backup.

---

## Additional Recommendations

### Monitoring & Performance

**Before migration:**
- Document current query performance metrics
- Note query execution times for:
  - `GetFeedItemsForUser()`
  - Feed profile listing
  - Profile favoriting queries

**After migration:**
- Compare query performance
- Monitor slow query logs
- Check index usage with `EXPLAIN ANALYZE`

### Documentation Updates

Update the following documentation:
- API documentation (endpoint signatures)
- Database schema documentation
- Architecture diagrams
- Developer onboarding docs

### Testing Checklist

- [ ] Profile can be added to feed
- [ ] Profile can be removed from feed
- [ ] Profile can be unfollowed (removed from library)
- [ ] Profile can be starred/unstarred in feed
- [ ] Feed items load correctly for a feed
- [ ] Feed items filter by starred profiles
- [ ] Feed items filter by date range
- [ ] Feed items filter by hashtag
- [ ] RSS feed generates correctly
- [ ] Scraper creates jobs for followed profiles
- [ ] Default feed shows all profiles
- [ ] Library view shows profiles not in feeds
- [ ] Profile appears in multiple feeds correctly

### Feature Flag (Optional)

Consider adding a feature flag to toggle between old/new queries:
- Allows gradual rollout
- Easier rollback if issues found
- Can A/B test performance

### Migration Script Dry-Run

Before running on production:
1. Create a copy of production database
2. Run migration on copy
3. Verify all validation queries pass
4. Test application against migrated copy
5. Only then run on production
