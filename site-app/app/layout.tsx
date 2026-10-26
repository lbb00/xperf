import type { ReactNode } from 'react';
import './global.css';

export const metadata = {
  title: {
    default: 'XPerf',
    template: '%s | XPerf',
  },
  description: 'Measured performance guides and heuristic linters for 19 languages.',
};

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="flex min-h-screen flex-col">
        {children}
      </body>
    </html>
  );
}
