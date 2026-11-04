import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site-meta';
import { source } from '@/lib/source';

export const dynamic = 'force-static';

function withTrailingSlash(path: string): string {
  if (path === '/') return '/';
  return path.endsWith('/') ? path : `${path}/`;
}

export default function sitemap(): MetadataRoute.Sitemap {
  const seen = new Set<string>();
  const entries: MetadataRoute.Sitemap = [];

  for (const locale of ['en', 'zh'] as const) {
    for (const page of source.getPages(locale)) {
      const path = withTrailingSlash(page.url || '/');
      const url = `${SITE_URL}${path === '/' ? '/' : path}`;
      if (seen.has(url)) continue;
      seen.add(url);

      const depth = page.slugs?.length ?? 0;
      let priority = 0.6;
      if (depth === 0) priority = 1;
      else if (page.slugs?.[0] === 'docs') priority = 0.8;
      else if (page.slugs?.[0] === 'packages') priority = 0.7;

      entries.push({
        url,
        changeFrequency: 'weekly',
        priority,
      });
    }
  }

  return entries;
}
