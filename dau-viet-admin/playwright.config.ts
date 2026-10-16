import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright e2e — Login → Dashboard against the controlled node:http stub.
 * Two webServers: (1) stub backend on :8081, (2) `next dev` on :3100 with
 * BACKEND_URL pointed at the stub. Port 3100 avoids collisions with a dev
 * server already running on :3000.
 */
export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  use: {
    baseURL: "http://localhost:3100",
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: [
    {
      command: "node scripts/e2e-backend-stub.mjs",
      url: "http://localhost:8081/api/v1/admin/ping",
      reuseExistingServer: !process.env.CI,
      timeout: 15_000,
      env: { BACKEND_STUB_PORT: "8081" },
    },
    {
      command: "npm run dev -- --port 3100",
      url: "http://localhost:3100/login",
      reuseExistingServer: !process.env.CI,
      timeout: 60_000,
      env: { BACKEND_URL: "http://localhost:8081" },
    },
  ],
});
