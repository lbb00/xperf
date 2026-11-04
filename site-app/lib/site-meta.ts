/** Shared SEO / GEO / social metadata for the docs site (GitHub Pages under /xperf). */

export const SITE_URL = 'https://lbb00.github.io/xperf';

export const SITE_NAME = 'XPerf';

/** One-line value prop — keep honest: hints ≠ guaranteed speedups. */
export const SITE_DESCRIPTION =
  'Performance guides and heuristic linters for 19 languages. A lint hit means look here, not this will be faster — rules stay hints until paired fixtures and measured before/after evidence.';

export const SITE_DESCRIPTION_ZH =
  '19 种语言的性能指南与启发式检查器。命中表示「值得看」，不等于「改了就更快」；规则默认是 hint，直到有配对夹具和实测前后对比。';

export const OG_IMAGE_PATH = '/og.png';

export const OG_IMAGE_ALT = 'XPerf — measured performance guides and heuristic linters';

export const REPO_URL = 'https://github.com/lbb00/xperf';

/** JSON-LD for generative engines and rich results (GEO + classic SEO). */
export function siteJsonLd(): Record<string, unknown>[] {
  return [
    {
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      name: SITE_NAME,
      url: SITE_URL,
      description: SITE_DESCRIPTION,
      inLanguage: ['en', 'zh-CN'],
    },
    {
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      name: SITE_NAME,
      applicationCategory: 'DeveloperApplication',
      operatingSystem: 'Cross-platform',
      url: SITE_URL,
      downloadUrl: REPO_URL,
      description: SITE_DESCRIPTION,
      license: 'https://opensource.org/licenses/MIT',
      codeRepository: REPO_URL,
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'USD',
      },
    },
  ];
}

export function pagePath(slugs: string[] | undefined, locale: 'en' | 'zh'): string {
  const parts = slugs?.filter(Boolean) ?? [];
  const tail = parts.length ? `${parts.join('/')}/` : '';
  if (locale === 'zh') return `/zh/${tail}`;
  return `/${tail}`;
}

export function absoluteUrl(path: string): string {
  const normalized = path.startsWith('/') ? path : `/${path}`;
  return `${SITE_URL}${normalized}`;
}
