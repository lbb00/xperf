import type { MetadataRoute } from 'next';
import { SITE_URL, absoluteUrl, pagePath } from '@/lib/site-meta';
import { source } from '@/lib/source';

export const dynamic = 'force-static';

function withTrailingSlash(path: string): string {
  if (path === '/') return '/';
  return path.endsWith('/') ? path : `${path}/`;
}

export default function sitemap(): MetadataRoute.Sitemap {
  const byKey = new Map<string, { en?: string; zh?: string; depth: number; firstSlug?: string }>();

  for (const locale of ['en', 'zh'] as const) {
    for (const page of source.getPages(locale)) {
      const path = withTrailingSlash(page.url || '/');
      const url = absoluteUrl(path === '/' ? '/' : path);
      const key = (page.slugs ?? []).join('/') || '';
      const row = byKey.get(key) ?? { depth: page.slugs?.length ?? 0, firstSlug: page.slugs?.[0] };
      if (locale === 'en') row.en = url;
      else row.zh = url;
      row.depth = page.slugs?.length ?? 0;
      row.firstSlug = page.slugs?.[0];
      byKey.set(key, row);
    }
  }

  // Ensure home keys exist even if a locale omits the root somehow.
  if (!byKey.has('')) {
    byKey.set('', {
      en: absoluteUrl(pagePath(undefined, 'en')),
      zh: absoluteUrl(pagePath(undefined, 'zh')),
      depth: 0,
    });
  }

  const entries: MetadataRoute.Sitemap = [];
  for (const row of byKey.values()) {
    const url = row.en ?? row.zh;
    if (!url) continue;
    let priority = 0.6;
    if (row.depth === 0) priority = 1;
    else if (row.firstSlug === 'docs') priority = 0.8;
    else if (row.firstSlug === 'packages') priority = 0.7;

    const languages: Record<string, string> = {};
    if (row.en) languages.en = row.en;
    if (row.zh) languages['zh-CN'] = row.zh;
    if (row.en) languages['x-default'] = row.en;

    entries.push({
      url,
      changeFrequency: 'weekly',
      priority,
      alternates: Object.keys(languages).length ? { languages } : undefined,
    });
    // Also list the zh URL as its own entry when both exist (crawlers that ignore xhtml links).
    if (row.en && row.zh && row.zh !== row.en) {
      entries.push({
        url: row.zh,
        changeFrequency: 'weekly',
        priority,
        alternates: { languages },
      });
    }
  }

  return entries;
}
