import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://cordierite.veltiosoft.com',
  output: 'static',
  trailingSlash: 'always',
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'ja'],
    routing: {
      prefixDefaultLocale: false,
    },
  },
});
