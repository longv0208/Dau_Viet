import { expect, test, type Page } from "@playwright/test";

/**
 * Builder e2e against the controlled node:http stub (NOT the real backend).
 * Creates a fresh lesson via the wizard, opens the builder, authors stages +
 * activities, saves, reloads, and asserts the draft round-trips.
 */

async function login(page: Page) {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
}

async function createLesson(page: Page, title: string) {
  await page.goto("/lessons/new");
  await page.getByRole("button", { name: /trận bạch đằng 938/i }).click({ timeout: 20_000 });
  await page.getByRole("button", { name: /tiếp tục/i }).click();
  await page.getByRole("button", { name: /điều tra sự kiện/i }).click();
  await page.getByRole("button", { name: /tiếp tục/i }).click();
  await page.getByLabel(/tiêu đề bài học/i).fill(title);
  await page.getByLabel(/câu hỏi trung tâm/i).fill("Câu hỏi trung tâm của bài học?");
  await page.getByPlaceholder("Mục tiêu 1").fill("Mục tiêu đầu tiên");
  await page.getByRole("button", { name: /tiếp tục/i }).click();
  await page.getByRole("button", { name: /lưu bản nháp/i }).click();
  // First-run dev compile can be slow — allow extra headroom.
  await expect(page).toHaveURL(/\/lessons\/[0-9a-f-]{36}$/, { timeout: 45_000 });
  const url = page.url();
  return url.substring(url.lastIndexOf("/") + 1);
}

test("builder: add stage + activity, save, reload persists", async ({ page }) => {
  test.setTimeout(90_000); // first dev-compile of the builder route can be slow
  await login(page);
  const lessonId = await createLesson(page, "Builder E2E — sắp xếp diễn biến");

  await page.goto(`/lessons/${lessonId}/builder`, { timeout: 60_000 });
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 30_000 });

  // Thêm stage CONTEXT với READ activity.
  await page.getByRole("button", { name: /thêm giai đoạn/i }).click();
  await expect(page.getByText("Giai đoạn (1)")).toBeVisible();
  await page.getByLabel(/tên giai đoạn/i).fill("Bối cảnh sông Bạch Đằng");
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  await page.getByRole("button", { name: /đọc tư liệu/i }).click();

  // Điền instruction + nội dung READ.
  await page.getByLabel(/hướng dẫn cho học viên/i).fill("Đọc kỹ đoạn tư liệu");
  await page.getByLabel(/nội dung đọc/i).fill("Năm 938 quân Nam Hán đóng thuyền ở cửa sông…");

  // Lưu — stub accepts và bump rowVersion.
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/đã lưu/i)).toBeVisible({ timeout: 15_000 });

  // Reload — dữ liệu vẫn còn; activity editor cần click để mở lại.
  await page.reload();
  await expect(page.getByText("Giai đoạn (1)")).toBeVisible({ timeout: 20_000 });
  await expect(page.getByLabel(/tên giai đoạn/i)).toHaveValue("Bối cảnh sông Bạch Đằng");
  await page.getByRole("button", { name: /đọc kỹ đoạn tư liệu/i }).click();
  await expect(page.getByLabel(/nội dung đọc/i)).toHaveValue(
    "Năm 938 quân Nam Hán đóng thuyền ở cửa sông…",
  );
});

test("builder: template seeding appends stages from presetJson", async ({ page }) => {
  await login(page);
  const lessonId = await createLesson(page, "Builder E2E — khung mẫu");

  await page.goto(`/lessons/${lessonId}/builder`);
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 20_000 });

  page.once("dialog", (d) => void d.accept());
  await page.getByRole("button", { name: /tạo cấu trúc từ khung bài học/i }).click();
  await expect(page.getByText("Giai đoạn (2)")).toBeVisible();
  await expect(page.getByText(/bối cảnh \(mẫu\)/i)).toBeVisible();
});

test("builder: 422 shows validation panel; validate shows readiness", async ({ page }) => {
  await login(page);
  const lessonId = await createLesson(page, "Builder E2E — lỗi lưu");

  await page.goto(`/lessons/${lessonId}/builder`);
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 20_000 });

  // Thêm EVIDENCE stage + MC thiếu question → stub trả 422 INVALID_CONFIG.
  await page.getByLabel(/loại giai đoạn mới/i).selectOption("EVIDENCE");
  await page.getByRole("button", { name: /thêm giai đoạn/i }).click();
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  await page.getByRole("button", { name: /trắc nghiệm/i }).click();

  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/lỗi từ máy chủ/i)).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText(/INVALID_CONFIG/)).toBeVisible();

  // Sửa question + lưu lại thành công (validate đọc bản nháp ĐÃ LƯU trên stub).
  await page.getByLabel(/câu hỏi \*/i).fill("Câu hỏi?");
  // MC đã có ≥2 options mặc định? Chưa — thêm 2 đáp án.
  await page.getByRole("button", { name: /thêm đáp án/i }).click();
  await page.getByRole("button", { name: /thêm đáp án/i }).click();
  await page.getByPlaceholder("Đáp án 1").fill("A");
  await page.getByPlaceholder("Đáp án 2").fill("B");
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/đã lưu/i)).toBeVisible({ timeout: 15_000 });

  // Kiểm tra xuất bản — chưa ready vì MC chưa tick "bắt buộc" (stub rule).
  await page.getByRole("button", { name: /kiểm tra xuất bản/i }).click();
  await expect(page.getByText(/chưa sẵn sàng xuất bản/i)).toBeVisible({ timeout: 15_000 });
});
