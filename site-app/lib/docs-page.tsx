import { DocsBody, DocsDescription, DocsPage, DocsTitle } from 'fumadocs-ui/layouts/docs/page';
import { createRelativeLink } from 'fumadocs-ui/mdx';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { getMDXComponents } from '@/components/mdx';
import type { Locale } from '@/lib/i18n';
import { source } from '@/lib/source';

function load(slugs: string[] | undefined, locale: Locale) {
  const page = source.getPage(slugs, locale);
  if (!page) notFound();
  return page;
}

export function renderDocsPage(slugs: string[] | undefined, locale: Locale) {
  const page = load(slugs, locale);
  const MDX = page.data.body;
  const untranslated = locale === 'zh' && !page.path.endsWith('.zh.md');

  return (
    <DocsPage toc={page.data.toc} full={page.data.full}>
      <DocsTitle>{page.data.title}</DocsTitle>
      {page.data.description ? <DocsDescription>{page.data.description}</DocsDescription> : null}
      <DocsBody>
        {untranslated ? (
          <p className="text-fd-muted-foreground text-sm">这篇还没有中文，下面是英文原文。</p>
        ) : null}
        <MDX
          components={getMDXComponents({
            a: createRelativeLink(source, page),
          })}
        />
      </DocsBody>
    </DocsPage>
  );
}

export function docsMetadata(slugs: string[] | undefined, locale: Locale): Metadata {
  const page = load(slugs, locale);
  const title = page.data.title === 'XPerf' ? { absolute: 'XPerf' } : page.data.title;
  return {
    title,
    description: page.data.description,
  };
}

export function staticParams(locale: Locale) {
  return source.getPages(locale).map((page) => ({ slug: page.slugs }));
}
