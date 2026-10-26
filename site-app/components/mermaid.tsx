'use client';

import { useTheme } from 'next-themes';
import { useEffect, useId, useState } from 'react';

const light = {
  background: 'transparent',
  fontFamily: 'Geist Variable, ui-sans-serif, system-ui, sans-serif',
  fontSize: '14px',
  textColor: '#18181b',
  primaryColor: '#fafafa',
  primaryTextColor: '#18181b',
  primaryBorderColor: '#d4d4d8',
  secondaryColor: '#fafafa',
  secondaryTextColor: '#18181b',
  secondaryBorderColor: '#d4d4d8',
  tertiaryColor: '#fafafa',
  tertiaryTextColor: '#18181b',
  tertiaryBorderColor: '#d4d4d8',
  lineColor: '#71717a',
  mainBkg: '#fafafa',
  nodeBorder: '#d4d4d8',
  clusterBkg: '#fafafa',
  clusterBorder: '#e4e4e7',
  titleColor: '#3f3f46',
  edgeLabelBackground: '#fafafa',
};

const dark = {
  background: 'transparent',
  fontFamily: 'Geist Variable, ui-sans-serif, system-ui, sans-serif',
  fontSize: '14px',
  textColor: '#fafafa',
  primaryColor: '#27272a',
  primaryTextColor: '#fafafa',
  primaryBorderColor: '#52525b',
  secondaryColor: '#27272a',
  secondaryTextColor: '#fafafa',
  secondaryBorderColor: '#52525b',
  tertiaryColor: '#27272a',
  tertiaryTextColor: '#fafafa',
  tertiaryBorderColor: '#52525b',
  lineColor: '#a1a1aa',
  mainBkg: '#27272a',
  nodeBorder: '#52525b',
  clusterBkg: '#18181b',
  clusterBorder: '#3f3f46',
  titleColor: '#e4e4e7',
  edgeLabelBackground: '#27272a',
};

let renderQueue = Promise.resolve();

function enqueue(task: () => Promise<void>) {
  const run = renderQueue.then(task, task);
  renderQueue = run.then(
    () => undefined,
    () => undefined,
  );
  return run;
}

export function Mermaid({ chart }: { chart: string }) {
  const { resolvedTheme } = useTheme();
  const id = useId().replace(/:/g, '');
  const [svg, setSvg] = useState('');

  useEffect(() => {
    if (resolvedTheme !== 'dark' && resolvedTheme !== 'light') return;
    const theme = resolvedTheme;
    let cancel = false;
    const renderId = `xperf-${id}-${theme}-${Math.random().toString(36).slice(2, 8)}`;
    enqueue(async () => {
      if (cancel) return;
      await document.fonts.ready;
      if (cancel) return;
      const mermaid = (await import('mermaid')).default;
      const elkLayouts = (await import('@mermaid-js/layout-elk')).default;
      mermaid.registerLayoutLoaders(elkLayouts);
      mermaid.initialize({
        startOnLoad: false,
        theme: 'base',
        securityLevel: 'strict',
        fontFamily: 'Geist Variable, ui-sans-serif, system-ui, sans-serif',
        htmlLabels: true,
        flowchart: {
          defaultRenderer: 'elk',
          wrappingWidth: 640,
        },
        themeVariables: theme === 'dark' ? dark : light,
      });
      const rendered = await mermaid.render(renderId, chart);
      document.getElementById(renderId)?.remove();
      if (!cancel) setSvg(rendered.svg);
    }).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : String(error);
      if (!cancel) setSvg('');
      console.error(message);
    });
    return () => {
      cancel = true;
    };
  }, [chart, id, resolvedTheme]);

  return (
    <figure
      className="xperf-mermaid not-prose my-6 overflow-x-auto rounded-xl border border-fd-border bg-fd-card px-3 py-4"
      dangerouslySetInnerHTML={svg ? { __html: svg } : undefined}
    />
  );
}
