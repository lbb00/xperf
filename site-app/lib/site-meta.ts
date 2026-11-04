/** Shared SEO / social metadata for the docs site (GitHub Pages under /xperf). */

export const SITE_URL = 'https://lbb00.github.io/xperf';

export const SITE_NAME = 'XPerf';

/** One-line value prop — keep honest: hints ≠ guaranteed speedups. */
export const SITE_DESCRIPTION =
  'Performance guides and heuristic linters for 19 languages. A lint hit means look here, not this will be faster — rules stay hints until paired fixtures and measured before/after evidence.';

export const SITE_DESCRIPTION_ZH =
  '19 种语言的性能指南与启发式检查器。命中表示「值得看」，不等于「改了就更快」；规则默认是 hint，直到有配对夹具和实测前后对比。';

export const OG_IMAGE_PATH = '/og.png';

export const OG_IMAGE_ALT = 'XPerf — measured performance guides and heuristic linters';

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
