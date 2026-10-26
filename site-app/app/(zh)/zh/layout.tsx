import { DocsShell } from '@/lib/docs-shell';
import type { ReactNode } from 'react';

export default function Layout({ children }: { children: ReactNode }) {
  return <DocsShell locale="zh">{children}</DocsShell>;
}
