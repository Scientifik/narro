import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { Feed, FeedItemWithAuthor } from './types.ts';

export async function getFeedById(
  supabase: SupabaseClient,
  feedId: string
): Promise<Feed | null> {
  const { data, error } = await supabase
    .from('feeds')
    .select('*')
    .eq('id', feedId)
    .is('deleted_at', null)
    .single();

  if (error) {
    console.error('[RSS] Feed query error:', error);
    return null;
  }

  return data;
}

export async function getFeedItemsForFeed(
  supabase: SupabaseClient,
  feedId: string,
  userId: string,
  limit: number = 50
): Promise<FeedItemWithAuthor[]> {
  // Get social_profile_ids directly from user_feed_profiles (consolidated table)
  const { data: userFeedProfiles, error: ufpError } = await supabase
    .from('user_feed_profiles')
    .select('social_profile_id')
    .eq('feed_id', feedId)
    .eq('user_id', userId)
    .is('deleted_at', null);

  if (ufpError || !userFeedProfiles?.length) {
    console.error('[RSS] User feed profiles error:', ufpError);
    return [];
  }

  const socialProfileIds = userFeedProfiles.map(
    (ufp: any) => ufp.social_profile_id
  );

  // Call Postgres function for feed items with author information
  const { data: feedItems, error: itemsError } = await supabase
    .rpc('get_feed_items_with_authors', {
      p_social_profile_ids: socialProfileIds,
      p_limit: limit,
    });

  if (itemsError) {
    console.error('[RSS] Feed items query error:', itemsError);
    return [];
  }

  return feedItems || [];
}
