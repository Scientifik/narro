# Front-End to Backend API Connection Setup

## ✅ What's Been Completed

### 1. API Client (`web/lib/api.ts`)
- Centralized API client using fetch
- Automatic token management (stores/retrieves from localStorage)
- Error handling with typed errors
- Support for GET, POST, PATCH, DELETE requests
- TypeScript types for all requests/responses

### 2. TypeScript Types (`web/types/api.ts`)
- Complete type definitions for all API endpoints
- Auth types (Signup, Login, User)
- Social Profile types
- Feed types
- Subscription types
- Error types

### 3. API Endpoints (`web/lib/api-endpoints.ts`)
- Centralized endpoint definitions
- Type-safe endpoint paths
- Easy to update if API routes change

### 4. React Hooks (`web/lib/hooks/use-api.ts`)
- `useApi` - Generic hook for API calls
- `useGet`, `usePost`, `usePatch`, `useDelete` - Specific hooks
- Loading states, error handling, data management

### 5. Environment Configuration
- `.env.local` created with `NEXT_PUBLIC_API_URL=http://localhost:3030`
- Environment variable template updated

### 6. Testing Components
- `ApiStatus` component - Shows connection status in bottom-right corner
- `/dashboard/api-test` page - Full API testing interface

### 7. Backend CORS
- ✅ CORS middleware already configured in backend
- Allows all origins (can be restricted in production)
- Supports all necessary HTTP methods

## 🔧 Next Steps

### 1. Update Environment Variables

Edit `web/.env.local` with your Supabase credentials:

```bash
# Backend API URL (already set to port 3030)
NEXT_PUBLIC_API_URL=http://localhost:3030

# Add your Supabase values from your Supabase dashboard
NEXT_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here

# Stripe (add when ready)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

### 2. Start Backend Server

Make sure your backend is running on port 3030:

```bash
cd backend
# Set PORT=3030 in your .env or environment
PORT=3030 go run main.go
```

### 3. Start Front-End

```bash
cd web
npm run dev
```

### 4. Test the Connection

1. Visit `http://localhost:3000/dashboard/api-test`
2. Click "Test Health Endpoint" - should see success
3. Check bottom-right corner for API status indicator

## 📝 Usage Examples

### Using the API Client Directly

```typescript
import { apiClient } from '@/lib/api';
import { API_ENDPOINTS } from '@/lib/api-endpoints';
import type { HealthResponse } from '@/types/api';

// Health check
const health = await apiClient.get<HealthResponse>(API_ENDPOINTS.health);

// Authenticated request
apiClient.setToken('your-jwt-token');
const profile = await apiClient.get(API_ENDPOINTS.user.profile);
```

### Using React Hooks

```typescript
'use client';

import { useGet } from '@/lib/hooks/use-api';
import { API_ENDPOINTS } from '@/lib/api-endpoints';
import type { FeedResponse } from '@/types/api';

export function FeedComponent() {
  const { data, loading, error, execute } = useGet<FeedResponse>(
    API_ENDPOINTS.feed.list,
    { page: 1, limit: 20 }
  );

  useEffect(() => {
    execute();
  }, []);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!data) return null;

  return (
    <div>
      {data.items.map(item => (
        <div key={item.id}>{item.content_text}</div>
      ))}
    </div>
  );
}
```

## 🔍 Troubleshooting

### Backend not connecting?

1. **Check backend is running:**
   ```bash
   curl http://localhost:3030/health
   ```

2. **Verify CORS is configured:**
   - Check `backend/src/middleware/cors_middleware.go`
   - Should allow `Access-Control-Allow-Origin: *`

3. **Check environment variables:**
   - Verify `NEXT_PUBLIC_API_URL` in `.env.local`
   - Restart Next.js dev server after changing env vars

4. **Check browser console:**
   - Look for CORS errors
   - Check Network tab for failed requests

### Common Issues

- **CORS errors:** Backend CORS middleware should handle this, but verify it's applied
- **404 errors:** Check that backend routes match the endpoint paths
- **401 errors:** Token may be expired or invalid
- **Network errors:** Backend may not be running or wrong port

## 📚 Files Created

- `web/lib/api.ts` - API client
- `web/lib/api-endpoints.ts` - Endpoint definitions
- `web/lib/hooks/use-api.ts` - React hooks
- `web/types/api.ts` - TypeScript types
- `web/components/api-status.tsx` - Status indicator
- `web/app/dashboard/api-test/page.tsx` - Test page
- `web/.env.local` - Environment variables

## 🎯 Ready for Development

The front-end is now fully connected to the backend API. You can:

1. Make API calls from any component
2. Use the provided hooks for React components
3. Test endpoints using the test page
4. Monitor connection status with the status indicator

Next: Start implementing authentication flows and connecting real data!


