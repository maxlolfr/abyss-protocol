import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';

// base relative : le même build marche sur GitHub Pages, dans Capacitor et en local.
export default defineConfig({
  base: './',
  build: {
    outDir: 'dist',
    chunkSizeWarningLimit: 1600,
    // deux pages : le prototype (index) et la démo premium de la salle Némésis
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        nemesis: fileURLToPath(new URL('./nemesis.html', import.meta.url)),
      },
    },
  },
  test: { include: ['tests/**/*.test.ts'] },
} as never);
