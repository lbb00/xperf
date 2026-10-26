import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import { RootProvider } from 'fumadocs-ui/provider/next';
import type { ReactNode } from 'react';
import SearchDialog from '@/components/search';
import { HtmlLang } from '@/components/html-lang';
import { i18n, type Locale } from '@/lib/i18n';
import { baseOptions } from '@/lib/layout.shared';
import { source } from '@/lib/source';

const htmlLang: Record<Locale, string> = { en: 'en', zh: 'zh-CN' };

export function DocsShell({ locale, children }: { locale: Locale; children: ReactNode }) {
  return (
    <RootProvider i18n={i18n.provider(locale)} search={{ SearchDialog }}>
      <HtmlLang lang={htmlLang[locale]} />
      <div lang={htmlLang[locale]} className="flex min-h-screen flex-col">
        <DocsLayout tree={source.getPageTree(locale)} {...baseOptions(locale)}>
          {children}
        </DocsLayout>
      </div>
    </RootProvider>
  );
}
