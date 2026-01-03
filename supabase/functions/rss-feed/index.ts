import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { getFeedById, getFeedItemsForFeed } from './database.ts';
import { buildRSSXML } from './rss-generator.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Extract feed ID from URL path
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/');
    const feedIdWithExt = pathParts[pathParts.length - 1]; // e.g., "123e4567-e89b-12d3-a456-426614174000.rss"

    // Remove .rss extension
    const feedId = feedIdWithExt.replace(/\.rss$/, '');

    console.log('[RSS] Requested feed ID:', feedId);

    // Validate UUID format
    if (!UUID_REGEX.test(feedId)) {
      console.error('[RSS] Invalid UUID format:', feedId);
      return new Response('Invalid feed ID', {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
      });
    }

    // Initialize Supabase client with service role key
    const apiUrl = Deno.env.get('API_URL');
    const serviceKey = Deno.env.get('SERVICE_ROLE_KEY');

    if (!apiUrl || !serviceKey) {
      console.error('[RSS] Missing API configuration');
      return new Response('Server configuration error', {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
      });
    }

    const supabase = createClient(apiUrl, serviceKey);

    // Get feed metadata
    const feed = await getFeedById(supabase, feedId);
    if (!feed) {
      console.error('[RSS] Feed not found:', feedId);
      return new Response('Feed not found', {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
      });
    }

    console.log('[RSS] Feed found:', feed.name, 'for user:', feed.user_id);

    // Get feed items (last 50)
    const feedItems = await getFeedItemsForFeed(
      supabase,
      feedId,
      feed.user_id,
      50
    );

    console.log('[RSS] Items returned:', feedItems.length);

    // Generate RSS XML
    const rssXML = buildRSSXML(feed, feedItems);

    // Return RSS with caching headers (15 minutes)
    return new Response(rssXML, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/rss+xml; charset=utf-8',
        'Cache-Control': 'public, max-age=900', // 15 minutes
        'CDN-Cache-Control': 'public, max-age=900',
      },
    });
  } catch (error) {
    console.error('[RSS] Error generating RSS feed:', error);
    return new Response('Error generating RSS feed', {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
    });
  }
});
