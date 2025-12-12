# Tutorial System Documentation

> **Purpose:** Comprehensive documentation of the Narro tutorial system implementation. This document serves as the authoritative reference for understanding, using, and extending the tutorial functionality.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Component API Reference](#component-api-reference)
4. [Hook API Reference](#hook-api-reference)
5. [Step Definition Guide](#step-definition-guide)
6. [Usage Examples](#usage-examples)
7. [Technical Implementation Details](#technical-implementation-details)
8. [Integration Patterns](#integration-patterns)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [Future Enhancements](#future-enhancements)

---

## Overview

The Narro tutorial system is a **custom-built, dependency-free** solution for creating interactive onboarding experiences. It was developed to replace `react-joyride`, which became incompatible with React 19.

### Key Features

- **Zero external dependencies** - Built entirely with React and TypeScript
- **Element highlighting** - Automatically highlights target elements with visual effects
- **Smart positioning** - Tooltip positioning with viewport clamping
- **State persistence** - Tracks completion status via localStorage
- **Analytics integration** - Automatically tracks tutorial events
- **Responsive design** - Works on all screen sizes
- **Accessibility** - Proper ARIA attributes and keyboard navigation

### Why Custom Implementation?

The tutorial system was refactored from `react-joyride` in December 2025 due to:
1. **React 19 incompatibility** - `react-joyride` requires React 15-18
2. **Bundle size** - Custom implementation is significantly smaller
3. **Full control** - Complete control over styling and behavior
4. **Type safety** - TypeScript-first design with full type coverage
5. **Maintainability** - No dependency on external library updates

---

## Architecture

The tutorial system consists of two main components:

### 1. `Tutorial` Component (`web/components/tutorial/Tutorial.tsx`)

The visual component that renders the tutorial overlay, tooltip, and handles element highlighting.

**Responsibilities:**
- Rendering the dark overlay that dims the page
- Finding and highlighting target elements via CSS selectors
- Positioning tooltips relative to target elements
- Managing step navigation (next, back, skip, finish)
- Handling cleanup when tutorial ends

### 2. `useTutorial` Hook (`web/lib/hooks/use-tutorial.ts`)

The state management hook that controls tutorial lifecycle and persistence.

**Responsibilities:**
- Managing tutorial state (running, current step index)
- Persisting completion status to localStorage
- Integrating with analytics tracking
- Providing API for starting/stopping tutorials
- Auto-starting tutorials based on localStorage flags

### Data Flow

```
User Action / Auto-start
    ↓
useTutorial.startTutorial()
    ↓
setRun(true) + setStepIndex(0)
    ↓
Tutorial component receives run=true
    ↓
Renders overlay + finds target element
    ↓
Highlights element + positions tooltip
    ↓
User clicks Next/Back/Skip
    ↓
Updates stepIndex or calls stopTutorial()
    ↓
Tutorial component updates display
    ↓
On completion: localStorage + analytics tracking
```

---

## Component API Reference

### `Tutorial` Component

**Location:** `web/components/tutorial/Tutorial.tsx`

**Props:**

```typescript
interface TutorialProps {
  steps: TutorialStep[];
}
```

**Props Description:**

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `steps` | `TutorialStep[]` | Yes | Array of tutorial steps to display |

**Returns:**

- `null` if tutorial is not running or steps array is empty
- React fragment containing overlay and tooltip when active

**Behavior:**

- Only renders when `useTutorial().run === true`
- Automatically highlights elements based on step `target` selector
- Positions tooltip based on step `placement` property
- Handles cleanup of element styles when step changes or tutorial ends
- Scrolls target elements into view before highlighting

---

## Hook API Reference

### `useTutorial` Hook

**Location:** `web/lib/hooks/use-tutorial.ts`

**Returns:**

```typescript
{
  run: boolean;                    // Is tutorial currently running?
  stepIndex: number;               // Current step index (0-based)
  startTutorial: () => void;       // Start the tutorial
  stopTutorial: () => void;       // Stop and mark as completed
  skipTutorial: () => void;       // Alias for stopTutorial()
  nextStep: () => void;           // Advance to next step
  prevStep: () => void;           // Go back to previous step
  setStepIndex: (fn: (prev: number) => number) => void; // Direct step index control
  isTutorialCompleted: () => boolean; // Check if user has completed tutorial
}
```

**State Management:**

The hook manages two pieces of state:
1. **`run`** - Boolean indicating if tutorial is active
2. **`stepIndex`** - Current step index (0-based)

**localStorage Keys:**

- `narro_tutorial_completed` - Set to `'true'` when tutorial is completed
- `showTutorial` - Set to `'true'` to trigger auto-start on next page load

**Analytics Events:**

- `'Tutorial Started'` - Fired when `startTutorial()` is called
- `'Tutorial Completed'` - Fired when `stopTutorial()` is called

**Auto-start Behavior:**

The hook automatically starts the tutorial if:
1. `localStorage.getItem('showTutorial') === 'true'`
2. `localStorage.getItem('narro_tutorial_completed') !== 'true'`
3. Component has mounted (500ms delay to ensure page is rendered)

---

## Step Definition Guide

### `TutorialStep` Type

```typescript
export type TutorialStep = {
  target: string;                    // CSS selector for element to highlight
  content: string;                    // Tooltip text content
  placement?: TutorialStepPlacement;  // Tooltip position relative to target
  disableBeacon?: boolean;           // Legacy prop (kept for compatibility, unused)
};

export type TutorialStepPlacement = 'top' | 'bottom' | 'left' | 'right' | 'center';
```

### Step Properties

#### `target` (required)

**Type:** `string`

**Description:** CSS selector for the element to highlight. The tutorial system uses `document.querySelector()` to find the element.

**Examples:**
```typescript
'#create-feed-button'        // ID selector
'.feed-card'                 // Class selector
'[data-tutorial="welcome"]'  // Attribute selector
'body'                       // Special: centers tooltip in viewport
```

**Best Practices:**
- Use ID selectors (`#element-id`) for unique elements
- Ensure target elements exist in the DOM when tutorial runs
- Use `'body'` with `placement: 'center'` for welcome/intro steps
- Test selectors in browser console before adding to tutorial

**Common Issues:**
- Element not found: Ensure element exists and selector is correct
- Element hidden: Element must be visible (not `display: none`)
- Dynamic content: Wait for content to load before starting tutorial

#### `content` (required)

**Type:** `string`

**Description:** The text content displayed in the tooltip. Supports plain text only (no HTML or markdown).

**Examples:**
```typescript
'Welcome to Feed Management! Let\'s take a quick tour.'
'Click here to create a new feed and start organizing your content.'
'Explore Wide Mode to see all posts from all your feeds in one unified timeline.'
```

**Best Practices:**
- Keep content concise (1-2 sentences)
- Use clear, action-oriented language
- Explain the "why" not just the "what"
- Use proper punctuation and capitalization

#### `placement` (optional)

**Type:** `'top' | 'bottom' | 'left' | 'right' | 'center'`

**Default:** `'bottom'`

**Description:** Where to position the tooltip relative to the target element.

**Placement Options:**

| Placement | Description | Use Case |
|-----------|-------------|----------|
| `'top'` | Above the element, horizontally centered | When element is at bottom of viewport |
| `'bottom'` | Below the element, horizontally centered | Default, works for most cases |
| `'left'` | To the left of element, vertically centered | When element is on right side of page |
| `'right'` | To the right of element, vertically centered | When element is on left side of page |
| `'center'` | Centered in viewport (ignores target) | Welcome steps, general instructions |

**Positioning Logic:**

The system calculates tooltip position as follows:

1. **For `'center'` placement:**
   - Tooltip is centered in viewport
   - `target` element is ignored (can be `'body'`)

2. **For directional placements (`top`, `bottom`, `left`, `right`):**
   - Calculates position relative to target element's bounding box
   - Adds 12px spacing between tooltip and target
   - Centers tooltip along the perpendicular axis

3. **Viewport Clamping:**
   - Ensures tooltip stays within viewport bounds
   - Maintains 12px margin from viewport edges
   - Adjusts position if tooltip would overflow

**Example:**
```typescript
{
  target: '#create-feed-button',
  content: 'Click here to create a new feed.',
  placement: 'left',  // Tooltip appears to the left of button
}
```

#### `disableBeacon` (optional)

**Type:** `boolean`

**Default:** `undefined` (treated as `false`)

**Description:** Legacy property kept for backward compatibility. Currently has no effect in the implementation. Previously used to disable animated beacon indicators.

**Note:** This property may be removed in future versions. It's safe to omit.

---

## Usage Examples

### Basic Usage

The simplest way to add a tutorial to a page:

```typescript
'use client';

import { Tutorial } from '@/components/tutorial/Tutorial';
import { useTutorial } from '@/lib/hooks/use-tutorial';
import type { TutorialStep } from '@/components/tutorial/Tutorial';

const tutorialSteps: TutorialStep[] = [
  {
    target: 'body',
    content: 'Welcome! Let\'s take a quick tour.',
    placement: 'center',
  },
  {
    target: '#create-feed-button',
    content: 'Click here to create a new feed.',
    placement: 'left',
  },
];

export default function MyPage() {
  const { run, startTutorial } = useTutorial();
  
  return (
    <div>
      <Tutorial steps={tutorialSteps} />
      {/* Your page content */}
    </div>
  );
}
```

### Triggering Tutorial from Query Parameter

Trigger tutorial when URL contains `?tutorial=true`:

```typescript
'use client';

import { useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { Tutorial } from '@/components/tutorial/Tutorial';
import { useTutorial } from '@/lib/hooks/use-tutorial';
import type { TutorialStep } from '@/components/tutorial/Tutorial';

const tutorialSteps: TutorialStep[] = [
  // ... steps
];

export default function FeedsPage() {
  const searchParams = useSearchParams();
  const { run, startTutorial } = useTutorial();

  // Trigger tutorial if query param is present
  useEffect(() => {
    if (searchParams.get('tutorial') === 'true' && !run) {
      startTutorial();
    }
  }, [searchParams, run, startTutorial]);

  return (
    <div>
      <Tutorial steps={tutorialSteps} />
      {/* Page content */}
    </div>
  );
}
```

### Manual Tutorial Trigger

Add a button to manually start the tutorial:

```typescript
'use client';

import { Tutorial } from '@/components/tutorial/Tutorial';
import { useTutorial } from '@/lib/hooks/use-tutorial';
import type { TutorialStep } from '@/components/tutorial/Tutorial';

const tutorialSteps: TutorialStep[] = [
  // ... steps
];

export default function SettingsPage() {
  const { startTutorial, isTutorialCompleted } = useTutorial();

  return (
    <div>
      <Tutorial steps={tutorialSteps} />
      
      <div>
        <h1>Settings</h1>
        {!isTutorialCompleted() && (
          <button onClick={startTutorial}>
            Take Tutorial
          </button>
        )}
      </div>
    </div>
  );
}
```

### Conditional Tutorial Steps

Dynamically generate steps based on page state:

```typescript
'use client';

import { useMemo } from 'react';
import { Tutorial } from '@/components/tutorial/Tutorial';
import { useTutorial } from '@/lib/hooks/use-tutorial';
import type { TutorialStep } from '@/components/tutorial/Tutorial';

export default function FeedsPage() {
  const { feeds } = useFeeds();
  const hasFeeds = feeds.length > 0;

  const tutorialSteps: TutorialStep[] = useMemo(() => {
    const steps: TutorialStep[] = [
      {
        target: 'body',
        content: 'Welcome to Feed Management!',
        placement: 'center',
      },
    ];

    if (!hasFeeds) {
      steps.push({
        target: '#create-feed-button',
        content: 'Start by creating your first feed.',
        placement: 'left',
      });
    } else {
      steps.push({
        target: '#feed-grid-view',
        content: 'Here are your feeds. Click any feed to view it.',
        placement: 'top',
      });
    }

    return steps;
  }, [hasFeeds]);

  return (
    <div>
      <Tutorial steps={tutorialSteps} />
      {/* Page content */}
    </div>
  );
}
```

### Complete Example: Feed Management Tutorial

Full example from the actual codebase:

```typescript
'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useFeeds } from '@/lib/hooks/use-profiles';
import { FeedManagementHub } from '@/components/feeds/FeedManagementHub';
import { CreateFeedModal } from '@/components/profiles/CreateFeedModal';
import { Tutorial } from '@/components/tutorial/Tutorial';
import { useTutorial } from '@/lib/hooks/use-tutorial';
import type { TutorialStep } from '@/components/tutorial/Tutorial';

const tutorialSteps: TutorialStep[] = [
  {
    target: 'body',
    content: 'Welcome to Feed Management! Let\'s take a quick tour.',
    placement: 'center',
    disableBeacon: true,
  },
  {
    target: '#create-feed-button',
    content: 'Click here to create a new feed and start organizing your content.',
    placement: 'left',
  },
  {
    target: '#wide-mode-button',
    content: 'Explore Wide Mode to see all posts from all your feeds in one unified timeline.',
    placement: 'left',
  },
  {
    target: '#grid-view-toggle',
    content: 'Toggle between grid and list view to manage your feeds efficiently.',
    placement: 'bottom',
  },
  {
    target: '#list-view-toggle',
    content: 'This is the list view toggle.',
    placement: 'bottom',
  },
];

export default function FeedsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { feeds, loading, fetchFeeds } = useFeeds();
  const [showCreateFeedModal, setShowCreateFeedModal] = useState(false);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');
  const { run, startTutorial } = useTutorial();

  useEffect(() => {
    fetchFeeds();
  }, [fetchFeeds]);

  // Trigger tutorial if query param is present
  useEffect(() => {
    if (searchParams.get('tutorial') === 'true' && !run) {
      startTutorial();
    }
  }, [searchParams, run, startTutorial]);

  return (
    <div className="space-y-6">
      <Tutorial steps={tutorialSteps} />
      
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Feed Management</h1>
        </div>
        <div className="flex items-center gap-3">
          <button
            id="wide-mode-button"
            onClick={() => router.push('/home/wide-mode')}
          >
            Wide Mode
          </button>
          <button
            id="create-feed-button"
            onClick={() => setShowCreateFeedModal(true)}
          >
            + Create Feed
          </button>
        </div>
      </div>

      <FeedManagementHub
        feeds={feeds}
        loading={loading}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
      />
    </div>
  );
}
```

---

## Technical Implementation Details

### Element Highlighting

When a step targets an element, the system:

1. **Finds the element** using `document.querySelector(targetSelector)`
2. **Scrolls into view** using `scrollIntoView({ behavior: 'smooth', block: 'center' })`
3. **Saves original styles** to restore later
4. **Applies highlighting styles:**
   ```typescript
   element.style.outline = '2px solid #0f172a';
   element.style.outlineOffset = '4px';
   element.style.borderRadius = '8px';
   element.style.position = 'relative';
   element.style.zIndex = '10001';
   element.style.boxShadow = '0 0 0 8px rgba(15, 23, 42, 0.10)';
   ```

**Visual Effect:**
- Dark outline (`#0f172a` - slate-900)
- 4px offset for breathing room
- Subtle shadow for depth
- High z-index to appear above overlay

### Tooltip Positioning Algorithm

The positioning system uses a two-phase approach:

**Phase 1: Initial Calculation**
```typescript
// Calculate base position based on placement
if (placement === 'top') {
  top = targetRect.top - tooltipHeight - 12;
  left = targetRect.left + (targetWidth - tooltipWidth) / 2;
} else if (placement === 'bottom') {
  top = targetRect.bottom + 12;
  left = targetRect.left + (targetWidth - tooltipWidth) / 2;
}
// ... similar for left/right
```

**Phase 2: Viewport Clamping**
```typescript
// Ensure tooltip stays within viewport
left = Math.min(Math.max(margin, left), viewportWidth - tooltipWidth - margin);
top = Math.min(Math.max(margin, top), viewportHeight - tooltipHeight - margin);
```

**Timing:**
- Uses double `requestAnimationFrame` to ensure DOM has painted
- Measures tooltip dimensions after render
- Recalculates on window resize

### Overlay System

The overlay creates a "spotlight" effect:

```typescript
<div
  className="fixed inset-0"
  style={{ background: 'rgba(15, 23, 42, 0.45)', zIndex: 10000 }}
  aria-hidden="true"
/>
```

**Z-Index Hierarchy:**
- Overlay: `10000`
- Highlighted element: `10001`
- Tooltip: `10002`

This ensures proper layering: overlay → highlighted element → tooltip.

### Cleanup and Memory Management

The component properly cleans up:

1. **Event listeners** - Removed on unmount
2. **Animation frames** - Cancelled on unmount
3. **Element styles** - Restored to original state
4. **Refs** - Cleared to prevent memory leaks

**Cleanup function:**
```typescript
return () => {
  window.removeEventListener('resize', onResize);
  cancelAnimationFrame(id1);
  cancelAnimationFrame(id2);
  cleanupHighlight();
};
```

### Responsive Design

The tooltip is responsive:

```typescript
className="fixed w-[min(420px,calc(100vw-24px))]"
```

- Maximum width: `420px` on large screens
- Minimum width: `calc(100vw - 24px)` on small screens
- Maintains 12px margin on all sides

---

## Integration Patterns

### Pattern 1: Auto-start on First Visit

Set localStorage flag to trigger tutorial on next page load:

```typescript
// In onboarding flow or after signup
localStorage.setItem('showTutorial', 'true');
// Tutorial will auto-start on next page load
```

### Pattern 2: Query Parameter Trigger

Allow deep linking to tutorial:

```typescript
// User visits: /feeds?tutorial=true
useEffect(() => {
  if (searchParams.get('tutorial') === 'true' && !run) {
    startTutorial();
  }
}, [searchParams, run, startTutorial]);
```

### Pattern 3: Settings Page Replay

Allow users to replay tutorial from settings:

```typescript
// In settings page
const handleReplayTutorial = () => {
  localStorage.removeItem('narro_tutorial_completed');
  startTutorial();
};
```

### Pattern 4: Conditional Steps

Show different steps based on user state:

```typescript
const steps = useMemo(() => {
  const baseSteps = [/* ... */];
  
  if (user.isNew) {
    baseSteps.push({
      target: '#onboarding-help',
      content: 'Need help? Check out our guide.',
      placement: 'right',
    });
  }
  
  return baseSteps;
}, [user.isNew]);
```

### Pattern 5: Multi-page Tutorial

Navigate between pages during tutorial:

```typescript
const steps: TutorialStep[] = [
  {
    target: '#home-feed',
    content: 'This is your home feed.',
    placement: 'bottom',
  },
  // After user clicks Next, navigate to feeds page
  // Then continue with feeds page steps
];
```

**Note:** This requires coordinating tutorial state across pages, which may need additional implementation.

---

## Best Practices

### 1. Step Definition

✅ **Do:**
- Use descriptive, action-oriented content
- Keep steps focused (one concept per step)
- Test selectors before adding to tutorial
- Use ID selectors for unique elements
- Start with a welcome step (`placement: 'center'`)

❌ **Don't:**
- Target elements that may not exist
- Use overly complex selectors
- Create too many steps (aim for 3-7 steps)
- Target elements that are conditionally rendered without checking

### 2. Element Targeting

✅ **Do:**
```typescript
// Add IDs specifically for tutorial targeting
<button id="create-feed-button">Create Feed</button>

// Use stable selectors
target: '#create-feed-button'
```

❌ **Don't:**
```typescript
// Avoid class selectors that may change
target: '.btn-primary'  // May match multiple elements

// Avoid complex selectors
target: 'div > button:nth-child(3)'  // Fragile
```

### 3. Content Writing

✅ **Do:**
- Write in second person ("You can...")
- Be concise (1-2 sentences)
- Explain benefits, not just features
- Use consistent tone

❌ **Don't:**
- Write long paragraphs
- Use technical jargon
- Be vague ("This is a button")
- Mix tones

### 4. Placement Selection

✅ **Do:**
- Use `'bottom'` as default (works for most cases)
- Use `'center'` for welcome/intro steps
- Consider viewport position when choosing placement
- Test on different screen sizes

❌ **Don't:**
- Always use the same placement
- Ignore element position in viewport
- Use `'left'` or `'right'` for centered elements

### 5. Performance

✅ **Do:**
- Define steps as constants outside component (if static)
- Use `useMemo` for dynamic steps
- Ensure target elements exist before starting tutorial

❌ **Don't:**
- Recreate steps array on every render
- Start tutorial before page is fully loaded
- Target elements in loading states

### 6. Accessibility

✅ **Do:**
- Ensure target elements are keyboard accessible
- Test with screen readers
- Provide alternative ways to access tutorial content

❌ **Don't:**
- Rely solely on tutorial for critical information
- Block keyboard navigation
- Hide important content behind tutorial

---

## Troubleshooting

### Issue: Tutorial doesn't start

**Symptoms:** Tutorial component renders but overlay doesn't appear.

**Possible Causes:**
1. `useTutorial().run` is `false`
2. Steps array is empty
3. Component not mounted

**Solutions:**
```typescript
// Check if tutorial is running
const { run } = useTutorial();
console.log('Tutorial running:', run);

// Ensure steps array is not empty
console.log('Steps:', tutorialSteps.length);

// Manually start tutorial
startTutorial();
```

### Issue: Element not found

**Symptoms:** Tooltip appears but no element is highlighted.

**Possible Causes:**
1. Selector is incorrect
2. Element doesn't exist in DOM
3. Element is conditionally rendered

**Solutions:**
```typescript
// Test selector in browser console
document.querySelector('#create-feed-button');

// Wait for element to render
useEffect(() => {
  const element = document.querySelector('#create-feed-button');
  if (element) {
    // Element exists, safe to start tutorial
    startTutorial();
  }
}, []);
```

### Issue: Tooltip positioned incorrectly

**Symptoms:** Tooltip appears off-screen or overlaps with element.

**Possible Causes:**
1. Viewport is too small
2. Element is near edge of viewport
3. Placement doesn't match element position

**Solutions:**
- Try different `placement` value
- Ensure viewport has enough space
- Test on different screen sizes
- System automatically clamps to viewport, but may need adjustment

### Issue: Tutorial doesn't persist completion

**Symptoms:** Tutorial restarts on page refresh.

**Possible Causes:**
1. localStorage is disabled
2. `stopTutorial()` not called
3. localStorage key mismatch

**Solutions:**
```typescript
// Check localStorage
console.log(localStorage.getItem('narro_tutorial_completed'));

// Ensure stopTutorial is called
const handleFinish = () => {
  stopTutorial(); // This sets the completion flag
};
```

### Issue: Multiple tutorials on same page

**Symptoms:** Multiple tutorial overlays appear.

**Possible Causes:**
1. Multiple `<Tutorial>` components rendered
2. Tutorial state shared incorrectly

**Solutions:**
- Only render one `<Tutorial>` component per page
- Use single `useTutorial()` hook instance
- Check for duplicate imports

### Issue: Styles not restored after tutorial

**Symptoms:** Element keeps highlighting styles after tutorial ends.

**Possible Causes:**
1. Cleanup function not called
2. Element removed from DOM before cleanup
3. React strict mode double-rendering

**Solutions:**
- Ensure tutorial component unmounts properly
- Check cleanup function in useEffect return
- Verify element still exists during cleanup

---

## Future Enhancements

### Planned Features

1. **Smooth Transitions**
   - Add CSS transitions between steps
   - Fade in/out animations for tooltip
   - Smooth element highlighting

2. **Spotlight Effect**
   - Cutout in overlay around highlighted element
   - More dramatic visual focus
   - Optional spotlight mode

3. **Keyboard Navigation**
   - Arrow keys to navigate steps
   - Escape key to skip
   - Enter to advance

4. **Auto-discovery**
   - Automatically detect interactive elements
   - Generate steps from component structure
   - Smart step ordering

5. **Tour Templates**
   - Pre-defined tour templates
   - Common onboarding flows
   - Easy tour creation

6. **Progress Persistence**
   - Save progress mid-tour
   - Resume from last step
   - Multi-session tutorials

7. **Custom Styling**
   - Theme customization
   - Custom tooltip styles
   - Brand colors

8. **Analytics Enhancements**
   - Track step completion rates
   - Identify drop-off points
   - A/B testing support

### Implementation Notes

When implementing enhancements:

1. **Maintain backward compatibility** - Don't break existing tutorials
2. **Keep it dependency-free** - Avoid adding external libraries
3. **Preserve type safety** - Update TypeScript types accordingly
4. **Update this documentation** - Keep docs in sync with implementation
5. **Test thoroughly** - Especially on mobile devices

---

## Related Documentation

- **UI Design Document** (`docs/narro_ui_design_document.md`) - UX/design intent for tutorials
- **Agent Context** (`docs/AGENT_CONTEXT.md`) - High-level overview
- **Update Log** (`update.md`) - Changelog entries for tutorial system

---

## Code Locations

| Component | Location |
|-----------|----------|
| Tutorial Component | `web/components/tutorial/Tutorial.tsx` |
| Tutorial Hook | `web/lib/hooks/use-tutorial.ts` |
| Analytics Hook | `web/lib/hooks/use-analytics.ts` |
| Example Usage | `web/app/(authenticated)/feeds/page.tsx` |
| Example Usage | `web/app/dashboard/feeds/page.tsx` |

---

## Version History

- **December 11, 2025** - Refactored from `react-joyride` to custom implementation
  - Removed external dependency
  - Created custom `Tutorial` component
  - Implemented element highlighting
  - Added smart tooltip positioning
  - Integrated with analytics

---

**Last Updated:** December 11, 2025

**Maintainer:** Development Team

**Questions or Issues:** Refer to this document first, then check code comments in component files.
