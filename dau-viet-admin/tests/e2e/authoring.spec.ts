import { expect, test, type Page } from "@playwright/test";

/**
 * Browser-level authoring flow against the controlled node:http stub
 * (scripts/e2e-backend-stub.mjs). The stub is NOT the real Spring Boot
 * backend — it keeps an in-memory store so create → save → reopen can be
 * exercised end-to-end in a real browser.
 */

async function login(page: Page) {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
}

test("content admin creates an event via the form", async ({ page }) => {
  // Cold dev-server compiles /events/new + /events/[id] on first hit — the
  // default 30s budget is not enough on a cold start.
  test.setTimeout(120_000);
  await login(page);

  await page.goto("/events/new");
  await page.getByLabel(/tiêu đề/i).fill("Chiến thắng Điện Biên Phủ");
  // Slug is auto-suggested from the title.
  await expect(page.getByLabel(/slug/i)).toHaveValue("chien-thang-dien-bien-phu");
  await page.getByLabel(/năm bắt đầu/i).fill("1954");
  await page.getByLabel(/tóm tắt/i).fill("Chiến dịch lịch sử lật đổ thực dân Pháp.");
  await page.getByRole("button", { name: /tạo sự kiện/i }).click();

  // Lands on the editor of the newly created event.
  await expect(page).toHaveURL(/\/events\/[0-9a-f-]{36}/, { timeout: 20_000 });
  await expect(page.getByLabel(/tiêu đề/i)).toHaveValue("Chiến thắng Điện Biên Phủ", {
    timeout: 20_000,
  });
  await expect(page.getByLabel(/tóm tắt/i)).toHaveValue(
    "Chiến dịch lịch sử lật đổ thực dân Pháp.",
  );
});

test("Bạch Đằng flow: create lesson draft, reopen, reload persists", async ({ page }) => {
  await login(page);

  // Wizard step 1 — pick the seeded Bạch Đằng event.
  await page.goto("/lessons/new");
  await page
    .getByRole("button", { name: /trận bạch đằng 938/i })
    .click({ timeout: 20_000 });
  await page.getByRole("button", { name: /tiếp tục/i }).click();

  // Step 2 — pick the real template from the stub catalogue.
  await page.getByRole("button", { name: /điều tra sự kiện/i }).click();
  await page.getByRole("button", { name: /tiếp tục/i }).click();

  // Step 3 — basic info.
  await page.getByLabel(/tiêu đề bài học/i).fill("Bí mật chiến thắng Bạch Đằng");
  await page
    .getByLabel(/câu hỏi trung tâm/i)
    .fill("Vì sao Ngô Quyền đánh bại quân Nam Hán năm 938?");
  await page.getByPlaceholder("Mục tiêu 1").fill("Hiểu được bối cảnh lịch sử");
  await page.getByRole("button", { name: /tiếp tục/i }).click();

  // Step 4 — confirm and save draft.
  await page.getByRole("button", { name: /lưu bản nháp/i }).click();

  // Lands on the basic editor of the new draft.
  await expect(page).toHaveURL(/\/lessons\/[0-9a-f-]{36}/, { timeout: 20_000 });
  await expect(page.getByLabel(/tiêu đề \*/i)).toHaveValue(
    "Bí mật chiến thắng Bạch Đằng",
    { timeout: 20_000 },
  );

  // Reopen via a hard reload — the draft must persist (stub holds it in memory).
  await page.reload();
  await expect(page.getByLabel(/tiêu đề \*/i)).toHaveValue(
    "Bí mật chiến thắng Bạch Đằng",
    { timeout: 20_000 },
  );
  await expect(page.getByLabel(/câu hỏi trung tâm/i)).toHaveValue(
    "Vì sao Ngô Quyền đánh bại quân Nam Hán năm 938?",
  );
  await expect(page.getByRole("textbox").nth(2)).toHaveValue(
    "Hiểu được bối cảnh lịch sử",
  );
});
