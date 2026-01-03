export interface Feed {
  id: string;
  user_id: string;
  name: string;
  color?: string | null;
  emoji?: string | null;
  custom_image_url?: string | null;
  description?: string | null;
  rss_feed_url?: string | null;
  is_default: boolean;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface FeedItemWithAuthor {
  id: string;
  social_profile_id: string;
  platform_post_id: string;
  content_text: string;
  content_html?: string | null;
  media_urls?: unknown;
  hashtags?: unknown;
  thumbnail?: string | null;
  post_url: string;
  posted_at: string;
  scraped_at: string;
  created_at: string;
  deleted_at?: string | null;
  author_username: string;
  author_display_name?: string | null;
  author_avatar_url?: string | null;
  platform_name: string;
}

export interface RSSItem {
  title: string;
  link: string;
  guid: string;
  pubDate: string;
  description: string;
  enclosure?: {
    url: string;
    type: string;
  };
}
