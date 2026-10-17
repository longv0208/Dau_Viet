import { expect, test, type Page } from "@playwright/test";

/**
 * TASK-0016 journey against the controlled node:http stub (NOT the real
 * backend): login → open lesson builder → attach library evidence to a READ
 * activity → write feedback → save → reload → confirm persisted.
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
  await expect(page).toHaveURL(/\/lessons\/[0-9a-f-]{36}$/, { timeout: 45_000 });
  const url = page.url();
  return url.substring(url.lastIndexOf("/") + 1);
}

test("evidence: create evidence in library, attach to READ, feedback, save, reload", async ({
  page,
}) => {
  test.setTimeout(120_000); // first dev-compile of new routes can be slow
  await login(page);

  // 1) Tạo bằng chứng mới trong thư viện (labels từ EvidenceForm).
  await page.goto("/evidence/new");
  await page.locator("#eventId").selectOption({ index: 1 });
  await page.locator("#title").fill("Ghi chép triều đình về lực lượng Nam Hán");
  await page.locator("#evidenceType").selectOption("GHI_CHEP");
  await page.locator("#sourceTitle").fill("An Nam chí lược");
  await page.getByRole("button", { name: /tạo bằng chứng/i }).click();
  // Sau khi tạo: reset form về trống (create mode ở lại trang) — chờ phản hồi.
  await expect(page.getByRole("button", { name: /tạo bằng chứng/i })).toBeEnabled({ timeout: 15_000 });

  // 2) Mở builder, thêm READ, gắn bằng chứng vừa có sẵn trong stub.
  const lessonId = await createLesson(page, "E2E — gắn bằng chứng");
  await page.goto(`/lessons/${lessonId}/builder`, { timeout: 60_000 });
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 30_000 });

  await page.getByRole("button", { name: /thêm giai đoạn/i }).click();
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  await page.getByRole("button", { name: /đọc tư liệu/i }).click();
  await page.getByLabel(/hướng dẫn cho học viên/i).fill("Đọc tư liệu có nguồn");
  await page.getByLabel(/nội dung đọc/i).fill("Đoạn tư liệu trích từ thư viện bằng chứng…");

  // 3) Mở picker, chọn bằng chứng từ thư viện (seeded trong stub).
  await page.getByRole("button", { name: /chọn bằng chứng/i }).click();
  await expect(page.getByText("Cọc ngầm sông Bạch Đằng")).toBeVisible({ timeout: 15_000 });
  await page.getByText("Cọc ngầm sông Bạch Đằng").click();
  // Chip hiển thị sau khi chọn.
  await expect(
    page.getByRole("button", { name: /gỡ cọc ngầm sông bạch đằng/i }),
  ).toBeVisible({ timeout: 10_000 });

  // 4) Mở panel phản hồi, viết feedback COMPLETED.
  await page.getByText("Phản hồi cho học viên").click();
  await page.getByLabel(/khi hoàn thành đúng/i).fill("Bạn đã đọc kỹ tư liệu.");

  // 5) Lưu → reload → kiểm tra persist.
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/đã lưu/i)).toBeVisible({ timeout: 15_000 });
  await page.reload();
  await expect(page.getByText("Giai đoạn (1)")).toBeVisible({ timeout: 20_000 });
  await page.getByRole("button", { name: /đọc tư liệu có nguồn/i }).click();
  await expect(
    page.getByRole("button", { name: /gỡ cọc ngầm sông bạch đằng/i }),
  ).toBeVisible({ timeout: 15_000 });
  await page.getByText("Phản hồi cho học viên").click();
  await expect(page.getByLabel(/khi hoàn thành đúng/i)).toHaveValue("Bạn đã đọc kỹ tư liệu.");
});
