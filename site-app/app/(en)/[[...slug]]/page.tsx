import { docsMetadata, renderDocsPage, staticParams } from '@/lib/docs-page';

export default async function Page(props: { params: Promise<{ slug?: string[] }> }) {
  const params = await props.params;
  return renderDocsPage(params.slug, 'en');
}

export function generateStaticParams() {
  return staticParams('en');
}

export async function generateMetadata(props: { params: Promise<{ slug?: string[] }> }) {
  const params = await props.params;
  return docsMetadata(params.slug, 'en');
}
