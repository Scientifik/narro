# WILO -- Where I Left Off

**Status:** ⏸️ PLANNING (NOT IMPLEMENTED)
**Created:** 2026-02-05
**Last Updated:** 2026-02-06
**Implementation Status:** This is a planning document. WILO feature has NOT been implemented.

---

## Table of Contents

1. [Feature Overview](#feature-overview)
2. [Requirements](#requirements)
3. [The Race Condition Problem](#the-race-condition-problem)
4. [Data Model Changes](#data-model-changes)
5. [Backend API](#backend-api)
6. [Web Frontend Implementation](#web-frontend-implementation)
7. [Mobile App Implementation](#mobile-app-implementation)
8. [Performance Strategy](#performance-strategy)
9. [Implementation Phases](#implementation-phases)
10. [Testing Plan](#testing-plan)
11. [Open Questions and Future Enhancements](#open-questions-and-future-enhancements)

---

## Feature Overview

WILO (Where I Left Off) tracks the last feed item a user actually viewed in each feed, enabling them to return later and see exactly where they stopped reading. When a user re-opens a feed, a horizontal bar with an upward chevron appears in the timeline, separating new content (above) from previously-seen content (below).

### Core Principle

WILO tracks **actual scroll position** based on which items entered the viewport, not based on when the user last opened the feed. This means:

- User opens feed on Monday, scrolls through 20 posts, leaves.
- Returns Wednesday, sees 15 new posts above the divider, scrolls down 2 posts, leaves.
- Returns Thursday -- the divider appears after those 2 posts they scrolled on Wednesday, not at the Monday position.

### Initial Load Behavior

When a user opens a feed that has a WILO position, the feed does **not** start at the top. Instead, the initial render positions the WILO divider at the center of the viewport. The user sees the divider mid-screen with new items above (scroll up to see them) and previously-seen items below. This avoids the jarring experience of "load at top, then auto-scroll down."

### Mobile Scroll-to-Top

On mobile, a small floating button allows the user to jump to the top of the feed (latest posts). Tapping it scrolls to the top **and** immediately updates `wilo_feed_item_id` to the newest item, acting as a manual "mark all as read to here."

### What WILO Is Not (Initially)

- Not an unread count ("12 new posts").
- Not a manual bookmark system (though scroll-to-top on mobile has a "mark as read" side effect).

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Track the last feed item the user viewed (scrolled into viewport) per feed | Must Have |
| FR-2 | Display a horizontal bar with an upward chevron (^) between new and previously-seen items | Must Have |
| FR-3 | Cross-platform sync via database -- web and mobile share the same WILO state | Must Have |
| FR-4 | Automatic tracking as the user scrolls -- no manual action required | Must Have |
| FR-5 | Smart positioning: track actual last-viewed item, not "last time opened" | Must Have |
| FR-6 | WILO works per-feed (each feed has its own position) | Must Have |
| FR-7 | WILO position persists across sessions (page refresh, app restart) | Must Have |
| FR-8 | Divider only appears when there are newer items above the WILO position | Must Have |
| FR-9 | WILO works in all feed view types (list, grid, gallery on web; list, gallery on mobile) | Should Have |
| FR-10 | WILO works on the Home page when it displays a specific feed | Should Have |
| FR-11 | Feed loads with WILO divider positioned mid-screen on initial render (no "load then scroll" jump) | Must Have |
| FR-12 | Mobile: floating scroll-to-top button that also updates WILO to the latest item | Should Have |
| FR-13 | Navigating away from a feed (e.g., clicking another page, switching tabs) immediately flushes pending WILO update | Must Have |
| FR-14 | Exiting the app (closing tab, backgrounding mobile app) immediately flushes pending WILO update | Must Have |
| FR-15 | Component unmount flushes pending WILO update (covers all navigation and cleanup paths) | Must Have |

### Non-Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-1 | Cannot spam the database -- debouncing/throttling on client side | Must Have |
| NFR-2 | Update latency: WILO position should persist within 5 seconds of scrolling | Should Have |
| NFR-3 | No perceptible performance impact on feed scrolling | Must Have |
| NFR-4 | Backend endpoint must respond in under 50ms | Should Have |
| NFR-5 | Graceful degradation: if WILO update fails, feed still works normally | Must Have |

---

## The Race Condition Problem

### The Challenge

Social media posts are created on platforms (Twitter, Instagram, etc.) before we scrape them. This creates a **race condition** between when a post is created and when our scraper discovers it:

```
1:58 PM - Creator posts Tweet B on Twitter
2:00 PM - User opens feed, sees Tweet A (created 1:55 PM)
          Tweet B hasn't been scraped yet
2:02 PM - User scrolls, WILO saves position at Tweet A
2:05 PM - Scraper runs, discovers Tweet B (created 1:58 PM)
2:06 PM - Tweet B inserted into feed chronologically (above Tweet A)
3:00 PM - User returns, loads at WILO divider (Tweet A)
          Tweet B is ABOVE the divider but user never saw it ❌
```

**The problem:** If we order feeds by `posted_at` (when the post was created on the platform), posts can be **backfilled** between viewing sessions. The user thinks "I've seen everything down to the divider," but backfilled posts silently appear above it.

### The Solution: Import-Time Ordering

Instead of ordering feeds by when posts were created (`posted_at`), we order by when they were **imported into our database** (`imported_at`).

**How it works:**
- Each feed item gets an `imported_at` timestamp when first added to our database
- Feeds are sorted by `imported_at DESC, posted_at DESC` (import time primary, creation time secondary)
- WILO tracks `wilo_imported_at` instead of `wilo_posted_at`
- The divider is placed where `item.imported_at <= wilo_imported_at`

**Why it solves the race condition:**

```
2:00 PM - User sees Tweet A (imported 1:56 PM)
2:02 PM - WILO saves imported_at: 1:56 PM
2:05 PM - Scraper finds Tweet B (created 1:58 PM, imported 2:05 PM)
3:00 PM - User returns
          Tweet B has imported_at: 2:05 PM (after WILO: 1:56 PM)
          Tweet B appears ABOVE divider ✅ Correct!
```

**Result:** Everything above the divider was imported AFTER the user's last session. No backfill issues.

### Trade-offs

**Pros:**
- ✅ Eliminates race condition completely
- ✅ Simpler logic (no dual timestamps, no backfill detection)
- ✅ Clear mental model: "Below divider = I've seen. Above divider = I haven't."
- ✅ Works naturally with batch scraping

**Cons:**
- ⚠️ Feed is not strictly chronological by post creation time
  - Posts can be "out of order" by a few hours (scraper delay)
  - With frequent scraping (3-48 hours), drift is minimal
- ⚠️ Different from Twitter/Instagram (which show strict reverse-chronological)
- ✅ User sees "their feed timeline" (when posts appeared) not "global timeline"

### Real-World Example

**Scenario:** User follows 3 accounts with 6-hour scrape frequency:

```
Monday 12 PM scrape:
  - @alice: Post A (created 11 AM, imported 12 PM)
  - @bob: Post B (created 10 AM, imported 12 PM)

Monday 6 PM scrape:
  - @alice: Post C (created 5 PM, imported 6 PM)
  - @charlie: Post D (created 2 PM, imported 6 PM)  ← Missed in 12 PM scrape

User's feed at 7 PM:
┌─────────────────────────────────────────────┐
│ Post C (@alice, 5 PM, imported 6 PM)       │
│ Post D (@charlie, 2 PM, imported 6 PM)     │  ← Created before C, but imported same time
│ Post A (@alice, 11 AM, imported 12 PM)     │
│ Post B (@bob, 10 AM, imported 12 PM)       │
└─────────────────────────────────────────────┘
```

**Notice:** Post D (created 2 PM) appears below Post C (created 5 PM) because they were imported together at 6 PM. The secondary sort by `posted_at` maintains chronological order within each import batch.

**User perception:** "My feed shows posts in the order they appeared in my feed, not the exact global timeline." This is similar to how email works - messages appear in the order they arrived in your inbox, not when they were sent globally.

---

## Data Model Changes

### Approach: New Columns on the `feeds` Table

The `feeds` table is already **per-user** -- every row has a `user_id` column and each user has their own set of feed rows. There is no concept of shared feeds in Narro. This means we can add WILO tracking columns directly to the `feeds` table without any multi-user collision issues.

**Current `feeds` table schema (relevant columns):**

```sql
CREATE TABLE feeds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT,
    emoji TEXT,
    custom_image_url TEXT,
    description TEXT,
    rss_feed_url TEXT,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, name)
);
```

Since each feed row already belongs to exactly one user, adding `wilo_feed_item_id` and `wilo_posted_at` directly to this table is the simplest and most efficient approach.

### Benefits of Using the `feeds` Table

1. **No new table** -- no new RLS policies, no new model files, no additional complexity.
2. **Simple UPDATE by ID** -- `UPDATE feeds SET wilo_feed_item_id = $1, wilo_posted_at = $2 WHERE id = $3 AND user_id = $4` is a primary key lookup, extremely fast.
3. **WILO data comes for free** -- whenever the frontend fetches feed details via `GET /api/feeds/:id`, the WILO fields are already included in the response. No extra API call needed to fetch the position.
4. **Cascade behavior is automatic** -- deleting a feed deletes its WILO position (they are the same row).

### Migration 1: Add `imported_at` to `feed_items`

```sql
-- Migration: Add imported_at timestamp to feed_items
-- This tracks when each post was added to our database (import time),
-- as opposed to when it was created on the platform (posted_at).
-- Feeds will be ordered by imported_at to avoid race conditions with
-- backfilled posts.

ALTER TABLE feed_items
ADD COLUMN IF NOT EXISTS imported_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Backfill existing rows with created_at or NOW()
UPDATE feed_items
SET imported_at = COALESCE(created_at, NOW())
WHERE imported_at IS NULL;

-- Make it NOT NULL after backfill
ALTER TABLE feed_items
ALTER COLUMN imported_at SET NOT NULL;

-- Index for feed queries (primary sort key)
-- NOTE: feed_items does NOT have a feed_id column. Items belong to social_profiles.
-- The query joins through user_feed_profiles to find items for a given feed.
CREATE INDEX IF NOT EXISTS idx_feed_items_imported_at
ON feed_items(social_profile_id, imported_at DESC, posted_at DESC);
```

**Important:** The scraper must set `imported_at` only on INSERT, never on UPDATE. Re-scraping existing posts should not change their import timestamp.

### Migration 2: Add WILO Columns to `feeds`

```sql
-- Migration: Add WILO (Where I Left Off) tracking to feeds table
-- Adds columns to track the last feed item the user viewed in each feed.
-- Since feeds are already per-user (one row per user per feed), this is
-- the natural place to store per-user, per-feed read position.

ALTER TABLE feeds
ADD COLUMN IF NOT EXISTS wilo_feed_item_id UUID REFERENCES feed_items(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS wilo_imported_at TIMESTAMP WITH TIME ZONE;

-- Index for quick lookups (optional -- the primary key lookup on feeds.id
-- is already sufficient for the UPDATE query, but this helps if we ever
-- need to query "all feeds with a WILO position" for a user)
CREATE INDEX IF NOT EXISTS idx_feeds_wilo
ON feeds(user_id, wilo_feed_item_id)
WHERE wilo_feed_item_id IS NOT NULL;
```

**Column details:**

| Column | Type | Nullable | Purpose |
|--------|------|----------|---------|
| `wilo_feed_item_id` | UUID | YES (NULL = no position set) | References the last feed_item the user scrolled to |
| `wilo_imported_at` | TIMESTAMPTZ | YES (NULL = no position set) | The `imported_at` value of that feed item, for divider placement |

**ON DELETE SET NULL:** If the referenced feed_item is deleted (e.g., scraper cleanup), the WILO position gracefully becomes NULL rather than causing a foreign key violation. The `wilo_imported_at` timestamp is preserved so the divider can still be placed approximately correctly even when `wilo_feed_item_id` is NULL.

### Why Both `wilo_feed_item_id` and `wilo_imported_at`?

We store both the item reference and its timestamp because:

1. **Feed items are sorted by `imported_at DESC, posted_at DESC`** -- the timestamp lets the frontend determine divider placement without an extra database lookup.
2. **Resilience to item deletion**: If the exact feed_item is deleted, `wilo_imported_at` still allows correct divider placement by timestamp comparison.
3. **No extra JOIN needed**: The frontend already has `imported_at` on every feed item in the response, so comparing against `wilo_imported_at` is a simple in-memory operation.

### Migration Files

**Migration 1 File:** `backend/migrations/025_add_imported_at_to_feed_items.sql`
**Migration 2 File:** `backend/migrations/026_add_wilo_to_feeds.sql`

These are the next migrations in sequence (after `024_add_profile_import_jobs.sql`).

> **Note:** The `feed_items` table does NOT currently have a `feed_id` column. Feed items belong to `social_profiles`, and users see them via `user_feed_profiles` JOIN. The index in Migration 1 must NOT reference `feed_id`. See the corrected index below.

### GORM Model Updates

**Update the `FeedItem` model in `backend/src/models/feed_item.go`:**

```go
type FeedItem struct {
    // ... existing fields ...
    PostedAt   time.Time  `json:"posted_at"`   // When post was created on platform
    ImportedAt time.Time  `json:"imported_at"` // When post was added to our database (NEW)
    // ... other fields ...
}
```

**Update the `Feed` model in `backend/src/models/feed.go`:**

```go
type Feed struct {
    // ... existing fields ...

    // WILO (Where I Left Off) tracking
    WiloFeedItemID *uuid.UUID `json:"wilo_feed_item_id,omitempty" gorm:"type:uuid"`
    WiloImportedAt *time.Time `json:"wilo_imported_at,omitempty"` // Changed from WiloPostedAt
}
```

No new model files needed. The WILO fields are just two additional nullable columns on the existing `Feed` struct.

---

## Backend API

### Approach: One New Endpoint + Existing Feed Responses

Since WILO data lives on the `feeds` table, the **GET** side is already handled -- any endpoint that returns feed data (`GET /api/feeds/:id`, `GET /api/feeds`) will automatically include `wilo_feed_item_id` and `wilo_imported_at` in the response once the model is updated.

Only one new endpoint is needed: the **PUT** to update the WILO position.

### New Endpoint

#### PUT `/api/feeds/:id/wilo`

Update the WILO position for a specific feed.

**Request:**
```
PUT /api/feeds/:id/wilo
Authorization: Bearer <token>
Content-Type: application/json

{
    "feed_item_id": "uuid",
    "imported_at": "2026-02-05T12:00:00Z"
}
```

**Response (200 OK):**
```json
{
    "feed_id": "uuid",
    "wilo_feed_item_id": "uuid",
    "wilo_imported_at": "2026-02-05T12:00:00Z"
}
```

**Validation Rules:**
- `feed_item_id` must be a valid UUID.
- `imported_at` must be a valid RFC3339 timestamp.
- The feed (`:id`) must belong to the authenticated user.
- The endpoint should NOT validate that the `feed_item_id` actually exists in `feed_items` (for performance; the client is trusted).

**Database Query:**
```sql
UPDATE feeds
SET wilo_feed_item_id = $1, wilo_imported_at = $2, updated_at = NOW()
WHERE id = $3 AND user_id = $4 AND deleted_at IS NULL;
```

This is a simple primary key update with a user ownership check. No UPSERT needed since the feed row already exists.

### How WILO Data is Read

No dedicated GET endpoint is required. WILO data is included in existing feed responses:

| Existing Endpoint | WILO Data Included |
|---|---|
| `GET /api/feeds/:id` | Returns feed with `wilo_feed_item_id` and `wilo_imported_at` |
| `GET /api/feeds` | Returns all feeds, each with WILO fields |

### Feed Items Query (Updated for imported_at)

**All feed item queries must be updated to order by `imported_at` instead of `posted_at`.**

> **IMPORTANT:** The actual feed items query in `backend/src/db/feed_items.go` (`GetFeedItemsForUser`) uses a CTE-based raw SQL query, NOT a simple `SELECT ... FROM feed_items WHERE feed_id = $1`. The query joins `feed_items` with `user_feed_profiles` and `social_profiles`. The `ORDER BY` clause that needs changing is at the end of this CTE query. There is NO `feed_id` column on `feed_items` -- the feed association is through `user_feed_profiles`.

```sql
-- Current ORDER BY (in the final SELECT of the CTE query in feed_items.go):
ORDER BY posted_at DESC

-- Updated ORDER BY:
ORDER BY imported_at DESC, posted_at DESC
```

**Additional sort locations that must also be updated:**
- `backend/src/services/feed_service.go` line 258: The `GetPublicShowcaseFeed` raw SQL query has `ORDER BY feed_items.posted_at DESC` in a `ROW_NUMBER()` window function and `ORDER BY posted_at DESC` in the final query. These should be updated for consistency, though the showcase feed does not need WILO.
- `backend/src/services/feed_service.go`: The feed item response serialization (the `itemsMap` construction) must add `"imported_at"` to the response map.

This ordering ensures:
1. Posts appear in the order they were imported into the user's feed
2. Within each import batch, posts are chronological by creation time
3. No race condition - backfilled posts always appear above previous WILO position

The frontend already fetches feed details when opening a feed page. The WILO position arrives as part of that existing response -- zero additional network requests for the read path.

### Backend File Changes

#### New Files

| File | Purpose |
|------|---------|
| `backend/migrations/025_add_imported_at_to_feed_items.sql` | Add `imported_at` column to `feed_items` |
| `backend/migrations/026_add_wilo_to_feeds.sql` | Add WILO columns to `feeds` |
| `backend/src/services/wilo_service.go` | Business logic for WILO update |
| `backend/src/handlers/wilo_handler.go` | HTTP handler for PUT endpoint |

#### Modified Files

| File | Change |
|------|--------|
| `backend/src/models/feed.go` | Add `WiloFeedItemID` and `WiloImportedAt` fields to `Feed` struct |
| `backend/src/models/feed_item.go` | Add `ImportedAt` field to `FeedItem` struct |
| `backend/src/routes/routes.go` | Add `PUT /:id/wilo` route under feeds group |
| `backend/src/db/feed_items.go` | Update `ORDER BY posted_at DESC` to `ORDER BY imported_at DESC, posted_at DESC` in the CTE query; add `imported_at` to the SELECT column list |
| `backend/src/services/feed_service.go` | Add `"imported_at"` to the feed item response map in both `GetFeed` and `GetWideModeFeed` |

**Note:** No new DB operations file is needed. The update is a simple GORM `Updates()` call that can live in the service or a small helper:

```go
// In wilo_service.go
func (s *WiloService) UpdateWiloPosition(ctx context.Context, userID, feedID, feedItemID uuid.UUID, importedAt time.Time) error {
    result := s.db.WithContext(ctx).
        Model(&models.Feed{}).
        Where("id = ? AND user_id = ? AND deleted_at IS NULL", feedID, userID).
        Updates(map[string]interface{}{
            "wilo_feed_item_id": feedItemID,
            "wilo_imported_at":  importedAt,
        })
    if result.Error != nil {
        return result.Error
    }
    if result.RowsAffected == 0 {
        return gorm.ErrRecordNotFound
    }
    return nil
}
```

### Route Registration

```go
// In backend/src/routes/routes.go, within the protected feeds group.
// IMPORTANT: This route must be placed BEFORE the less specific `feeds.GET("/:id", ...)`
// and `feeds.PATCH("/:id", ...)` routes, alongside the other `/:id/...` routes.
// Place it near the feed profile routes (e.g., after the feed-config routes):
feeds.PUT("/:id/wilo", wiloHandler.UpdateWILO)
```

> **Note on `sendBeacon`:** The `navigator.sendBeacon()` API can only send POST requests, not PUT. For the `beforeunload` flush path on web, the backend should also accept `POST /:id/wilo` as an alias, or the web implementation should use `fetch` with `keepalive: true` exclusively (which supports PUT and custom headers). The recommended approach is to use `fetch` with `keepalive: true` for all flush paths and avoid `sendBeacon` entirely, since `sendBeacon` also cannot set `Authorization` headers.

---

## Web Frontend Implementation

### Overview

The web frontend needs to:
1. **Read** the WILO position from the existing feed details response (no extra fetch).
2. **Render** the divider bar at the correct position in the feed item list.
3. **Track** which items the user has scrolled past using Intersection Observer.
4. **Report** the latest viewed item to the backend (debounced).

### New Files

| File | Purpose |
|------|---------|
| `web/lib/hooks/use-wilo.ts` | Hook for tracking and updating WILO position |
| `web/components/feed/WiloDivider.tsx` | The horizontal bar with upward chevron |

### Modified Files

| File | Change |
|------|--------|
| `web/types/api.ts` | Add WILO fields to existing `Feed` interface |
| `web/lib/api-endpoints.ts` | Add WILO update endpoint |
| `web/components/feed/ListFeedView.tsx` | Integrate WILO divider and scroll tracking |
| `web/components/feed/GridFeedView.tsx` | Integrate WILO divider and scroll tracking |
| `web/components/feed/GalleryFeedView.tsx` | Integrate WILO divider and scroll tracking |
| `web/components/feed/FeedCard.tsx` | Add `data-feed-item-id` and `data-posted-at` attributes for observer |
| `web/app/(authenticated)/feed/[id]/page.tsx` | Wire up `useWilo` hook |
| `web/app/(authenticated)/home/page.tsx` | Wire up `useWilo` hook for specific_feed mode |

### TypeScript Type Changes

```typescript
// Update existing Feed interface in web/types/api.ts:
export interface Feed {
    id: string;
    user_id: string;
    name: string;
    color?: string;
    emoji?: string;
    custom_image_url?: string;
    description?: string;
    rss_feed_url?: string;
    is_default: boolean;
    // WILO fields (new)
    wilo_feed_item_id?: string | null;
    wilo_imported_at?: string | null;
    // timestamps
    created_at: string;
    updated_at: string;
}

// Update existing FeedItem interface to include imported_at:
export interface FeedItem {
    id: string;
    feed_id: string;
    // ... existing fields ...
    posted_at: string;   // When post was created on platform
    imported_at: string; // When post was added to our database (NEW)
    // ... other fields ...
}

// New request type:
export interface UpdateWiloRequest {
    feed_item_id: string;
    imported_at: string;
}
```

### API Endpoint Addition

```typescript
// Add to web/lib/api-endpoints.ts, inside feeds object:
updateWilo: (feedId: string) => `/api/feeds/${feedId}/wilo`,
```

### useWilo Hook

```typescript
// web/lib/hooks/use-wilo.ts
//
// This hook manages WILO tracking for a feed. It does NOT fetch WILO data --
// that comes from the existing feed details response. Instead, it:
//
// 1. Accepts the current feed's wilo_imported_at from the parent component.
// 2. Provides a `reportItemViewed` callback for scroll tracking.
// 3. Debounces backend updates (2000ms during continuous scrolling).
// 4. Flushes pending updates immediately on ANY exit path (see flush triggers below).
// 5. Only advances WILO forward (newer imported_at), never backward.
//
// Interface:
// function useWilo(feedId: string | null, currentWiloImportedAt: string | null): {
//     reportItemViewed: (feedItemId: string, importedAt: string) => void;
//     forceUpdate: (feedItemId: string, importedAt: string) => void;
//     flush: () => void;
// }
```

**Key implementation details:**

- `reportItemViewed` is called by the Intersection Observer in the feed view components.
- Internally, it keeps a `latestViewedRef` that updates instantly on every call.
- A debounced function (2000ms) sends the `PUT /api/feeds/:id/wilo` request when scrolling pauses.
- The hook compares the pending item's `imported_at` against `currentWiloImportedAt`. If the pending item is older or equal, the PUT is skipped (user scrolled backward -- we only advance WILO forward).

### Flush Triggers (Web)

The 2-second debounce exists only for continuous scrolling. **Any navigation, unmount, or app exit must flush the pending WILO update immediately.** The guiding principle is: if the user leaves the feed, we must persist their position -- even if they scrolled for less than 1 second.

The `useWilo` hook sets up and tears down these flush triggers internally:

| Trigger | Event / API | When It Fires | Flush Method |
|---------|-------------|---------------|--------------|
| **Tab/window close** | `beforeunload` on `window` | User closes the tab or browser | `navigator.sendBeacon()` (fire-and-forget, survives page teardown) |
| **Tab becomes hidden** | `visibilitychange` on `document` | User switches to another tab, minimizes browser | `fetch()` with `keepalive: true` (or `sendBeacon`) |
| **Route change (Next.js)** | `next/navigation` router events or `usePathname` change | User clicks a link, navigates to another page within Narro | `flush()` called from a `useEffect` cleanup or pathname watcher |
| **Component unmount** | `useEffect` cleanup (return function) | Feed page component is destroyed for any reason | `flush()` called synchronously in the cleanup |

**Implementation pattern:**

```typescript
// Inside useWilo hook:

const flush = useCallback(() => {
    // Cancel the pending debounce timer
    clearTimeout(debounceTimerRef.current);

    // If there is a pending update that has not been sent, send it now
    const pending = latestViewedRef.current;
    if (!pending || !feedId) return;

    // Forward-only check
    if (currentWiloImportedAt && pending.importedAt <= currentWiloImportedAt) return;

    // Send immediately (fire-and-forget)
    sendWiloUpdate(feedId, pending.feedItemId, pending.importedAt);

    // Clear the pending ref so we do not double-send
    latestViewedRef.current = null;
}, [feedId, currentWiloImportedAt]);

// Register global event listeners
useEffect(() => {
    const handleVisibilityChange = () => {
        if (document.visibilityState === 'hidden') flush();
    };
    const handleBeforeUnload = () => {
        // Use sendBeacon for reliability during page teardown
        const pending = latestViewedRef.current;
        if (pending && feedId) {
            const url = apiEndpoints.feeds.updateWilo(feedId);
            const body = JSON.stringify({
                feed_item_id: pending.feedItemId,
                imported_at: pending.importedAt,
            });
            navigator.sendBeacon(url, body);
            latestViewedRef.current = null;
        }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
        document.removeEventListener('visibilitychange', handleVisibilityChange);
        window.removeEventListener('beforeunload', handleBeforeUnload);
        // Flush on unmount (covers route changes, component destruction)
        flush();
    };
}, [flush, feedId]);
```

**Why component unmount is the most important trigger:** In Next.js, navigating from `/feed/abc` to `/profiles` or to another feed destroys the feed page component. The `useEffect` cleanup runs synchronously during unmount, giving the `flush()` function a reliable moment to send the pending update via a standard `fetch()` call. This single mechanism covers all in-app navigation paths without needing to hook into Next.js router events separately. The `beforeunload` and `visibilitychange` listeners cover the remaining cases (tab close, tab switch, browser minimize) where the component may not unmount cleanly.

**`sendBeacon` vs `fetch` with `keepalive`:**

| Method | Use Case | Why |
|--------|----------|-----|
| `navigator.sendBeacon(url, body)` | `beforeunload` handler | Guaranteed to fire even during page teardown. Does not block unload. Cannot set custom headers (no `Authorization`). |
| `fetch(url, { method: 'PUT', keepalive: true, ... })` | `visibilitychange`, component unmount | Supports custom headers (including `Authorization`). `keepalive: true` lets the request complete even if the page is being destroyed. |

**Important note on `sendBeacon` and auth:** `sendBeacon` cannot set custom `Authorization` headers. If the backend requires a Bearer token, the `sendBeacon` payload must include the token in the body (and the backend must support this alternate auth path), or use a cookie-based session that is sent automatically. Alternatively, use `fetch` with `keepalive: true` for all flush scenarios, which does support custom headers. The implementation should prefer `fetch` with `keepalive` unless testing reveals reliability issues on specific browsers.

### WILO Divider Component

```typescript
// web/components/feed/WiloDivider.tsx
//
// A horizontal bar spanning the full width with a centered upward chevron.
// Minimal and unobtrusive -- no text, just a visual marker.
//
// Visual design:
//   ─────────────── ^ ───────────────
//
// Implementation:
// - A <div> with a horizontal line (border-top or hr element).
// - A centered chevron icon (^) sitting on the line.
// - Uses DaisyUI/Tailwind classes for consistency.
// - Subtle color: muted/secondary tone so it is noticeable but not loud.
//
// Props:
// - className?: string (for view-type-specific adjustments)
```

**Design details:**
- The divider is a thin horizontal line (1px, muted color like `base-300` or `base-content/20`).
- Centered on the line is a small upward-pointing chevron icon.
- The chevron can be an SVG or a simple CSS triangle.
- No text label -- just the bar and chevron.
- Padding above and below (e.g., `my-4`) to give it breathing room between feed cards.

### Scroll Tracking with Intersection Observer

The feed views (`ListFeedView`, `GridFeedView`, `GalleryFeedView`) already use Intersection Observer for infinite scroll. WILO tracking adds a second observer that watches for feed items entering the viewport.

**Strategy for each feed view:**

1. Each feed item wrapper gets a `ref` callback registered with an Intersection Observer.
2. When an item enters the viewport (threshold: 0.5 -- at least 50% visible), the observer fires.
3. The callback calls `reportItemViewed(item.id, item.posted_at)`.
4. The hook internally determines if this item is "newer" than the last reported position and, if so, updates the debounced value.

**Direction-aware tracking:** WILO should only advance FORWARD in time (to newer `imported_at` values), never backward. Since feeds are sorted `imported_at DESC, posted_at DESC` (newest imported first):

- The most recently imported items are at the top of the page.
- Scrolling down means viewing older imports.
- The "newest item seen" is determined by comparing `imported_at` timestamps, not scroll direction.
- When the user opens the feed, the top items are the newest they have seen. WILO advances to those.

**Modified behavior for feed views:**

```typescript
// In ListFeedView.tsx (and similar for GridFeedView, GalleryFeedView):
//
// New props:
//   wiloImportedAt?: string | null;   // from feed.wilo_imported_at
//   onItemViewed?: (feedItemId: string, importedAt: string) => void;
//
// 1. Insert WiloDivider between items:
//    - Iterate through items. When we encounter the first item where
//      item.imported_at <= wiloImportedAt, insert the WiloDivider before it.
//    - If the first item in the list has imported_at <= wiloImportedAt,
//      do NOT show the divider (nothing new above it).
//    - If all items are newer than wiloImportedAt, show the divider
//      at the very end of the loaded items.
//
// 2. Set up Intersection Observer for scroll tracking:
//    - Observe each feed card element.
//    - On intersection (>= 50% visible), call onItemViewed(id, imported_at).
```

### Divider Placement Algorithm

Given:
- `items[]` sorted by `imported_at DESC, posted_at DESC` (newest imported first, then chronological)
- `wiloImportedAt` = the feed's `wilo_imported_at` timestamp

```
if wiloImportedAt is null or undefined:
    DO NOT show divider (no WILO position set)
    RETURN

if items[0].imported_at <= wiloImportedAt:
    DO NOT show divider (no new items above WILO position)
    RETURN

for i = 0 to items.length - 1:
    if items[i].imported_at <= wiloImportedAt:
        INSERT divider before items[i]
        RETURN

// If we get here, all loaded items are newer than WILO
APPEND divider after last item
```

**Edge cases:**

| Case | Behavior |
|------|----------|
| No WILO position (null) | No divider shown. First-time user or new feed. |
| No new items above WILO | No divider shown. User is caught up. |
| WILO item was deleted | `wilo_imported_at` still exists, divider placed by timestamp. `wilo_feed_item_id` may be NULL (ON DELETE SET NULL). |
| WILO position is beyond loaded pages | Divider not yet visible. Appears when user scrolls down to load that page. |
| Empty feed (no items) | No divider shown. |
| All items newer than WILO | Divider appears at bottom of loaded items. |

### Initial Scroll Positioning (Web)

When a feed has a WILO position, the page should render with the divider centered in the viewport from the very first paint. The user should never see the page load at the top and then jump down to the divider.

**Approach: `scrollIntoView` after first render**

```typescript
// In the feed page (feed/[id]/page.tsx) or inside the feed view component:

const wiloDividerRef = useRef<HTMLDivElement>(null);
const hasScrolledToWilo = useRef(false);

useEffect(() => {
    if (wiloDividerRef.current && !hasScrolledToWilo.current) {
        wiloDividerRef.current.scrollIntoView({
            block: 'center',
            behavior: 'instant',   // No smooth scroll -- immediate positioning
        });
        hasScrolledToWilo.current = true;
    }
}, [items]);  // Run when items are first loaded
```

**Key implementation details:**

1. **Use `behavior: 'instant'`** (not `'smooth'`). The user should see the divider mid-screen immediately, not watch the page scroll down to it. This prevents the jarring "load at top, then animate to WILO" experience.

2. **Suppress scroll tracking during initial scroll.** When the page initially positions to the WILO divider, all the items above the divider are technically "scrolled past" from the viewport's perspective. The `useWilo` hook must NOT treat these as viewed. Implementation approach:
   - Add a `suppressTracking` ref to the `useWilo` hook, initialized to `true`.
   - After the initial `scrollIntoView` fires and the browser settles (use a `requestAnimationFrame` or short `setTimeout`), set `suppressTracking` to `false`.
   - While `suppressTracking` is true, `reportItemViewed` is a no-op.

3. **Avoid layout shift.** The feed items should have stable, predictable heights. If items have images that load asynchronously, consider:
   - Setting explicit `aspect-ratio` or `min-height` on image containers.
   - Using the `loading="lazy"` attribute so images below the fold do not trigger layout changes above the divider.
   - Re-firing `scrollIntoView` once if a significant layout shift is detected (though this is a last resort).

4. **No WILO position (null).** If `wilo_posted_at` is null (new feed, first visit), the feed loads normally from the top. No `scrollIntoView` is called.

5. **Divider at bottom of loaded items.** If all loaded items are newer than WILO (the divider is at the bottom), scroll to the bottom of the loaded items. The divider may be near the infinite scroll trigger, which will load more items -- this is acceptable.

---

## Mobile App Implementation

### Overview

The mobile app uses React Native with Expo Router and React Query. The implementation parallels the web but uses React Native-specific APIs for scroll tracking.

### New Files

| File | Purpose |
|------|---------|
| `mobile/hooks/use-wilo.ts` | Hook for tracking/updating WILO with flush triggers (AppState, focus/blur, unmount) |
| `mobile/components/feed/WiloDivider.tsx` | Horizontal bar with upward chevron (React Native) |
| `mobile/components/feed/ScrollToTopButton.tsx` | Floating button: scroll to top + update WILO to latest item |

### Modified Files

| File | Change |
|------|--------|
| `mobile/types/api.ts` | Add WILO fields to existing `Feed` interface |
| `mobile/lib/api-endpoints.ts` | Add WILO update endpoint |
| `mobile/app/(tabs)/feed/[id].tsx` | Wire up `useWilo` hook, viewability tracking, `initialScrollIndex`, scroll-to-top FAB |
| `mobile/app/(tabs)/index.tsx` | Wire up `useWilo` hook for home feed |
| `mobile/components/feed/FeedCard.tsx` | Support WILO tracking |
| `mobile/components/feed/GalleryFeedView.tsx` | Support WILO tracking |

### Scroll Tracking on Mobile (FlatList)

React Native's `FlatList` does not have Intersection Observer. Instead, we use `onViewableItemsChanged`, which is specifically designed for this purpose.

```typescript
// In feed/[id].tsx:

const viewabilityConfig = useRef({
    itemVisiblePercentThreshold: 50,  // Item is "viewed" when 50% visible
    minimumViewTime: 300,             // Must be visible for 300ms
}).current;

const onViewableItemsChanged = useRef(({ viewableItems }: { viewableItems: ViewToken[] }) => {
    // Find the newest item among currently viewable items
    // Call reportItemViewed with that item's id and imported_at
}).current;

<FlatList
    // ... existing props
    viewabilityConfig={viewabilityConfig}
    onViewableItemsChanged={onViewableItemsChanged}
/>
```

**Key considerations:**
- `onViewableItemsChanged` fires as items scroll in and out of the viewport.
- `minimumViewTime: 300` ensures we only count items the user actually paused on, not items that flew past during fast scrolling.
- The `useWilo` hook on mobile uses the same debouncing strategy as web (2s for continuous scrolling, immediate flush on exit).

### Flush Triggers (Mobile)

Same principle as web: the 2-second debounce is only for continuous scrolling. Any navigation away from the feed screen or app exit must flush immediately.

| Trigger | Event / API | When It Fires | Flush Method |
|---------|-------------|---------------|--------------|
| **App backgrounded** | `AppState` listener (`active` -> `background` or `inactive`) | User switches apps, presses home button, locks screen | `flush()` called in AppState change handler |
| **Screen loses focus** | `useIsFocused()` from `@react-navigation/native` or Expo Router `useFocusEffect` | User taps a different tab (e.g., Profiles, Settings), navigates to another screen | `flush()` called when `isFocused` transitions from `true` to `false` |
| **Component unmount** | `useEffect` cleanup (return function) | Feed screen is destroyed for any reason | `flush()` called synchronously in the cleanup |

**Implementation pattern:**

```typescript
// Inside mobile useWilo hook:

const flush = useCallback(() => {
    // Cancel the pending debounce timer
    clearTimeout(debounceTimerRef.current);

    const pending = latestViewedRef.current;
    if (!pending || !feedId) return;

    // Forward-only check
    if (currentWiloImportedAt && pending.importedAt <= currentWiloImportedAt) return;

    // Send immediately
    sendWiloUpdate(feedId, pending.feedItemId, pending.importedAt);
    latestViewedRef.current = null;
}, [feedId, currentWiloImportedAt]);

// AppState flush
useEffect(() => {
    const subscription = AppState.addEventListener('change', (nextState) => {
        if (nextState === 'background' || nextState === 'inactive') {
            flush();
        }
    });
    return () => {
        subscription.remove();
        // Flush on unmount
        flush();
    };
}, [flush]);

// Screen focus/blur flush (Expo Router)
useFocusEffect(
    useCallback(() => {
        // Screen gained focus -- no action needed
        return () => {
            // Screen lost focus -- flush immediately
            flush();
        };
    }, [flush])
);
```

**Why both `AppState` and focus/blur are needed:**

- **`AppState`** catches the case where the user exits the app entirely (home button, app switcher, lock screen). The feed screen does not unmount in this case -- the app is simply suspended. `AppState` is the only reliable signal.
- **Focus/blur** catches the case where the user taps a different tab (e.g., from the feed tab to the profiles tab) within the app. The feed screen may or may not unmount depending on Expo Router's tab navigation behavior (tabs often keep screens mounted for fast switching). The `useFocusEffect` cleanup is the reliable signal here.
- **Component unmount** is the final safety net. If the screen is actually destroyed (e.g., navigation stack reset, deep link to another section), the `useEffect` cleanup fires and flushes.

All three triggers are idempotent -- if `latestViewedRef.current` is `null` (already flushed), the `flush()` call is a no-op. There is no risk of double-sending.

### WILO Divider (React Native)

```typescript
// mobile/components/feed/WiloDivider.tsx
//
// A React Native component rendering a horizontal bar with a centered upward chevron.
// Same visual concept as the web version but using React Native primitives.
//
// Structure:
// <View style={{ flexDirection: 'row', alignItems: 'center' }}>
//   <View style={{ flex: 1, height: 1, backgroundColor: borderColor }} />
//   <ChevronUpIcon />
//   <View style={{ flex: 1, height: 1, backgroundColor: borderColor }} />
// </View>
```

### Divider Insertion in FlatList

Since `FlatList` expects a flat array of items, we insert the WILO divider as a special item in the data array:

```typescript
const itemsWithDivider = useMemo(() => {
    if (!feed?.wilo_imported_at) return items;

    const wiloTime = new Date(feed.wilo_imported_at).getTime();

    // If the first item is at or before WILO, no new items -- skip divider
    if (items.length > 0 && new Date(items[0].imported_at).getTime() <= wiloTime) {
        return items;
    }

    const result: (FeedItem | { type: 'wilo-divider'; id: string })[] = [];
    let dividerInserted = false;

    for (const item of items) {
        if (!dividerInserted && new Date(item.imported_at).getTime() <= wiloTime) {
            result.push({ type: 'wilo-divider', id: 'wilo-divider' });
            dividerInserted = true;
        }
        result.push(item);
    }

    // If all items are newer, put divider at end
    if (!dividerInserted && items.length > 0) {
        result.push({ type: 'wilo-divider', id: 'wilo-divider' });
    }

    return result;
}, [items, feed?.wilo_imported_at]);

// In renderItem:
const renderItem = ({ item }: { item: FeedItem | { type: string; id: string } }) => {
    if ('type' in item && item.type === 'wilo-divider') {
        return <WiloDivider />;
    }
    return <FeedCard item={item as FeedItem} ... />;
};

// In keyExtractor:
const keyExtractor = (item: any) => item.id;
```

### Initial Scroll Positioning (Mobile)

When a feed has a WILO position, the FlatList should render with the divider centered on screen from the start, not at the top.

**Approach: `initialScrollIndex` on FlatList**

```typescript
// Calculate the index of the WILO divider in the combined items array:
const wiloDividerIndex = useMemo(() => {
    if (!feed?.wilo_imported_at) return undefined;
    const idx = itemsWithDivider.findIndex(
        (item) => 'type' in item && item.type === 'wilo-divider'
    );
    return idx >= 0 ? idx : undefined;
}, [itemsWithDivider, feed?.wilo_imported_at]);

<FlatList
    // ... existing props
    initialScrollIndex={wiloDividerIndex}
    getItemLayout={getItemLayout}   // Required when using initialScrollIndex
/>
```

**Key implementation details:**

1. **`getItemLayout` is required BUT conflicts with current architecture.** When using `initialScrollIndex`, React Native's FlatList needs to know item dimensions without rendering them first. However, the current mobile codebase **intentionally removed `getItemLayout`** from the feed detail screen because feed cards have variable heights (images vs no images, long text vs short text). The comment in `mobile/app/(tabs)/feed/[id].tsx` (line 20) reads: _"getItemLayout removed because feed cards have variable heights... A fixed estimate causes FlatList to miscalculate item positions, which combined with removeClippedSubviews causes images to vanish after loading."_

**Alternative approach: Use `scrollToIndex` after render instead of `initialScrollIndex`.** This avoids the `getItemLayout` requirement:

```typescript
// After items are loaded and divider index is known:
const flatListRef = useRef<FlatList>(null);
const hasScrolledToWilo = useRef(false);

useEffect(() => {
    if (wiloDividerIndex !== undefined && !hasScrolledToWilo.current && flatListRef.current) {
        // Use a short delay to let FlatList measure items
        setTimeout(() => {
            flatListRef.current?.scrollToIndex({
                index: wiloDividerIndex,
                animated: false,
                viewPosition: 0.5, // Center the divider
            });
            hasScrolledToWilo.current = true;
        }, 100);
    }
}, [wiloDividerIndex]);

// Handle scrollToIndex failure (item not yet rendered):
const onScrollToIndexFailed = useCallback((info: { index: number }) => {
    // Scroll to nearest available position, then retry
    flatListRef.current?.scrollToOffset({ offset: info.averageItemLength * info.index, animated: false });
    setTimeout(() => {
        flatListRef.current?.scrollToIndex({ index: info.index, animated: false, viewPosition: 0.5 });
    }, 100);
}, []);
```

This approach trades a brief "load at top then jump" for reliability. The jump is minimized by using `animated: false` and a very short delay. If pixel-perfect initial positioning is critical, `getItemLayout` would need to be re-implemented with more accurate height estimates, potentially using a pre-measurement pass.

2. **Suppress scroll tracking during initial positioning.** Same concept as web -- the `useWilo` hook has a `suppressTracking` ref that starts `true` and is set to `false` after the initial scroll settles. Use a short `setTimeout` (e.g., 500ms) after mount to flip the flag.

3. **No WILO position (null).** If `wilo_posted_at` is null, do not set `initialScrollIndex`. FlatList renders from the top as usual.

4. **Height estimation tolerance.** The `getItemLayout` heights do not need to be pixel-perfect. FlatList uses them to calculate an approximate scroll offset for `initialScrollIndex`. Once rendered, the actual item heights take over. A small mismatch means the divider may not be perfectly centered, but it will be close enough. Refine the estimates based on actual FeedCard measurements during testing.

### Scroll-to-Top Button (Mobile)

A floating action button (FAB) in the bottom-right corner of the feed screen. It provides two actions in one tap: scroll to the top of the feed AND advance WILO to the latest (newest) item.

**New file:** `mobile/components/feed/ScrollToTopButton.tsx`

```typescript
// mobile/components/feed/ScrollToTopButton.tsx
//
// A small circular floating button with an upward arrow/chevron icon.
// Positioned in the bottom-right corner of the feed screen.
//
// Props:
//   onPress: () => void;      // Parent handles the scroll + WILO update
//   visible?: boolean;        // Show/hide based on scroll position (optional)
//
// Behavior:
// - Appears when the user has scrolled down (not at the top of the feed).
// - Tapping it triggers the parent's onPress handler.
// - Uses Animated fade-in/fade-out for smooth appearance.
//
// Visual:
// - Small circle (40x40 or 44x44) with subtle shadow/elevation.
// - Uses the app's secondary/accent color.
// - Contains an upward-pointing chevron or arrow icon.
// - Positioned with { position: 'absolute', bottom: 20, right: 20 }.
```

**Integration in `mobile/app/(tabs)/feed/[id].tsx`:**

```typescript
const flatListRef = useRef<FlatList>(null);
const { reportItemViewed, forceUpdate } = useWilo(feedId, feed?.wilo_imported_at);

// Track whether user has scrolled down (to show/hide FAB)
const [showScrollToTop, setShowScrollToTop] = useState(false);
const onScroll = useCallback((event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const offsetY = event.nativeEvent.contentOffset.y;
    setShowScrollToTop(offsetY > 300);  // Show FAB after scrolling 300px
}, []);

const handleScrollToTop = useCallback(() => {
    // 1. Scroll to top
    flatListRef.current?.scrollToOffset({ offset: 0, animated: true });

    // 2. Immediately update WILO to the newest item
    if (items.length > 0) {
        const newest = items[0];  // Items are sorted imported_at DESC, posted_at DESC
        forceUpdate(newest.id, newest.imported_at);
    }
}, [items, forceUpdate]);

// In the JSX:
<View style={{ flex: 1 }}>
    <FlatList
        ref={flatListRef}
        onScroll={onScroll}
        scrollEventThrottle={100}
        // ... other props
    />
    <ScrollToTopButton
        visible={showScrollToTop}
        onPress={handleScrollToTop}
    />
</View>
```

**`forceUpdate` method on the `useWilo` hook:**

The `useWilo` hook needs an additional method beyond `reportItemViewed`. While `reportItemViewed` goes through debouncing logic, `forceUpdate` bypasses the debounce and immediately sends the PUT request. This is used by the scroll-to-top button because:

- The user explicitly tapped a button (not passively scrolling), so the intent is clear.
- The update should be instant, not delayed by 2 seconds.
- The WILO position should reflect the newest item immediately.

```typescript
// In use-wilo.ts (both web and mobile):
//
// Return type:
// {
//     reportItemViewed: (feedItemId: string, importedAt: string) => void;
//     forceUpdate: (feedItemId: string, importedAt: string) => void;
// }
//
// forceUpdate:
//   1. Cancels any pending debounced update.
//   2. Immediately sends PUT /api/feeds/:id/wilo with the given item.
//   3. Updates the internal latestViewedRef.
//   4. Still respects forward-only rule (only advances, never regresses).
```

---

## Performance Strategy

### The Problem

A user scrolling through a feed could trigger hundreds of "item viewed" events per session. Without controls, this would generate excessive API calls that:
- Overload the backend with PUT requests.
- Waste bandwidth on mobile networks.
- Increase database write load unnecessarily.

### Client-Side Debouncing (Continuous Scrolling Only)

**Approach:** The `useWilo` hook maintains a local ref (`latestViewedRef`) that updates instantly on every `reportItemViewed` call. A debounced function sends the actual API request only after the user has stopped scrolling for a defined interval.

```
User scrolls continuously:
  t=0ms    item A viewed -> latestViewedRef = A
  t=100ms  item B viewed -> latestViewedRef = B
  t=200ms  item C viewed -> latestViewedRef = C
  t=300ms  item D viewed -> latestViewedRef = D
  t=300ms  (user pauses scrolling)
  t=2300ms (debounce fires) -> PUT /api/feeds/:id/wilo { item: D }
```

**Debounce interval:** 2000ms (2 seconds).

This means the backend receives at most one request per 2-second scrolling pause, regardless of how many items the user scrolled past.

**Critical distinction: the 2-second debounce applies ONLY during continuous scrolling.** Any navigation, unmount, or app exit bypasses the debounce and flushes immediately. This ensures we never lose WILO position, even if the user scrolled for less than 1 second before leaving.

```
User scrolls then navigates away quickly:
  t=0ms    item A viewed -> latestViewedRef = A
  t=200ms  item B viewed -> latestViewedRef = B
  t=400ms  user taps Profiles tab
  t=400ms  (flush fires immediately) -> PUT /api/feeds/:id/wilo { item: B }
  (the 2s debounce timer is cancelled -- flush took priority)
```

### Immediate Flush Triggers

The `useWilo` hook's `flush()` method cancels any pending debounce timer and sends the PUT request immediately. It is triggered by:

**Web:**
- `beforeunload` event (tab/window close)
- `visibilitychange` event (tab hidden, browser minimized)
- Component unmount (`useEffect` cleanup -- covers all Next.js route changes)

**Mobile:**
- `AppState` change to `background` or `inactive` (app exit, home button, lock screen)
- Screen blur via `useFocusEffect` cleanup (tab switch within the app)
- Component unmount (`useEffect` cleanup -- covers navigation stack changes)

All flush triggers are idempotent. If the pending update was already sent (by debounce or a prior flush), calling `flush()` again is a no-op.

See the [Web Frontend: Flush Triggers](#flush-triggers-web) and [Mobile: Flush Triggers](#flush-triggers-mobile) sections for full implementation details.

### Request Optimization

1. **Skip redundant updates:** Before sending the PUT, compare the pending item's `imported_at` against the current WILO position's `wilo_imported_at`. If the pending item is older or equal, skip the request entirely (user scrolled backward into old content).

2. **Fire-and-forget:** WILO updates are non-blocking. The PUT request is sent asynchronously and the result is not awaited. If it fails, log the error but do not retry or show an error to the user.

3. **No lost positions:** Between the debounce (for scrolling) and the immediate flush triggers (for navigation/exit), there is no scenario where a viewed item goes unreported. The worst-case latency is 2 seconds (user is still scrolling). The moment they stop interacting with the feed -- whether by pausing, navigating, or exiting -- the update fires.

### Backend Optimization

1. **Simple UPDATE by primary key:** The PUT endpoint runs a single UPDATE statement on the `feeds` table, which has a primary key index on `id`. This is as fast as a database write can get:
   ```sql
   UPDATE feeds
   SET wilo_feed_item_id = $1, wilo_imported_at = $2, updated_at = NOW()
   WHERE id = $3 AND user_id = $4 AND deleted_at IS NULL;
   ```

2. **No validation of feed_item_id existence:** We trust the client to send a real item ID. Validating it would require a JOIN to `feed_items` on every update, which adds unnecessary overhead.

3. **Lightweight response:** The PUT returns only the feed_id and updated WILO fields (no full feed object, no JOINs).

4. **No separate GET needed:** WILO data is included in existing feed responses automatically, eliminating any read-path overhead.

### Estimated Backend Load

Assumptions:
- 1,000 active users.
- Average user checks 3 feeds per session.
- Average session includes ~5 scroll pauses per feed (2-second debounce).
- 2 sessions per day per user.

Writes per day: 1,000 x 3 x 5 x 2 = 30,000 writes/day = ~0.35 writes/second.

This is well within PostgreSQL's capabilities and far from being a concern. Even at 10x this scale, the load is trivial.

---

## Implementation Phases

### Phase 1: Backend Foundation

**Scope:** Database migration, model update, service, handler, route.

**Agent:** Backend Architect

**Tasks:**

1. Create migration file `backend/migrations/025_add_imported_at_to_feed_items.sql` with ALTER TABLE adding `imported_at` column to `feed_items`.
2. Create migration file `backend/migrations/026_add_wilo_to_feeds.sql` with ALTER TABLE adding `wilo_feed_item_id` and `wilo_imported_at` columns to `feeds`.
3. Update `backend/src/models/feed_item.go` to add `ImportedAt` field to the `FeedItem` struct.
4. Update `backend/src/models/feed.go` to add `WiloFeedItemID` and `WiloImportedAt` fields to the `Feed` struct.
5. Update all feed item queries:
   - In `backend/src/db/feed_items.go` `GetFeedItemsForUser`: add `fi.imported_at` to the CTE SELECT column list (after `fi.posted_at`), and change `ORDER BY posted_at DESC` to `ORDER BY imported_at DESC, posted_at DESC`.
   - In `backend/src/services/feed_service.go` `GetFeed` and `GetWideModeFeed`: add `"imported_at": item.ImportedAt.Format(time.RFC3339)` to the `itemsMap` response serialization.
   - In `backend/src/db/feed_items.go` `FeedItemWithAuthor` struct: no change needed (it embeds `models.FeedItem` which will have the new `ImportedAt` field).
6. Update scraper: add `imported_at` column to `scraper/src/models/feed_item.py` SQLAlchemy model. In `scraper/src/db/queries.py`, the `insert_feed_items` function uses `db.add(item)` which will automatically set `imported_at` via the column default. Verify that re-scraping existing posts (which are skipped by `_get_existing_post_ids`) does NOT update `imported_at`.
7. Create service file `backend/src/services/wilo_service.go` with `UpdateWiloPosition` method.
8. Create handler file `backend/src/handlers/wilo_handler.go` with `UpdateWILO` handler.
9. Update `backend/src/routes/routes.go` to register `PUT /:id/wilo` under the feeds group.

**Definition of Done:**
- Both migrations run successfully.
- `feed_items` table has `imported_at` column populated for all rows.
- Feed queries return items ordered by `imported_at DESC, posted_at DESC`.
- Scraper sets `imported_at` on INSERT, preserves it on UPDATE.
- `GET /api/feeds/:id` returns `wilo_feed_item_id: null` and `wilo_imported_at: null` for feeds with no WILO position.
- `GET /api/feed-items` returns items with `imported_at` field.
- `PUT /api/feeds/:id/wilo` updates the WILO position and returns 200.
- `PUT /api/feeds/:id/wilo` returns 404 if the feed does not belong to the user.
- `GET /api/feeds` returns all feeds with their WILO fields.
- Existing feed functionality is unaffected.

### Phase 2: Web Frontend

**Scope:** Type updates, endpoint, hook, divider component, feed view integration.

**Agent:** Narro Web Developer

**Tasks:**

1. Update `Feed` interface in `web/types/api.ts` to add `wilo_feed_item_id` and `wilo_imported_at` optional fields.
2. Update `FeedItem` interface in `web/types/api.ts` to add `imported_at` field.
3. Add `UpdateWiloRequest` type and `updateWilo` endpoint path to `web/lib/api-endpoints.ts`.
4. Create `web/lib/hooks/use-wilo.ts` with debounced tracking logic and flush triggers:
   - 2s debounce for continuous scrolling.
   - `flush()` method that cancels debounce and sends immediately.
   - Register `beforeunload` and `visibilitychange` listeners.
   - Flush on component unmount via `useEffect` cleanup.
   - Handle `sendBeacon` vs `fetch` with `keepalive` for page teardown scenarios.
5. Create `web/components/feed/WiloDivider.tsx` -- horizontal bar with upward chevron.
6. Update `web/components/feed/FeedCard.tsx` to include `data-feed-item-id` and `data-imported-at` attributes.
7. Update `web/components/feed/ListFeedView.tsx`:
   - Accept `wiloImportedAt` and `onItemViewed` props.
   - Insert `WiloDivider` at the correct position in the item list.
   - Set up Intersection Observer for item tracking.
8. Update `web/components/feed/GridFeedView.tsx` (same pattern as list view).
9. Update `web/components/feed/GalleryFeedView.tsx` (same pattern as list view).
10. Update `web/app/(authenticated)/feed/[id]/page.tsx`:
    - Pass `feed.wilo_imported_at` to feed view as `wiloImportedAt`.
    - Integrate `useWilo(feedId, feed.wilo_imported_at)`.
    - Pass `reportItemViewed` to the feed view component as `onItemViewed`.
11. Implement initial scroll positioning:
    - Add `wiloDividerRef` to `WiloDivider` component and expose it via `forwardRef`.
    - In the feed page, call `scrollIntoView({ block: 'center', behavior: 'instant' })` on mount when WILO position exists.
    - Add `suppressTracking` flag to `useWilo` hook to prevent initial scroll from triggering WILO updates.
    - Ensure layout stability with explicit image container dimensions.
12. Update `web/app/(authenticated)/home/page.tsx`:
    - Same integration when in `specific_feed` mode.

**Definition of Done:**
- Opening a feed shows the chevron divider bar at the correct position based on `imported_at`.
- Feed items are displayed in order by `imported_at DESC, posted_at DESC`.
- Feed loads with WILO divider centered mid-screen on initial render (no visible scroll jump).
- Scroll tracking is suppressed during initial scroll positioning (items above WILO are not marked as viewed).
- Scrolling through feed items updates the WILO position (verify in database).
- Refreshing the page preserves the WILO position.
- Reading on web updates the position that mobile will see.
- No perceptible scroll performance degradation.
- Divider does not appear for new feeds with no WILO position.
- Divider does not appear when there are no new items above the position.
- Navigating to another page within Narro flushes pending WILO (verify position persists after quick scroll + navigate).
- Closing the tab flushes pending WILO (verify via `sendBeacon` / `keepalive` fetch).
- Switching tabs (visibilitychange) flushes pending WILO.
- No race condition - backfilled posts always appear above WILO divider.

### Phase 3: Mobile App

**Scope:** Type updates, endpoint, hook, divider component, feed screen integration.

**Agent:** Mobile App Architect

**Tasks:**

1. Update `Feed` interface in `mobile/types/api.ts` to add `wilo_feed_item_id` and `wilo_imported_at` fields.
2. Update `FeedItem` interface in `mobile/types/api.ts` to add `imported_at` field.
3. Add WILO update endpoint to `mobile/lib/api-endpoints.ts`.
4. Create `mobile/hooks/use-wilo.ts` with debounced tracking and all flush triggers:
   - 2s debounce for continuous scrolling.
   - `flush()` method that cancels debounce and sends immediately.
   - `AppState` listener for app backgrounding/inactive.
   - `useFocusEffect` cleanup for screen blur (tab switching within the app).
   - `useEffect` cleanup for component unmount.
5. Create `mobile/components/feed/WiloDivider.tsx` -- React Native horizontal bar with chevron.
6. Update `mobile/app/(tabs)/feed/[id].tsx`:
   - Integrate `useWilo(feedId, feed?.wilo_imported_at)`.
   - Add `viewabilityConfig` and `onViewableItemsChanged` to FlatList.
   - Insert WILO divider item into the data array.
   - Handle divider rendering in `renderItem`.
7. Implement initial scroll positioning:
   - Calculate `wiloDividerIndex` from the combined items array.
   - Set `initialScrollIndex` on FlatList when WILO position exists.
   - Implement `getItemLayout` with estimated item heights for FlatList.
   - Add `suppressTracking` flag to mobile `useWilo` hook.
8. Create `mobile/components/feed/ScrollToTopButton.tsx`:
   - Floating circular button with upward chevron, positioned bottom-right.
   - Animated fade-in/fade-out based on scroll position.
   - On press: scroll FlatList to top AND call `forceUpdate` with newest item.
9. Integrate scroll-to-top button in `mobile/app/(tabs)/feed/[id].tsx`:
   - Track scroll offset to show/hide FAB (visible after scrolling down 300px).
   - Wire `handleScrollToTop` to `flatListRef.scrollToOffset` + `forceUpdate`.
10. Add `forceUpdate` method to `useWilo` hook (both web and mobile):
    - Bypasses debounce, immediately sends PUT request.
    - Cancels any pending debounced update.
    - Still respects forward-only rule.
11. Update `mobile/components/feed/GalleryFeedView.tsx` for WILO support.
12. Update `mobile/app/(tabs)/index.tsx` for WILO on home feed.

**Definition of Done:**
- Same as web, but on iOS and Android.
- Feed items are displayed in order by `imported_at DESC, posted_at DESC`.
- FlatList `onViewableItemsChanged` correctly tracks viewed items.
- AppState background flush works reliably.
- Divider renders correctly in both list and gallery views.
- Feed opens with WILO divider centered on screen (not at top).
- Scroll-to-top FAB appears when scrolled down, hides at top.
- Tapping scroll-to-top scrolls to top and updates WILO to newest item.
- Switching tabs within the app flushes pending WILO (verify position persists after quick scroll + tab switch).
- Backgrounding the app flushes pending WILO (verify position persists after quick scroll + home button).
- Component unmount flushes pending WILO.
- No race condition - backfilled posts always appear above WILO divider.

### Phase 4: Polish and Edge Cases

**Scope:** Handle edge cases, refine UX.

**Tasks:**

1. Handle deleted feed items (WILO item no longer in feed -- `wilo_feed_item_id` is NULL but `wilo_posted_at` remains).
2. Handle empty feeds (no items at all -- do not show divider).
3. Handle very old WILO positions (WILO item is beyond loaded pages in infinite scroll -- divider appears when user scrolls to that point).
4. Test cross-device sync (read on web, verify divider on mobile).
5. Performance audit: measure scroll jank, debounce effectiveness.
6. Ensure `sendBeacon` flush works on web tab close.
7. Ensure `AppState` flush works on mobile app background.

---

## Testing Plan

### Backend Tests

| Test | Description |
|------|-------------|
| `GET /feeds/:id` includes WILO fields | Feed response contains `wilo_feed_item_id` and `wilo_imported_at` (both null initially) |
| `GET /feed-items` includes `imported_at` | Feed items include `imported_at` timestamp |
| Feed items ordered correctly | Items returned in `imported_at DESC, posted_at DESC` order |
| `PUT /feeds/:id/wilo` sets position | Updates WILO columns on the feed row |
| `PUT /feeds/:id/wilo` overwrites position | Second PUT updates existing values |
| `PUT /feeds/:id/wilo` with wrong user | Returns 404 (feed not found for this user) |
| `PUT /feeds/:id/wilo` with invalid UUID | Returns 400 |
| `GET /feeds` includes WILO for all feeds | All feeds in list include WILO fields |
| Feed item deletion sets WILO to NULL | ON DELETE SET NULL clears `wilo_feed_item_id` but preserves `wilo_imported_at` |
| Feed deletion cascades | Deleting a feed removes WILO data (same row) |
| Scraper sets `imported_at` on INSERT | New feed items have `imported_at` populated |
| Scraper preserves `imported_at` on UPDATE | Re-scraping existing posts doesn't change `imported_at` |

### Web Frontend Tests

| Test | Description |
|------|-------------|
| Divider renders correctly | Appears between correct items based on `imported_at` timestamp |
| Divider not shown for new feed | No divider when `wilo_imported_at` is null |
| Divider not shown when caught up | No divider when first item `imported_at` is at or before WILO |
| Feed items ordered correctly | Items displayed in `imported_at DESC, posted_at DESC` order |
| No race condition | Backfilled posts (created before session, imported after) appear above divider |
| Scroll tracking fires | Intersection Observer calls `reportItemViewed` |
| Debouncing works | Only one PUT per scroll pause (2s) |
| Forward-only tracking | Scrolling backward does not regress WILO position |
| Page unload flushes (`beforeunload`) | Closing the tab sends pending WILO via `sendBeacon` or `fetch` with `keepalive` |
| Tab hidden flushes (`visibilitychange`) | Switching to another browser tab immediately sends pending WILO |
| Route change flushes (component unmount) | Navigating to another page within Narro flushes pending WILO during `useEffect` cleanup |
| Quick scroll then navigate | Scrolling for < 1 second then navigating away still persists the WILO position |
| Flush is idempotent | Multiple flush triggers firing in sequence do not cause duplicate PUT requests |
| Flush respects forward-only | Flush does not send update if pending position is older than current WILO |
| Cross-device sync | Position set on web appears on mobile |
| Initial scroll to WILO | Feed loads with divider centered mid-screen, no visible scroll jump |
| Suppress tracking on initial scroll | Items above divider are not marked as viewed during initial positioning |
| No initial scroll for new feed | Feed with null WILO loads from top normally |
| Works in list view | Divider and tracking work in list mode |
| Works in grid view | Divider and tracking work in grid mode |
| Works in gallery view | Divider and tracking work in gallery mode |

### Mobile Tests

| Test | Description |
|------|-------------|
| Divider renders in FlatList | Special divider item renders correctly |
| `onViewableItemsChanged` tracks | Callback fires with correct items |
| AppState flush (background) | Backgrounding the app immediately flushes pending WILO |
| AppState flush (inactive) | Locking the screen immediately flushes pending WILO |
| Screen blur flush (tab switch) | Switching to another tab in the app immediately flushes pending WILO |
| Component unmount flush | Navigating away from feed screen via stack navigation flushes pending WILO |
| Quick scroll then tab switch | Scrolling for < 1 second then tapping another tab still persists the WILO position |
| Flush is idempotent | AppState + blur + unmount all firing does not cause duplicate PUT requests |
| Gallery view support | Divider works in gallery mode |
| Initial scroll to WILO | FlatList renders with divider centered via `initialScrollIndex` |
| Suppress tracking on initial scroll | Items above divider are not marked as viewed during initial positioning |
| No initial scroll for new feed | Feed with null WILO loads from top normally |
| Scroll-to-top FAB appears | Button visible after scrolling down 300px |
| Scroll-to-top FAB hidden at top | Button not visible when at top of feed |
| Scroll-to-top scrolls to top | Tapping FAB scrolls FlatList to offset 0 |
| Scroll-to-top updates WILO | Tapping FAB immediately sets WILO to newest item |
| `forceUpdate` bypasses debounce | PUT request fires instantly, not after 2s delay |
| `forceUpdate` respects forward-only | Cannot regress WILO position via forceUpdate |
| Performance | No scroll jank on mid-range devices |

### Integration / E2E Tests

| Test | Description |
|------|-------------|
| Full flow: scroll then return | User scrolls feed, leaves, returns, sees divider |
| Cross-platform sync | Read on web, check divider position on mobile |
| New items added by scraper | After new posts are scraped, divider position is still correct |
| Multiple feeds | Each feed maintains independent WILO position |
| Feed with filters | WILO tracking works correctly when filters are active |
| Quick exit preserves position | User scrolls briefly, exits (any method), returns later, divider is at correct position |
| Rapid tab switching | Quickly switching between feed tab and other tabs does not lose WILO state or cause errors |

---

## Open Questions and Future Enhancements

### Open Questions

1. **Wide Mode:** Should WILO work in Wide Mode (aggregated view of all feeds)? This would require a special mechanism since Wide Mode is not a real feed.
   - **Recommendation:** Defer. Wide Mode can be added later.

2. **"All Feeds" home display mode:** Similar to Wide Mode -- when the home page shows `all_feeds` mode, there is no single feed_id. Defer WILO for this mode.

3. **Feed sorting changes:** If a user changes feed sorting (e.g., oldest first), how does WILO behave?
   - **Recommendation:** WILO always tracks based on `posted_at` timestamp. The divider is placed based on chronological comparison regardless of display sort order.

### Future Enhancements (Not in Initial Scope)

| Enhancement | Description |
|-------------|-------------|
| Unread count badges | Show "12 new" on feed cards in the feed management hub |
| Web scroll-to-top with WILO update | Port the mobile scroll-to-top FAB to web (button or keyboard shortcut) |
| WILO for Wide Mode | Track position in the aggregated all-feeds view |
| Animated divider | Subtle fade-in animation on the divider when first visible |
| WILO analytics | Track how often users reach their WILO position (engagement metric) |

---

## Quick Reference: File Changes Summary

### New Files

| File | Component | Description |
|------|-----------|-------------|
| `backend/migrations/025_add_imported_at_to_feed_items.sql` | Backend | ALTER TABLE migration for `imported_at` |
| `backend/migrations/026_add_wilo_to_feeds.sql` | Backend | ALTER TABLE migration for WILO fields |
| `backend/src/services/wilo_service.go` | Backend | WILO update logic |
| `backend/src/handlers/wilo_handler.go` | Backend | HTTP handler for PUT |
| `web/lib/hooks/use-wilo.ts` | Web | Debounced tracking hook with flush triggers |
| `web/components/feed/WiloDivider.tsx` | Web | Chevron divider component |
| `mobile/hooks/use-wilo.ts` | Mobile | Debounced tracking hook with `forceUpdate`, `flush`, AppState + focus/blur triggers |
| `mobile/components/feed/WiloDivider.tsx` | Mobile | Chevron divider component (RN) |
| `mobile/components/feed/ScrollToTopButton.tsx` | Mobile | Floating button: scroll to top + mark all as read |

### Modified Files

| File | Component | Description |
|------|-----------|-------------|
| `backend/src/models/feed_item.go` | Backend | Add `ImportedAt` field to FeedItem struct |
| `backend/src/models/feed.go` | Backend | Add WILO fields to Feed struct |
| `backend/src/routes/routes.go` | Backend | Add PUT /:id/wilo route |
| `backend/src/db/feed_items.go` | Backend | Add `imported_at` to CTE SELECT columns; update ORDER BY to `imported_at DESC, posted_at DESC` |
| `scraper/src/db/queries.py` | Scraper | Set `imported_at` on INSERT (in `insert_feed_items`), preserve on UPDATE |
| `scraper/src/models/feed_item.py` | Scraper | Add `imported_at` column to SQLAlchemy `FeedItem` model |
| `web/types/api.ts` | Web | Add WILO fields to Feed interface, `imported_at` to FeedItem |
| `web/lib/api-endpoints.ts` | Web | Add updateWilo endpoint |
| `web/components/feed/ListFeedView.tsx` | Web | Divider + tracking (uses `imported_at`) |
| `web/components/feed/GridFeedView.tsx` | Web | Divider + tracking (uses `imported_at`) |
| `web/components/feed/GalleryFeedView.tsx` | Web | Divider + tracking (uses `imported_at`) |
| `web/components/feed/FeedCard.tsx` | Web | Data attributes for observer (`data-imported-at`) |
| `web/app/(authenticated)/feed/[id]/page.tsx` | Web | Hook integration, initial scroll to WILO divider, update merged-item sort from `posted_at` to `imported_at` |
| `web/app/(authenticated)/home/page.tsx` | Web | Hook integration |
| `mobile/types/api.ts` | Mobile | Add WILO fields to Feed interface, `imported_at` to FeedItem |
| `mobile/lib/api-endpoints.ts` | Mobile | Add updateWilo endpoint |
| `mobile/app/(tabs)/feed/[id].tsx` | Mobile | Hook + FlatList integration, `initialScrollIndex`, scroll-to-top FAB |
| `mobile/app/(tabs)/index.tsx` | Mobile | Hook integration |
| `mobile/components/feed/GalleryFeedView.tsx` | Mobile | Divider + tracking |

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2026-02-05 | Technical Liaison | Initial planning document |
| 2026-02-05 | Technical Liaison | Revised: simplified data model (columns on `feeds` table instead of separate table), simplified visual (horizontal bar with up chevron instead of text label) |
| 2026-02-05 | Technical Liaison | Added: initial scroll positioning (feed loads with WILO divider mid-screen), mobile scroll-to-top FAB with immediate WILO update, `forceUpdate` method on `useWilo` hook, `suppressTracking` for initial scroll, `ScrollToTopButton.tsx` component |
| 2026-02-05 | Technical Liaison | Added: comprehensive flush trigger specification -- immediate flush on navigation (route change, tab switch), app exit (beforeunload, AppState background), and component unmount; clarified debounce is for continuous scrolling only; added `flush()` method to hook interface; `sendBeacon` vs `fetch` with `keepalive` tradeoffs; idempotent flush design; web and mobile flush implementation patterns; flush-specific test cases |
| 2026-02-06 | Technical Liaison | **Major change:** Switched from `posted_at` to `imported_at` (scrape-time) ordering to eliminate race condition with backfilled posts. Added "The Race Condition Problem" section explaining the issue and solution. Updated all data models, queries, APIs, and frontend logic to use `imported_at` instead of `posted_at` for feed ordering and WILO tracking. Feeds now ordered by `imported_at DESC, posted_at DESC` to show posts in the order they appeared in the user's feed, not global chronological order. |
| 2026-02-06 | Technical Liaison | **Conflict review:** Cross-codebase audit identified and corrected 10 conflicts/inaccuracies. Key fixes: corrected `feed_items` index (no `feed_id` column exists), fixed scraper file path (`db/queries.py` not `database.py`), added missing scraper model file, resolved mobile `getItemLayout` conflict with `scrollToIndex` alternative, added `sendBeacon` POST/PUT limitation note, added missing `imported_at` serialization requirement in feed service, corrected migration numbering for new split migrations. |
