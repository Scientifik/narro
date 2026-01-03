import type { Feed, FeedItemWithAuthor } from './types.ts';

function escapeXML(str: string): string {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function formatRFC1123Z(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toUTCString();
}

export function buildRSSXML(feed: Feed, items: FeedItemWithAuthor[]): string {
  const lastBuildDate = formatRFC1123Z(new Date().toISOString());

  let xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>${escapeXML(feed.name)}</title>
    <link>https://narro.app</link>
    <description>${escapeXML(feed.name)} Feed</description>
    <lastBuildDate>${lastBuildDate}</lastBuildDate>
    <generator>Narro</generator>
`;

  for (const item of items) {
    // Truncate content for title if too long
    let title = item.content_text;
    if (title.length > 100) {
      title = title.substring(0, 97) + '...';
    }

    xml += `    <item>
      <title>${escapeXML(title)}</title>
      <link>${escapeXML(item.post_url)}</link>
      <guid>${item.id}</guid>
      <pubDate>${formatRFC1123Z(item.posted_at)}</pubDate>
      <description>${escapeXML(item.content_text)}</description>
`;

    if (item.thumbnail) {
      xml += `      <enclosure url="${escapeXML(item.thumbnail)}" type="image/jpeg"/>
`;
    }

    xml += `    </item>
`;
  }

  xml += `  </channel>
</rss>`;

  return xml;
}
