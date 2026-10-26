import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import type { Locale } from '@/lib/i18n';

const repo = process.env.NEXT_PUBLIC_REPO_URL ?? 'https://github.com/lbb00/xperf';

export function baseOptions(locale: Locale = 'en'): BaseLayoutProps {
  return {
    nav: {
      title: 'XPerf',
      url: locale === 'zh' ? '/zh' : '/',
    },
    githubUrl: repo,
  };
}
