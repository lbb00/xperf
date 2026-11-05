import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import { RootProvider } from 'fumadocs-ui/provider/next';
import type { ReactNode } from 'react';
import SearchDialog from '@/components/search';
import { HtmlLang } from '@/components/html-lang';
import { i18n, type Locale } from '@/lib/i18n';
import { baseOptions } from '@/lib/layout.shared';
import { htmlLang, siteJsonLd } from '@/lib/site-meta';
import { source } from '@/lib/source';

export function DocsShell({ locale, children }: { locale: Locale; children: ReactNode }) {
  const lang = htmlLang(locale);
  const jsonLd = siteJsonLd(locale);
  return (
    <RootProvider i18n={i18n.provider(locale)} search={{ SearchDialog }}>
      <HtmlLang lang={lang} />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <div lang={lang} className="flex min-h-screen flex-col">
        <DocsLayout tree={source.getPageTree(locale)} {...baseOptions(locale)}>
          {children}
        </DocsLayout>
      </div>
    </RootProvider>
  );
}
