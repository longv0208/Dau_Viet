import { expect, test, type Page } from "@playwright/test";

/**
 * TASK-0017 publish journey against the controlled node:http stub (NOT the
 * real backend): login → publish a DRAFT event → author a lesson → preview
 * (asserts the projection strips answer keys) → validate → publish → verify
 * learner content → republish bumps versionNo.
 */

async function login(page: Page) {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
}

async function createDraftEvent(page: Page, title: string, slug: string) {
  await page.goto("/events/new");
  await page.getByLabel(/tiêu đề/i).fill(title);
  await page.getByLabel(/slug/i).fill(slug);
  await page.getByLabel(/tóm tắt/i).fill("Sự kiện e2e cho publish journey");
  await page.getByRole("button", { name: /tạo sự kiện/i }).click();
  await expect(page).toHaveURL(/\/events\/[0-9a-f-]{36}$/, { timeout: 30_000 });
  return page.url().substring(page.url().lastIndexOf("/") + 1);
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
  return page.url().substring(page.url().lastIndexOf("/") + 1);
}

/**
 * Author a publishable draft: one CONTEXT stage (mặc định bắt buộc) với một
 * READ activity được tick "Bắt buộc hoàn thành" — stub chỉ coi lesson đủ điều
 * kiện khi mọi required stage có ≥1 required activity.
 */
async function authorRequiredActivity(page: Page, lessonId: string) {
  await page.goto(`/lessons/${lessonId}/builder`, { timeout: 60_000 });
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 30_000 });
  await page.getByRole("button", { name: /thêm giai đoạn/i }).click();
  await expect(page.getByText("Giai đoạn (1)")).toBeVisible();
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  await page.getByRole("button", { name: /đọc tư liệu/i }).click();
  // Pick activity → editor tự mở (selectedActivityId = activity mới).
  await page.getByLabel(/hướng dẫn cho học viên/i).fill("Đọc tư liệu nền");
  await page.getByLabel(/nội dung đọc/i).fill("Năm 938, Ngô Quyền cho đóng cọc ngầm…");
  // Tick "Bắt buộc hoàn thành" — checkbox nằm trong label wrap của activity
  // editor (không phải checkbox của stage "Bắt buộc hoàn thành" ở metadata).
  await page
    .locator("label", { hasText: /^Bắt buộc hoàn thành$/ })
    .locator('input[type="checkbox"]')
    .check();
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  // Chip trạng thái "Đã lưu HH:mm" — tránh match "bản đã lưu" trong link/banner.
  await expect(page.getByText(/^đã lưu \d/i)).toBeVisible({ timeout: 15_000 });
}

test("publish journey: event publish → lesson preview → validate → publish → verify → republish", async ({
  page,
}) => {
  test.setTimeout(240_000);
  await login(page);

  // 1) Event publish — event mới tạo ở trạng thái DRAFT phải publish được.
  await createDraftEvent(page, "Hải chiến Bạch Đằng e2e", "bach-dang-e2e");
  await page.getByRole("button", { name: /xuất bản sự kiện/i }).click();
  await expect(page.getByText(/xuất bản sự kiện này\?/i)).toBeVisible();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  // Nút publish biến mất khi event đã PUBLISHED (chip render lại).
  await expect(page.getByRole("button", { name: /xuất bản sự kiện/i })).toHaveCount(0, {
    timeout: 15_000,
  });

  // 2) Lesson authoring trên event Bạch Đằng (đã PUBLISHED sẵn trong stub seed).
  const lessonId = await createLesson(page, "E2E — publish journey");
  await authorRequiredActivity(page, lessonId);

  // 3) Preview — stage chip + READ content hiển thị; không lộ answer keys.
  await page.goto(`/lessons/${lessonId}/preview`);
  await expect(page.getByText(/chế độ xem trước/i)).toBeVisible({ timeout: 30_000 });
  await expect(page.getByText(/đọc tư liệu nền/i)).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText(/đóng cọc ngầm/i)).toBeVisible();
  await expect(page.getByText(/correctOptionIds|expectedOrder/)).toHaveCount(0);

  // 4) Publish — validate → publish → versionNo 1.
  await page.goto(`/lessons/${lessonId}/publish`);
  await page.getByRole("button", { name: /kiểm tra xuất bản/i }).click();
  await expect(page.getByText(/đủ điều kiện xuất bản/i)).toBeVisible({ timeout: 15_000 });
  await page.getByRole("button", { name: /xuất bản bài học/i }).click();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  await expect(page.getByText(/đã xuất bản phiên bản 1 thành công/i)).toBeVisible({
    timeout: 15_000,
  });

  // 5) Verify learner content — versionNo 1 reachable via learner endpoint.
  await page.getByRole("button", { name: /kiểm tra nội dung learner/i }).click();
  await expect(page.getByText(/phiên bản 1 đang phát hành/i)).toBeVisible({ timeout: 15_000 });

  // 6) Republish — sửa draft → publish lại → versionNo 2.
  await page.goto(`/lessons/${lessonId}/builder`);
  await expect(
    page.getByText(/trạng thái ĐÃ XUẤT BẢN\. Thay đổi lưu vào bản nháp mới/i),
  ).toBeVisible({ timeout: 20_000 });
  // Bấm activity trong danh sách để mở lại editor (label = instruction đã nhập).
  await page.getByRole("button", { name: /đọc tư liệu nền/i }).click();
  await page.getByLabel(/nội dung đọc/i).fill("Phiên bản mới: trận sông Bạch Đằng 938…");
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/^đã lưu \d/i)).toBeVisible({ timeout: 15_000 });

  await page.goto(`/lessons/${lessonId}/publish`);
  await page.getByRole("button", { name: /xuất bản phiên bản mới/i }).click();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  await expect(page.getByText(/đã xuất bản phiên bản 2 thành công/i)).toBeVisible({
    timeout: 15_000,
  });
});

test("publish blocked when parent event is still DRAFT", async ({ page }) => {
  test.setTimeout(240_000);
  await login(page);

  // Event mới ở DRAFT — KHÔNG publish. Lesson tạo qua wizard gắn eventId theo
  // event chọn ở bước 1, nên chọn đúng event nháp để publish bị chặn.
  await createDraftEvent(page, "Sự kiện nháp e2e", "draft-event-e2e");
  await page.goto("/lessons/new");
  await page.getByRole("button", { name: /sự kiện nháp e2e/i }).click({ timeout: 20_000 });
  await page.getByRole("button", { name: /tiếp tục/i }).click();
  await page.getByRole("button", { name: /điều tra sự kiện/i }).click();
  await page.getByRole("button", { name: /tiếp tục/i }).click();
  await page.getByLabel(/tiêu đề bài học/i).fill("E2E — event nháp chặn publish");
  await page.getByLabel(/câu hỏi trung tâm/i).fill("Câu hỏi trung tâm?");
  await page.getByPlaceholder("Mục tiêu 1").fill("Mục tiêu");
  await page.getByRole("button", { name: /tiếp tục/i }).click();
  await page.getByRole("button", { name: /lưu bản nháp/i }).click();
  await expect(page).toHaveURL(/\/lessons\/[0-9a-f-]{36}$/, { timeout: 45_000 });
  const url = page.url();
  const lessonId = url.substring(url.lastIndexOf("/") + 1);

  await authorRequiredActivity(page, lessonId);

  // Validate báo EVENT_NOT_PUBLISHED; publish trả 422 → VN message + link event.
  await page.goto(`/lessons/${lessonId}/publish`);
  await page.getByRole("button", { name: /kiểm tra xuất bản/i }).click();
  await expect(page.getByText(/EVENT_NOT_PUBLISHED/).first()).toBeVisible({ timeout: 15_000 });

  await page.getByRole("button", { name: /xuất bản bài học/i }).click();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  await expect(
    page.getByText(/sự kiện lịch sử chưa được xuất bản/i).first(),
  ).toBeVisible({ timeout: 15_000 });
  await expect(
    page.getByRole("link", { name: /đi tới trang sự kiện để xuất bản/i }),
  ).toBeVisible();
});
