import { defineConfig } from '@playwright/test';

const mobilePort = process.env.MOBILE_WEB_PORT || '4300';
const baseURL = process.env.MOBILE_WEB_URL || `http://localhost:${mobilePort}`;

export default defineConfig({
  testDir: './specs',
  timeout: 120_000,
  expect: {
    timeout: 20_000,
  },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: {
    baseURL,
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'mobile-chrome',
      use: {
        browserName: 'chromium',
        viewport: { width: 390, height: 844 },
      },
    },
  ],
  webServer: {
    command: 'node scripts/serve-flutter-web.mjs',
    url: baseURL,
    reuseExistingServer: true,
    timeout: 180_000,
    env: {
      MOBILE_WEB_PORT: String(mobilePort),
      API_BASE_URL: process.env.API_BASE_URL || 'http://localhost:8080',
    },
  },
});
