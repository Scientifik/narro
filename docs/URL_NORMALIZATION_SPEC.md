# URL Normalization Specification

**Status:** CURRENT
**Last Updated:** 2026-01-24

---

## Overview

This document defines the canonical URL format for each supported platform in Narro. All components (backend, web, mobile, scraper) MUST normalize URLs to these exact formats to enable effective caching.

## Why Normalization Matters

Without consistent URL normalization:
- `instagram.com/FoxtonHardware` and `instagram.com/foxtonhardware` are stored as different profiles
- Cache lookups fail, causing redundant Apify costs
- The same profile can exist multiple times in the database

## Canonical URL Formats

### Instagram

**Canonical Format:** `https://www.instagram.com/{lowercase_username}`

| Input | Canonical Output |
|-------|------------------|
| `instagram.com/FoxtonHardware` | `https://www.instagram.com/foxtonhardware` |
| `https://www.instagram.com/FoxtonHardware/` | `https://www.instagram.com/foxtonhardware` |
| `Instagram.com/@FOXTONHARDWARE` | `https://www.instagram.com/foxtonhardware` |
| `ig/foxtonhardware` | `https://www.instagram.com/foxtonhardware` |

**Rules:**
- Always `https://`
- Always include `www.` subdomain
- Always lowercase username
- Strip `@` prefix if present
- No trailing slash
- Remove query parameters and fragments

### Twitter/X

**Canonical Format:** `https://twitter.com/{lowercase_handle}`

| Input | Canonical Output |
|-------|------------------|
| `twitter.com/elonmusk` | `https://twitter.com/elonmusk` |
| `x.com/ElonMusk` | `https://twitter.com/elonmusk` |
| `https://www.twitter.com/@ELONMUSK/` | `https://twitter.com/elonmusk` |

**Rules:**
- Always `https://`
- Always use `twitter.com` (not `x.com`) for canonical URL
- NO `www.` subdomain (Twitter doesn't use it)
- Always lowercase handle
- Strip `@` prefix if present
- No trailing slash

### TikTok

**Canonical Format:** `https://www.tiktok.com/@{lowercase_username}`

| Input | Canonical Output |
|-------|------------------|
| `tiktok.com/@DanceQueen` | `https://www.tiktok.com/@dancequeen` |
| `tiktok.com/dancequeen` | `https://www.tiktok.com/@dancequeen` |
| `https://www.tiktok.com/@DANCEQUEEN/` | `https://www.tiktok.com/@dancequeen` |

**Rules:**
- Always `https://`
- Always include `www.` subdomain
- Always include `@` prefix in URL (TikTok standard)
- Always lowercase username
- No trailing slash

### YouTube

**Canonical Format:**
- For handles: `https://www.youtube.com/@{lowercase_handle}`
- For channel IDs: `https://www.youtube.com/channel/{ORIGINAL_CASE_ID}`

| Input | Canonical Output |
|-------|------------------|
| `youtube.com/@TechChannel` | `https://www.youtube.com/@techchannel` |
| `youtube.com/c/TechChannel` | `https://www.youtube.com/@techchannel` |
| `youtube.com/user/TechChannel` | `https://www.youtube.com/@techchannel` |
| `youtube.com/channel/UCxxxABCdef` | `https://www.youtube.com/channel/UCxxxABCdef` |

**Rules:**
- Always `https://`
- Always include `www.` subdomain
- For handles/custom URLs: lowercase and normalize to `@handle` format
- For channel IDs (`/channel/UC...`): PRESERVE original case (case-sensitive)
- Convert `/c/name` and `/user/name` formats to `@name`
- No trailing slash

### LinkedIn

**Canonical Format:** `https://www.linkedin.com/in/{lowercase_username}`

| Input | Canonical Output |
|-------|------------------|
| `linkedin.com/in/JohnDoe` | `https://www.linkedin.com/in/johndoe` |
| `https://www.linkedin.com/in/johndoe/` | `https://www.linkedin.com/in/johndoe` |

**Rules:**
- Always `https://`
- Always include `www.` subdomain
- Always use `/in/` path prefix
- Always lowercase username
- No trailing slash

### Reddit

**Canonical Format:** `https://www.reddit.com/r/{original_case_subreddit}`

| Input | Canonical Output |
|-------|------------------|
| `reddit.com/r/AskReddit` | `https://www.reddit.com/r/AskReddit` |
| `reddit.com/r/askreddit` | `https://www.reddit.com/r/askreddit` |

**Rules:**
- Always `https://`
- Always include `www.` subdomain
- Always use `/r/` path prefix
- PRESERVE original case (Reddit subreddits are case-insensitive but display varies)
- No trailing slash

**Note:** Reddit case handling is intentionally preserved because different casing displays differently in the UI while pointing to the same subreddit.

## Normalization Algorithm

```
1. Trim whitespace
2. Remove trailing slash(es)
3. Remove query parameters (everything after ?)
4. Remove fragments (everything after #)
5. Add https:// if no protocol present
6. Parse URL
7. Identify platform from host
8. Extract username/identifier from path
9. Apply platform-specific rules:
   a. Strip @ prefix (except TikTok which needs it)
   b. Lowercase (except YouTube channel IDs and Reddit subreddits)
   c. Add required prefixes (@ for TikTok/YouTube handles, /in/ for LinkedIn)
10. Construct canonical URL using platform template
```

## Implementation Requirements

### Backend (Go)
- Location: `/backend/src/db/url_parser.go`
- Modify `ParseSocialURLWithDB` to apply lowercase normalization
- This is the CRITICAL point - backend MUST normalize before storing in database

### Web (TypeScript)
- Location: `/web/lib/utils/profileUrlNormalizer.ts` (new file)
- Used by: `/web/components/profiles/shared/ProfileInputFields.tsx`
- Normalize before sending to API
- Provide visual feedback if URL was normalized

### Mobile (TypeScript)
- Location: `/mobile/lib/profileUrlNormalizer.ts` (new file)
- Used by: `/mobile/app/(tabs)/profiles/import.tsx`
- Same logic as web (could be shared package in future)

### Scraper (Python)
- Location: `/scraper/src/importers/base.py`
- Add validation that received URLs are canonical
- Log warnings if non-canonical URLs received
- Apply normalization as safety net

## Testing Requirements

Each component must have tests covering:

1. **Case normalization**
   - `Instagram.com/USERNAME` -> `https://www.instagram.com/username`

2. **Protocol handling**
   - `instagram.com/user` -> `https://www.instagram.com/user`
   - `http://instagram.com/user` -> `https://www.instagram.com/user`

3. **Subdomain handling**
   - `www.instagram.com/user` -> `https://www.instagram.com/user`
   - `instagram.com/user` -> `https://www.instagram.com/user`

4. **Trailing slash**
   - `instagram.com/user/` -> `https://www.instagram.com/user`

5. **@ symbol handling**
   - `instagram.com/@user` -> `https://www.instagram.com/user`
   - `tiktok.com/user` -> `https://www.tiktok.com/@user`

6. **Query parameters**
   - `instagram.com/user?ref=123` -> `https://www.instagram.com/user`

7. **Platform aliases**
   - `x.com/user` -> `https://twitter.com/user`
   - `youtu.be/video` -> (video URLs, not profile URLs)

8. **YouTube special cases**
   - `/c/ChannelName` -> `/@channelname`
   - `/user/UserName` -> `/@username`
   - `/channel/UCxxx` -> `/channel/UCxxx` (preserve case)

## Migration Strategy

For existing data with non-normalized URLs:

1. Create migration script to update `profile_import_jobs.source_url`
2. Update `social_profiles.url` to canonical format
3. Handle duplicates that may emerge (same profile, different URLs)
4. Consider keeping old URLs in a separate column during transition

## Version History

- v1.0 (2025-01-22): Initial specification
