import { remarkMdxMermaid } from 'fumadocs-core/mdx-plugins';
import { loader } from 'fumadocs-core/source';
import { applyMdxPreset } from 'fumadocs-mdx/config';
import { defineDocs } from 'fumadocs-mdx/macro';
import { i18n } from '@/lib/i18n';

const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    mdxOptions: (environment) =>
      applyMdxPreset({
        remarkPlugins: [remarkMdxMermaid],
      })(environment),
  },
});

export const source = loader({
  baseUrl: '/',
  i18n,
  source: docs.toFumadocsSource(),
});
