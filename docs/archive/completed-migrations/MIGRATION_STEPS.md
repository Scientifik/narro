# Migration Steps: user_feed_profiles

All code changes have been committed to the `staging` branch in each repository.

## Commits Made

| Repo | Branch | Commit | Description |
|------|--------|--------|-------------|
| backend | staging | c2bb105 | Backend services, handlers, migration, models |
| web | staging | 3d9393a | TypeScript types and hooks |
| scraper | staging | 1b82b0a | Scheduler query update |
| narro (main) | staging | a8f2783 | Supabase RSS function |

---

## Step 1: Run Database Migration

Connect to your Supabase database and run the migration:

```bash
# Option A: Using psql
psql $DATABASE_URL -f backend/migrations/023_consolidate_user_feed_profiles.sql

# Option B: Using Supabase CLI
supabase db push
```

---

## Step 2: Verify Data Migration

Run these queries to verify data integrity:

```sql
-- Verify all feed_profile_items migrated
SELECT
  (SELECT COUNT(*) FROM feed_profile_items WHERE deleted_at IS NULL) as old_feed_items,
  (SELECT COUNT(*) FROM user_feed_profiles WHERE feed_id IS NOT NULL AND deleted_at IS NULL) as new_feed_items;

-- Verify library entries (profiles not in feeds)
SELECT
  (SELECT COUNT(*) FROM user_social_profiles usp
   WHERE usp.deleted_at IS NULL
   AND NOT EXISTS (
     SELECT 1 FROM feed_profile_items fpi
     WHERE fpi.user_social_profile_id = usp.id
     AND fpi.deleted_at IS NULL
   )) as old_library,
  (SELECT COUNT(*) FROM user_feed_profiles WHERE feed_id IS NULL AND deleted_at IS NULL) as new_library;

-- Verify favorites migrated
SELECT
  (SELECT COUNT(*) FROM feed_profile_favorites) as old_favorites,
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

**Expected**: Counts should match or new counts should be >= old counts.

---

## Step 3: Deploy Services

Deploy in this order (can be parallelized after migration):

### 3a. Deploy Backend
```bash
cd backend
git checkout staging
# Deploy to staging environment
```

### 3b. Deploy Web Frontend
```bash
cd web
git checkout staging
# Deploy to staging environment
```

### 3c. Deploy Scraper
```bash
cd scraper
git checkout staging
# Deploy to staging environment
```

### 3d. Deploy Supabase Functions
```bash
cd narro
supabase functions deploy rss-feed
```

---

## Step 4: Testing Checklist

### Profile Management
- [ ] Add new profile to default feed
- [ ] Add new profile to specific feed
- [ ] View profiles in a feed
- [ ] View all profiles (no feed filter)
- [ ] Unfollow a profile

### Feed Management
- [ ] Add existing profile to a different feed
- [ ] Remove profile from feed
- [ ] Get feed profiles list

### Favorites
- [ ] Star a profile in a feed
- [ ] Unstar a profile in a feed
- [ ] View starred profiles in a feed
- [ ] Filter feed by starred profiles

### Feed Display
- [ ] Feed items load correctly
- [ ] Feed items show correct authors
- [ ] Filtering by profile works
- [ ] Pagination works

### RSS Feed
- [ ] RSS feed generates correctly
- [ ] RSS feed shows items from correct profiles

### Scraper
- [ ] Scraper picks up profiles for scheduled scraping
- [ ] Manual scrape trigger works

---

## Step 5: Cleanup (After Verification)

Once everything is working, drop the old tables:

```sql
-- ONLY RUN AFTER VERIFYING ALL TESTS PASS
DROP TABLE IF EXISTS feed_profile_favorites;
DROP TABLE IF EXISTS feed_profile_items;
DROP TABLE IF EXISTS user_social_profiles;
```

And remove the old model/db files:
- `backend/src/models/user_social_profile.go`
- `backend/src/models/feed_profile_item.go`
- `backend/src/models/feed_profile_favorite.go`
- `backend/src/db/user_social_profiles.go`
- `backend/src/db/feed_profile_items.go`
- `backend/src/db/feed_profile_favorites.go`

---

## Rollback Plan

If issues occur:

1. **Revert code**: `git checkout main` in each repo
2. **Old tables still exist** - they contain all original data
3. **Redeploy**: Deploy from main branch
4. **Fix issues**: Address problems and retry migration

---

## API Changes Summary

| Before | After |
|--------|-------|
| `ProfileWithFeed.id` = UserSocialProfile ID | `ProfileWithFeed.id` = UserFeedProfile ID |
| Separate `feed_id` field | `feed_id` on ProfileWithFeed object |
| No `is_favorited` field | `is_favorited` boolean on profile |
| `GET /feeds/:id/starred-profiles` returns `{ profile_ids: [] }` | Returns `{ profiles: [] }` |

---

## Files Changed

### Backend (7 files)
- `migrations/023_consolidate_user_feed_profiles.sql` (new)
- `src/models/user_feed_profile.go` (new)
- `src/db/user_feed_profiles.go` (new)
- `src/services/profile_service.go`
- `src/services/feed_management_service.go`
- `src/services/feed_profile_favorite_service.go`
- `src/handlers/feed_profile_favorite_handler.go`

### Web (2 files)
- `types/api.ts`
- `lib/hooks/use-feed-favorites.ts`

### Scraper (1 file)
- `src/scheduler/default.py`

### Supabase (1 file)
- `supabase/functions/rss-feed/database.ts`
