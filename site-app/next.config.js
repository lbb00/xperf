import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();
const basePath = (process.env.PAGES_BASE_PATH || '').replace(/\/$/, '');
const staticExport = process.env.PAGES_STATIC === '1';

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  agentRules: false,
  trailingSlash: true,
  // Static GitHub Pages has no per-request UA. Force blocking metadata into the
  // exported HTML so description / Open Graph / Twitter tags are present for crawlers.
  htmlLimitedBots: /.*/,
  ...(basePath ? { basePath, assetPrefix: basePath } : {}),
  ...(staticExport ? { output: 'export', images: { unoptimized: true } } : {}),
};

export default withMDX(config);
