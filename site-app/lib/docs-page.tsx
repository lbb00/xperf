import { DocsBody, DocsDescription, DocsPage, DocsTitle } from 'fumadocs-ui/layouts/docs/page';
import { createRelativeLink } from 'fumadocs-ui/mdx';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { getMDXComponents } from '@/components/mdx';
import type { Locale } from '@/lib/i18n';
import {
  OG_IMAGE_ALT,
  OG_IMAGE_ALT_ZH,
  OG_IMAGE_PATH,
  SITE_NAME,
  descriptionFor,
  ogLocale,
  pagePath,
} from '@/lib/site-meta';
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
  // Always set a string. Returning `description: undefined` from generateMetadata
  // clears the root layout description in the static HTML export.
  const description = page.data.description?.trim() || descriptionFor(locale);
  const canonical = pagePath(slugs, locale);
  const enPath = pagePath(slugs, 'en');
  const zhPath = pagePath(slugs, 'zh');
  const ogTitle =
    typeof title === 'string' ? title : title.absolute === 'XPerf' ? SITE_NAME : String(page.data.title);
  const imageAlt = locale === 'zh' ? OG_IMAGE_ALT_ZH : OG_IMAGE_ALT;

  return {
    title,
    description,
    alternates: {
      canonical,
      languages: {
        en: enPath,
        'zh-CN': zhPath,
        'x-default': enPath,
      },
    },
    openGraph: {
      type: 'article',
      locale: ogLocale(locale),
      alternateLocale: locale === 'zh' ? ['en_US'] : ['zh_CN'],
      url: canonical,
      siteName: SITE_NAME,
      title: ogTitle,
      description,
      images: [
        {
          url: OG_IMAGE_PATH,
          width: 1200,
          height: 630,
          alt: imageAlt,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: ogTitle,
      description,
      images: [OG_IMAGE_PATH],
    },
  };
}

export function staticParams(locale: Locale) {
  return source.getPages(locale).map((page) => ({ slug: page.slugs }));
}
