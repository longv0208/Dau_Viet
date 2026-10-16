import { expect, test } from "@playwright/test";

/**
 * Browser-level Login → Dashboard flow against the controlled node:http stub
 * (scripts/e2e-backend-stub.mjs). The stub is NOT the real backend — it only
 * proves the admin's BFF wiring end-to-end in a real browser.
 */

test("admin can login and reach dashboard", async ({ page }) => {
  await page.goto("/login");

  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();

  // Dev-mode SSR + first-compile can take >5s on a cold run.
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
  await expect(page.getByText(/xin chào/i)).toBeVisible({ timeout: 20_000 });
  await expect(page.getByText(/backend: hoạt động/i)).toBeVisible({ timeout: 20_000 });
});

test("session survives a page reload (refresh rotation)", async ({ page }) => {
  // Regression guard for the P0 review finding: after login, a reload must
  // still land on /dashboard — the rotated dv_refresh cookie has to reach the
  // browser or the next refresh hits a revoked token and force-logs-out.
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });

  await page.reload();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
  await expect(page.getByText(/xin chào/i)).toBeVisible({ timeout: 20_000 });
});

test("invalid credentials surface a Vietnamese error", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("wrong");
  await page.getByRole("button", { name: /đăng nhập/i }).click();

  await expect(page.getByText(/email hoặc mật khẩu không đúng/i)).toBeVisible();
  await expect(page).toHaveURL(/\/login/);
});
