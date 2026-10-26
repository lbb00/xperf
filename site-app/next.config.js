import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();
const basePath = (process.env.PAGES_BASE_PATH || '').replace(/\/$/, '');
const staticExport = process.env.PAGES_STATIC === '1';

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  agentRules: false,
  trailingSlash: true,
  ...(basePath ? { basePath, assetPrefix: basePath } : {}),
  ...(staticExport ? { output: 'export', images: { unoptimized: true } } : {}),
};

export default withMDX(config);
