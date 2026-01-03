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
  // Step 1: Get feed_profile_items for this feed
  const { data: feedProfileItems, error: feedProfileError } = await supabase
    .from('feed_profile_items')
    .select('user_social_profile_id')
    .eq('feed_id', feedId)
    .is('deleted_at', null);

  if (feedProfileError || !feedProfileItems?.length) {
    console.error('[RSS] Feed profile items error:', feedProfileError);
    return [];
  }

  const userSocialProfileIds = feedProfileItems.map(
    (item: any) => item.user_social_profile_id
  );

  // Step 2: Get social_profile_ids from user_social_profiles
  const { data: userSocialProfiles, error: uspError } = await supabase
    .from('user_social_profiles')
    .select('social_profile_id')
    .eq('user_id', userId)
    .in('id', userSocialProfileIds)
    .is('deleted_at', null);

  if (uspError || !userSocialProfiles?.length) {
    console.error('[RSS] User social profiles error:', uspError);
    return [];
  }

  const socialProfileIds = userSocialProfiles.map(
    (usp: any) => usp.social_profile_id
  );

  // Step 3: Call Postgres function for feed items with author information
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
