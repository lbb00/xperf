import { docsMetadata, renderDocsPage, staticParams } from '@/lib/docs-page';

export default async function Page(props: { params: Promise<{ slug?: string[] }> }) {
  const params = await props.params;
  return renderDocsPage(params.slug, 'zh');
}

export function generateStaticParams() {
  return staticParams('zh');
}

export async function generateMetadata(props: { params: Promise<{ slug?: string[] }> }) {
  const params = await props.params;
  return docsMetadata(params.slug, 'zh');
}
