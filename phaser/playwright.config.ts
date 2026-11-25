import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: 'e2e',
  timeout: 60_000,
  use: { baseURL: 'http://localhost:4173', ...devices['Pixel 7 landscape'] },
  webServer: { command: 'npm run preview', port: 4173, reuseExistingServer: true },
});
