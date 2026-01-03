-- Function to get feed items with author information
-- Replicates the Go query logic from GetFeedItemsForUser
CREATE OR REPLACE FUNCTION get_feed_items_with_authors(
  p_social_profile_ids UUID[],
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  social_profile_id UUID,
  platform_post_id TEXT,
  content_text TEXT,
  content_html TEXT,
  media_urls JSONB,
  hashtags JSONB,
  thumbnail TEXT,
  post_url TEXT,
  posted_at TIMESTAMP WITH TIME ZONE,
  scraped_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  deleted_at TIMESTAMP WITH TIME ZONE,
  author_username TEXT,
  author_display_name TEXT,
  author_avatar_url TEXT,
  platform_name TEXT
)
LANGUAGE SQL STABLE
AS $$
  SELECT
    feed_items.id,
    feed_items.social_profile_id,
    feed_items.platform_post_id,
    feed_items.content_text,
    feed_items.content_html,
    feed_items.media_urls,
    feed_items.hashtags,
    feed_items.thumbnail,
    feed_items.post_url,
    feed_items.posted_at,
    feed_items.scraped_at,
    feed_items.created_at,
    feed_items.deleted_at,
    social_profiles.username as author_username,
    social_profiles.display_name as author_display_name,
    social_profiles.avatar_url as author_avatar_url,
    COALESCE(platforms.name, 'other') as platform_name
  FROM feed_items
  LEFT JOIN social_profiles
    ON feed_items.social_profile_id = social_profiles.id
    AND social_profiles.deleted_at IS NULL
  LEFT JOIN platforms
    ON social_profiles.platform = platforms.id
  WHERE feed_items.social_profile_id = ANY(p_social_profile_ids)
    AND feed_items.deleted_at IS NULL
  ORDER BY feed_items.posted_at DESC
  LIMIT p_limit;
$$;
