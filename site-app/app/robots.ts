import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site-meta';

export const dynamic = 'force-static';

/** Allow general crawlers and common generative-engine / AI bots (GEO). */
const AI_BOTS = [
  'GPTBot',
  'ChatGPT-User',
  'Google-Extended',
  'anthropic-ai',
  'ClaudeBot',
  'Claude-Web',
  'PerplexityBot',
  'Bytespider',
  'CCBot',
  'meta-externalagent',
] as const;

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
      },
      ...AI_BOTS.map((userAgent) => ({
        userAgent,
        allow: '/',
      })),
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
