# Narro UI Design Document

## Product Overview

Narro is a social media browser app that collects posts from your favorite social media profiles and combines them into one feed. We filter out the algorithm, ads, and tracking—giving you just the content from the people you actually want to follow.

Users can create multiple feeds to organize content by topic or interest, with each feed aggregating posts from various social media platforms (Twitter, LinkedIn, Instagram, TikTok, Facebook, blogs, etc.) and any other supported sources. When users log in, they see their configured home feed (a default feed is automatically created on account setup). The core value proposition is curation without algorithmic manipulation—users explicitly choose their sources, and Narro presents content in clean, user-controlled ways.

---

## 1. Information Architecture

### User's Mental Model
Users maintain multiple **feeds**, each representing a distinct topic, interest area, or use case. A single feed may aggregate posts from:
- Multiple social media platforms
- Blogs
- RSS feeds
- Any supported source

Feeds are typically unrelated to each other (e.g., "Tech News," "Close Friends," "Home Renovation Ideas").

### Navigation Hierarchy

```
Login/Auth
├── Home Feed (Primary, configurable - shows default feed or user's selected home feed)
├── Feed Management Hub (Secondary - view/manage all feeds)
├── Individual Feed View (if not currently viewing home feed)
├── Wide Mode (view all posts from all feeds)
└── Settings/Account
```

---

## 2. Home Feed (Primary Interface After Login)

### Purpose
When a user logs in, they see their configured home feed. On initial account creation, a default feed is automatically created and displayed. Users can change which feed is their home page via settings.

### Appearance
The home feed displays the posts from that feed's configured sources in a timeline/scroll interface.

**Navigation from Home Feed**
- Access Feed Management Hub (to view/manage all feeds or switch home feed)
- Access Wide Mode (to see all posts from all feeds)
- Access individual feeds from the feed management hub
- Access settings

### Account Onboarding

**New Account Creation**
- When a user signs up, a default feed is automatically created
- User is guided to add sources to this default feed (social media profiles, blogs, etc.)
- After adding sources, the user is taken to the home feed to see posts
- The user can rename this default feed, customize its appearance, or create additional feeds at any time
- This default feed is automatically set as the home feed and shown on login

**In-App Tutorial**
- First-time users are presented with an option to view a brief click-through tutorial
- Tutorial walks through key features and concepts:
  - What a feed is and how to customize it
  - How to access Feed Management Hub to manage multiple feeds
  - How to use Wide Mode to see all posts at once
  - How to favorite/star profiles within a feed
- Tutorial is optional and can be skipped
- Users can replay the tutorial anytime from settings if needed
- Tutorial uses interactive highlights or overlays pointing out relevant UI elements

---

## 3. Feed Management Hub (Secondary Interface)

### Purpose
Allows users to view, organize, and manage all their feeds. Home feed configuration is done via user settings (not within individual feed customization).

### Default View: Grid Layout

**Appearance**
- Responsive grid of feed cards (3-4 columns on desktop)
- Each card is visually distinct and clickable

**Feed Card Contents**
- **Feed Title** (user-defined, editable)
- **Custom Visual Element** (optional):
  - Custom color background
  - Custom emoji
  - Custom image/thumbnail
  - Combination of the above
- **Interaction Affordances**:
  - Click to open feed
  - Hover reveals options menu icon (three-dot menu for edit, delete, more actions)
  - Optional drag-to-reorder functionality

**Visual Principles**
- Clean, uncluttered design
- Customization should feel personal, not chaotic
- Consistent spacing and alignment

---

### Alternative View 1: List View

**Appearance**
- Vertical list of feeds
- More compact than grid
- Optimized for users with many feeds (20+)

**Row Contents**
- Feed title (left-aligned)
- Custom visual element if present (small, left of title or as background accent)
- Options menu (three-dot icon or similar)

**Use Case**
- Users who prefer dense information
- Easier to search/filter by name
- Better for scrolling through large feed lists

---

## 4. Feed Customization System

### Customizable Metadata (Per Feed)

When creating or editing a feed, users can set:

1. **Name/Title** (required)
   - Free text, user-defined
   - Example: "Tech News," "Close Friends," "Home Renovation"

2. **Visual Identity** (optional)
   - **Color**: Solid background color picker
   - **Emoji**: Single emoji selector
   - **Custom Image**: Upload a small image (thumbnail)
   - Can combine (e.g., color + emoji, image + emoji)
   - If not set, feed displays with a default neutral appearance

3. **Source List** (required, editable)
   - List of platforms/sources included in this feed
   - User can add/remove sources via UI

4. **Description/Notes** (optional)
   - Short text field for user's own reference
   - Not displayed to others (Narro has no sharing, so this is just for user clarity)

### Customization UI Pattern

- **Creation Flow**: Step-by-step form (or single form depending on complexity)
  1. Name the feed
  2. Add sources
  3. Optional: Choose visual identity
  4. Optional: Add description/notes
  
- **Edit Flow**: Modal or dedicated edit screen with all fields

---

## 5. Individual Feed View

### Purpose
When a user clicks into a feed, they see the posts from all sources aggregated in that feed.

### Layout
- Single-column or multi-column timeline (depending on device/user preference)
- Posts displayed chronologically (newest first) or by configurable sorting
- Each post shows:
  - Author/profile information
  - Post content (text, image, video)
  - Timestamp
  - Links to original if desired

### Search and Filtering

Users can filter posts within a feed to find specific content:

**Filter Options**
- **By Date**: Picker or range selector to view posts from specific dates or date ranges
- **By Profile Name**: Filter to show posts from specific profiles/authors within the feed
- **By Hashtag**: Filter to show only posts containing specific hashtags
- Filters can be combined (e.g., posts from a specific profile in the last week with a certain hashtag)
- Active filters are visually indicated
- Easy toggle to clear filters and reset to full feed view

### Post Display and Interaction
- Posts are displayed as thumbnails with visual preview of content
- Posts are clickable through to the original source (Twitter, Instagram, etc.)
- Clicking a post opens the original in a new tab or within Narro's viewer

### RSS Feed Link
- Each individual feed has an associated RSS feed URL
- An RSS icon/link is prominently displayed in the feed header (top-right or in feed info area)
- Clicking the RSS icon reveals or copies the feed's RSS URL
- Users can subscribe to this feed in external RSS readers if desired
- This provides flexibility for users who prefer RSS aggregators or want to use Narro alongside other tools

### Note on Feed-Level Interface Design
The specific styling and layout of posts within an individual feed (the scroll/timeline interface) is a separate design concern and should be documented separately.

---

## 5.5 Individual Feed Management

### Purpose
Allows users to edit and manage settings for a specific feed without creating a new feed or returning to the main Feed Management Hub.

### Access
- Accessible from the feed header via an "Edit" button or settings icon
- Alternative: three-dot menu on feed card in Feed Management Hub

### Manageable Settings
- **Feed Name**: Rename the feed
- **Visual Identity**: Customize color, emoji, and/or image
- **Sources**: Add or remove sources (social media profiles, blogs, RSS feeds, etc.)
- **Description/Notes**: Edit personal notes about the feed
- **RSS Feed URL**: Display and copy the feed's RSS URL
- **Delete Feed**: Option to remove the feed entirely

### Interaction
- Edit mode shows the same form fields as Create Feed
- Changes are saved and user returns to viewing that feed
- Deletion requires confirmation before removing the feed

### Profile Favoriting/Starring Within Feeds

Users can favorite or star specific profiles/authors within a feed. This creates visual distinction for those profiles' posts in the timeline:

**Purpose**
- Allows users to highlight favorite profiles without creating new feeds
- Creates visual priority for most-engaged profiles

**Interaction**
- Click on a profile name or avatar to open profile menu
- Option to "star" or "favorite" that profile
- Starred profiles have their posts visually distinguished (e.g., highlighted, pinned to top, different styling)

**Use Case**
- Users with a feed containing many profiles can highlight the ones they engage with most frequently
- Doesn't require creating new feeds; just marks certain profiles as priority within an existing feed
- Visual distinction makes scanning easier

---

## 6. Wide Mode

### Purpose
A special view that aggregates **all** posts from **all** feeds in a single unified timeline.

### Configuration
- **Access**:
  - Accessible from the Feeds section as an alternative view
  - Can be set as default home view via Settings (instead of a specific feed)
  - Option to toggle between feed management and wide mode view

### Appearance
- Single-column timeline
- Posts from all sources, all feeds, in chronological order
- Post attribution shows both:
  - Original source platform (Twitter, Instagram, etc.)
  - Which user feed it came from (if user has multiple feeds)
- No filtering or algorithmic ranking (purely chronological)

### Use Cases
- Users who want to completely abandon feed organization and just consume everything
- Users doing deep archive browsing
- Users who want a "catch-all" view option

### Interaction
- Switch between Wide Mode and Feed Management Hub seamlessly
- Ideally via top-level navigation (tab, toggle, or sidebar link)

---

## 7. Navigation & Configuration

### Primary Navigation (Top-Level)

Horizontal navigation bar across the top of the application with the following buttons:

- **Home** (home icon)
  - Primary landing page after login
  - Displays configured home feed
  
- **Feeds** (feeds/list icon)
  - Opens Feed Management Hub
  - View and manage all feeds
  - Edit and organize feeds
  
- **Settings** (gear icon)
  - Account settings
  - Configure home feed preference
  - Application preferences
  
- **Help** (question mark or help icon)
  - Access in-app tutorial
  - Help documentation
  - Support information

### Feed Management Hub Controls

**View Mode Selector**
- Prominent toggle/dropdown showing current view
- Options: Grid, List
- Instant switch (no page reload)

**Action Buttons**
- **Create New Feed** (prominent CTA)
  - Opens feed creation flow
  - Button should be easily accessible in a prominent position (top-right or near feed list controls)

**Search/Filter** (optional, but recommended)
- Search by feed name if many feeds
- Filter by source platform (optional)

---

## 8. Visual Design Principles

1. **Clarity Over Complexity**: Each feed should be easily identifiable at a glance. Customization (color, emoji, image) should enhance scannability, not clutter.

2. **Consistency**: Use consistent spacing, typography, and interaction patterns across all views.

3. **Browser-Optimized**: Design should work seamlessly in modern web browsers (Chrome, Firefox, Safari, Edge). All interactions should use browser-native patterns (hover, click, keyboard navigation).

4. **Minimalism**: Narro's value is "no algorithm, no ads, no tracking." Visual design should feel clean and ad-free, not cluttered with badges, notifications, or engagement metrics.

5. **Accessibility**: Sufficient color contrast, readable font sizes, keyboard navigation support.

6. **Customization = Personality**: User customization (colors, emojis) should feel like personalizing a space, not overwhelming the interface.

---

## 9. Key Screens & States

### Screen 1: Home Feed (Primary, after login)
**Primary user interface.**
- Single feed's posts displayed as timeline/scroll with thumbnail previews
- Posts are clickable through to original source
- User's configured home feed (default feed on new account)
- Top navigation bar with Home, Feeds, Settings, Help buttons
- Quick access to Feed Management Hub via Feeds button
- Access to settings and help via top navigation

### Screen 2: Feed Management Hub - Grid View
**Managing and organizing feeds.**
- Top navigation bar with Home, Feeds, Settings, Help buttons
- Grid of feed cards
- Each card shows: title, custom visual if present (color/emoji/image)
- Quick access to create new feed
- Easy toggle to list view
- Access to Wide Mode view option

### Screen 3: Feed Management Hub - List View
**For users with many feeds.**
- Top navigation bar with Home, Feeds, Settings, Help buttons
- Compact list of feeds
- Search/filter functionality for feed names

### Screen 4: Individual Feed - Timeline/Post View (with optional filter panel)
**Viewing a non-home feed with optional filtering.**
- Single feed's posts displayed as timeline/scroll with thumbnail previews
- Posts are clickable through to original source
- Attribution shows post author/profile
- Filter panel toggle button at top of feed (collapsed by default)
- When expanded: filter controls appear as a panel showing filters for date range, profile name, hashtag
- Filter functionality allows combining multiple filters
- Active filters are visually indicated
- RSS icon/link in feed header to access feed's RSS URL
- User can return to Feed Management Hub

### Screen 5: Individual Feed Management
**Managing a specific feed's settings and profile preferences.**
- Feed name editing
- Visual identity customization (color, emoji, image)
- Source management (add/remove sources)
- Description/notes editing
- RSS feed URL display
- Profile favoriting/starring interface (star/favorite specific profiles within the feed)
- Delete feed option
- Save and Cancel buttons

### Screen 6: Wide Mode
**All posts, all feeds, one timeline.**
- Top navigation bar with Home, Feeds, Settings, Help buttons
- Unified chronological timeline with post thumbnails
- Posts are clickable through to original source
- Post attribution includes feed and author/profile
- Distinct visual treatment (to differentiate from individual feed view)

### Screen 7: Create/Edit Feed Modal
**Feed customization UI.**
- Form fields: Name, Sources, Visual Identity (optional), Description (optional)
- Step-by-step or single form depending on UX preference
- Save and Cancel buttons

### Screen 8: Feed Card Context Menu
**Options menu on feed cards in Feed Management Hub.**
- Visible on hover (desktop)
- Options: Edit, Delete, and other feed management actions
- Provides quick access to feed settings

### Screen 9: In-App Tutorial (First-Time User)
**Onboarding guide for new users.**
- Sequential click-through screens explaining core features
- Covers: feeds concept, Feed Management Hub, Wide Mode, filtering options, top navigation
- Interactive highlights/overlays pointing to relevant UI elements
- Explains Home, Feeds, Settings, and Help buttons
- Skip button available at any time
- Completion returns user to their home feed
- Can be accessed again from Settings via Help

---

## 10. Interactions & Micro-Interactions

### Feed Card Interactions
- **Hover** (desktop): Subtle shadow or highlight; options menu appears (three-dot icon)
- **Click**: Opens feed (navigates to individual feed timeline)
- **Drag** (if reordering enabled): Visual feedback showing drag state and drop zones

### View Mode Switching
- **Instant switch** between grid/list views (no loading state needed if data is in-memory)
- Smooth animation/transition (fade or slide)

### Feed Creation
- **Button click** → Modal/form opens
- Step-by-step or form-fill experience (design team can decide)
- **Save** → Feed added to grid, notification/confirmation
- **Cancel** → Modal closes, no data loss if user hasn't saved

### Post Interactions
- **Hover/Click on post thumbnail**: Indicates it's clickable
- **Click post**: Opens original post in new tab or Narro viewer

### Feed Filtering Panel
- **Filter toggle button** at top of individual feed timeline (collapsed by default)
- **Click toggle** → Filter panel slides in/out
- **Filter options**: Date range selector, profile name dropdown, hashtag input
- **Select filter criteria** → Results update in real-time
- **Active filters** visually indicated
- **Clear filters** button resets to full feed view

---

## 11. Web Browser Considerations

This design is optimized for desktop web browsers. All interactions leverage browser-native patterns:
- Hover states for menu reveal
- Click-based navigation and menus
- Keyboard navigation and shortcuts
- No mobile touch gestures or mobile-specific interactions

---

## 12. Future Enhancements (Not In Scope, But Architecture For)

- Drag-and-drop reordering of feeds
- Bulk actions (edit multiple feeds, delete multiple)
- Sharing feed lists (e.g., "My Tech News Sources") — may conflict with current product positioning but worth considering
- Feed templates or suggestions
- Digest/summary mode for feeds

---

## 13. Summary of Design Outputs Needed

For a visual design team or AI image/UI generation tool, create the following screens:

1. Home Feed - Timeline/Post View (primary interface after login)
2. Feed Management Hub - Grid View
3. Feed Management Hub - List View
4. Individual Feed - Timeline/Post View (with optional filter panel shown/hidden, thumbnails, clickthrough)
5. Individual Feed Management (edit settings, visual identity, sources, profile favoriting)
6. Wide Mode - All Posts Timeline
7. Create/Edit Feed - Form/Modal
8. Feed Card Context Menu (on hover)
9. In-App Tutorial - Click-Through Onboarding (multiple screens)

Each screen should clearly show:
- Layout and spacing
- Feed card customization examples (various color/emoji/image combinations, and cards without custom visuals)
- Posts displayed as thumbnails with visual previews
- Navigation elements across the top (Home, Feeds, Settings, Help)
- Key interactions and affordances
- Filter panel toggle and expanded state on Screen 4

---

## End of Design Document
