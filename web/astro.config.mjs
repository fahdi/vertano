// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://vertano.app',
  trailingSlash: 'always',
  outDir: '../docs',
  publicDir: 'public',
  build: { format: 'directory' },
  integrations: [sitemap({ filter: (p) => !p.includes('/app/') && !p.includes('/superpowers/') })],
});
