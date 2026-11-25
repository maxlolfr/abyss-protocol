import { defineConfig } from 'vite';

// base relative : le même build marche sur GitHub Pages, dans Capacitor et en local.
export default defineConfig({
  base: './',
  build: { outDir: 'dist', chunkSizeWarningLimit: 1600 },
  test: { include: ['tests/**/*.test.ts'] },
} as never);
