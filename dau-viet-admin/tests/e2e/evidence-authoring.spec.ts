import { expect, test, type Page } from "@playwright/test";

/**
 * TASK-0016 journey against the controlled node:http stub (NOT the real
 * backend): login → create evidence → confirm it lands in the library →
 * attach the CREATED evidence to a READ activity → feedback → save → reload
 * → confirm persisted. Also exercises authenticated image rendering: the
 * stub returns 401 for asset content without a Bearer token, so a visible
 * thumbnail proves the fetch carried auth.
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

test("evidence: create → appears in library → attach created item to READ → feedback → save → reload", async ({
  page,
}) => {
  test.setTimeout(180_000); // first dev-compile of new routes can be slow
  const evTitle = "Ghi chép triều đình về lực lượng Nam Hán";
  await login(page);

  // 1) Tạo bằng chứng mới trong thư viện.
  await page.goto("/evidence/new");
  await page.locator("#eventId").selectOption({ index: 1 });
  await page.locator("#title").fill(evTitle);
  await page.locator("#evidenceType").selectOption("GHI_CHEP");
  await page.locator("#sourceTitle").fill("An Nam chí lược");
  await page.getByRole("button", { name: /tạo bằng chứng/i }).click();
  await expect(page.getByRole("button", { name: /tạo bằng chứng/i })).toBeEnabled({ timeout: 15_000 });

  // 2) Bằng chứng vừa tạo phải xuất hiện trong danh sách thư viện.
  await page.goto("/evidence");
  await expect(page.getByText(evTitle)).toBeVisible({ timeout: 15_000 });

  // 3) Mở builder, thêm READ, mở picker — bằng chứng MỚI TẠO phải chọn được.
  const lessonId = await createLesson(page, "E2E — gắn bằng chứng");
  await page.goto(`/lessons/${lessonId}/builder`, { timeout: 60_000 });
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 30_000 });

  await page.getByRole("button", { name: /thêm giai đoạn/i }).click();
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  await page.getByRole("button", { name: /đọc tư liệu/i }).click();
  await page.getByLabel(/hướng dẫn cho học viên/i).fill("Đọc tư liệu có nguồn");
  await page.getByLabel(/nội dung đọc/i).fill("Đoạn tư liệu trích từ thư viện bằng chứng…");

  // Picker mở — lọc "Tất cả sự kiện" (bằng chứng tạo ở sự kiện Bạch Đằng,
  // lesson thuộc cùng event nên cũng thấy khi lọc mặc định).
  await page.getByRole("button", { name: /chọn bằng chứng/i }).click();
  await expect(page.getByText(evTitle)).toBeVisible({ timeout: 15_000 });
  await page.getByText(evTitle).click();
  await expect(
    page.getByRole("button", { name: new RegExp(`gỡ ${evTitle.slice(0, 20)}`, "i") }),
  ).toBeVisible({ timeout: 10_000 });

  // 4) Feedback COMPLETED.
  await page.getByText("Phản hồi cho học viên").click();
  await page.getByLabel(/khi hoàn thành đúng/i).fill("Bạn đã đọc kỹ tư liệu.");

  // 5) Lưu → reload → evidence chip + feedback vẫn còn.
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/^đã lưu \d/i)).toBeVisible({ timeout: 15_000 });
  await page.reload();
  await expect(page.getByText("Giai đoạn (1)")).toBeVisible({ timeout: 20_000 });
  await page.getByRole("button", { name: /đọc tư liệu có nguồn/i }).click();
  await expect(
    page.getByRole("button", { name: new RegExp(`gỡ ${evTitle.slice(0, 20)}`, "i") }),
  ).toBeVisible({ timeout: 15_000 });
  await page.getByText("Phản hồi cho học viên").click();
  await expect(page.getByLabel(/khi hoàn thành đúng/i)).toHaveValue("Bạn đã đọc kỹ tư liệu.");
});

test("assets: seeded thumbnail renders via authenticated blob fetch", async ({ page }) => {
  test.setTimeout(120_000);
  await login(page);
  await page.goto("/assets");
  await expect(page.getByText(/thư viện media|chưa có ảnh|ảnh/i).first()).toBeVisible({ timeout: 30_000 });

  // Stub seeds one ACTIVE asset; its <img> must render — stub returns 401
  // without Bearer, so a real <img> (not the error fallback) proves auth.
  const img = page.locator("img[alt*='Bản đồ'], img[alt*='ban-do']").first();
  await expect(img).toBeVisible({ timeout: 20_000 });
  // Assert it's a blob: object URL — the authenticated-fetch mechanism.
  await expect(img).toHaveAttribute("src", /^blob:/);
});

test("media: upload PNG → preview decodes → attach to VIEW_IMAGE → save → reload persists", async ({
  page,
}) => {
  test.setTimeout(180_000);
  await login(page);

  // 3–4) Upload ảnh PNG hợp lệ qua /assets — phải thành công và preview mở.
  await page.goto("/assets");
  await expect(page.getByText(/thư viện media|chưa có ảnh/i).first()).toBeVisible({
    timeout: 30_000,
  });
  // Real 1x1 PNG bytes — verified decodable (same fixture the stub seeds).
  const png1x1 = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
    "base64",
  );
  const fileName = "e2e-upload-bach-dang.png";
  await page.locator("input[type=file]").setInputFiles({
    name: fileName,
    mimeType: "image/png",
    buffer: png1x1,
  });

  // Library tự mở preview asset vừa upload (post-upload UX fix).
  const previewDialog = page.getByRole("dialog");
  await expect(previewDialog).toBeVisible({ timeout: 15_000 });
  await expect(previewDialog.getByText(fileName)).toBeVisible();

  // 7) Ảnh trong preview phải decode thật — blob: URL + naturalWidth > 0.
  const previewImg = previewDialog.locator("img").first();
  await expect(previewImg).toHaveAttribute("src", /^blob:/, { timeout: 15_000 });
  await previewImg.waitFor({ state: "visible", timeout: 15_000 });
  // Wait for the blob to actually decode before asserting naturalWidth.
  await expect
    .poll(
      async () =>
        previewImg.evaluate(
          (el: HTMLImageElement) => el.complete && el.naturalWidth > 0,
        ),
      { timeout: 15_000 },
    )
    .toBe(true);
  await previewDialog.getByRole("button", { name: "Đóng", exact: true }).last().click();

  // 5) Asset vừa upload xuất hiện trong lưới thư viện (trang đầu).
  await expect(page.getByText(fileName)).toBeVisible({ timeout: 15_000 });

  // 8–9) Builder → thêm VIEW_IMAGE activity → gắn ảnh vừa upload.
  const lessonId = await createLesson(page, "E2E — gắn ảnh VIEW_IMAGE");
  await page.goto(`/lessons/${lessonId}/builder`, { timeout: 60_000 });
  await expect(page.getByText("Giai đoạn (0)")).toBeVisible({ timeout: 30_000 });

  await page.getByRole("button", { name: /thêm giai đoạn/i }).click();
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  await page.getByRole("button", { name: /quan sát hình ảnh/i }).click();
  await page.getByLabel(/hướng dẫn cho học viên/i).fill("Quan sát bản đồ vừa tải lên");

  // Picker → chọn asset đã upload (auto-close) → editor hiển thị preview.
  await page.getByRole("button", { name: /chọn ảnh từ thư viện/i }).click();
  const picker = page.getByRole("dialog");
  await expect(picker.getByText(fileName)).toBeVisible({ timeout: 15_000 });
  await picker.getByText(fileName).click();

  // Editor hiển thị preview asset đã chọn.
  await expect(page.getByText(fileName)).toBeVisible({ timeout: 15_000 });
  const chipImg = page.locator("img[src^='blob:']").first();
  await expect(chipImg).toBeVisible({ timeout: 15_000 });
  await expect
    .poll(
      async () =>
        chipImg.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0),
      { timeout: 15_000 },
    )
    .toBe(true);

  // 10–12) Save → reload → asset ref + preview vẫn nguyên.
  await page.getByRole("button", { name: /lưu nháp/i }).click();
  await expect(page.getByText(/^đã lưu \d/i)).toBeVisible({ timeout: 15_000 });
  await page.reload();
  await expect(page.getByText("Giai đoạn (1)")).toBeVisible({ timeout: 20_000 });
  // Mở lại activity editor — click vào instruction của VIEW_IMAGE.
  await page.getByRole("button", { name: /quan sát bản đồ vừa tải lên/i }).click();
  await expect(page.getByText(fileName)).toBeVisible({ timeout: 15_000 });
  const persistedImg = page.locator("img[src^='blob:']").first();
  await expect(persistedImg).toBeVisible({ timeout: 15_000 });
  await expect
    .poll(
      async () =>
        persistedImg.evaluate(
          (el: HTMLImageElement) => el.complete && el.naturalWidth > 0,
        ),
      { timeout: 15_000 },
    )
    .toBe(true);
});
