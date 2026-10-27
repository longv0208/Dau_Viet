import zlib from "node:zlib";
import { expect, test, type Page } from "@playwright/test";

/**
 * Multi-phase E2E test suite for Lesson Creation, Auto-generated 16:9 Cover &
 * Activity Image Upload, and Authoring all 9 StageTypes + all 13 ActivityTypes
 * in `dau-viet-admin`.
 */

/* -------------------------------------------------------------------------- */
/* Helper: Programmatic 16:9 PNG Generator (valid IHDR + zlib IDAT + IEND)    */
/* -------------------------------------------------------------------------- */

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf: Buffer): number {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]!) & 0xff]! ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type: string, data: Buffer): Buffer {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, "ascii");
  const crcInput = Buffer.concat([typeBuf, data]);
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(crcInput), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

/**
 * Generates a valid, browser-decodable 16:9 RGB PNG image buffer (default 320x180).
 */
function createSolidPng16x9(
  r: number,
  g: number,
  b: number,
  width = 320,
  height = 180,
): Buffer {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth 8
  ihdr[9] = 2; // color type 2 (Truecolor RGB)
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  // Each scanline starts with filter byte 0 followed by RGB triples
  const stride = 1 + width * 3;
  const raw = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const rowStart = y * stride;
    raw[rowStart] = 0; // filter type None
    for (let x = 0; x < width; x++) {
      const px = rowStart + 1 + x * 3;
      // Add subtle gradient band so each generated image has rich pixel data
      raw[px] = (r + Math.floor((x / width) * 30)) & 0xff;
      raw[px + 1] = (g + Math.floor((y / height) * 30)) & 0xff;
      raw[px + 2] = b & 0xff;
    }
  }

  const compressed = zlib.deflateSync(raw);
  return Buffer.concat([
    signature,
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", compressed),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
}

/* -------------------------------------------------------------------------- */
/* Common UI Helpers                                                          */
/* -------------------------------------------------------------------------- */

async function login(page: Page) {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
}

async function addStage(page: Page, type: string, title: string, required = true) {
  await page.getByLabel("Loại giai đoạn mới").selectOption(type);
  await page.getByRole("button", { name: "Thêm giai đoạn" }).click();
  await page.locator("#stage-title").fill(title);
  const reqCheckbox = page
    .locator("main label")
    .filter({ hasText: /Bắt buộc|Tuỳ chọn/ })
    .locator("input[type='checkbox']")
    .first();
  const isChecked = await reqCheckbox.isChecked();
  if (isChecked !== required) {
    await reqCheckbox.click();
  }
}

async function pickActivity(page: Page, labelTitle: string) {
  await page.getByRole("button", { name: /thêm hoạt động/i }).click();
  // Click the activity card button matching exact title in ActivityPicker
  const pickerBtn = page
    .locator("main button")
    .filter({ has: page.locator("span.font-medium", { hasText: new RegExp(`^${escapeRegExp(labelTitle)}$`) }) })
    .first();
  await pickerBtn.click();
}

function escapeRegExp(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function fillRequiredFeedback(
  page: Page,
  completedText = "Chính xác! Bạn đã nắm vững kiến thức lịch sử.",
  incorrectText = "Chưa chính xác, hãy đối chiếu lại tư liệu lịch sử.",
) {
  const details = page.locator("main details").filter({ hasText: "Phản hồi cho học viên" });
  const isOpen = await details.evaluate((el: HTMLDetailsElement) => el.open);
  if (!isOpen) {
    await details.locator("summary").click();
  }
  await details.getByLabel("Khi hoàn thành đúng").fill(completedText);
  await details.getByLabel("Khi trả lời chưa đúng").fill(incorrectText);
}

async function pickFirstEvidenceInSection(page: Page, sectionLabel: string) {
  const section = page
    .locator("main div.flex.flex-col")
    .filter({ has: page.locator("label", { hasText: sectionLabel }) })
    .last();
  await section.getByRole("button", { name: /chọn bằng chứng/i }).first().click();
  await section.getByText("Cọc ngầm sông Bạch Đằng").first().click();
  // Đóng panel chọn bằng chứng inline để tránh trùng lặp với section tiếp theo
  await section.getByRole("button", { name: /chọn bằng chứng/i }).first().click();
}

/* -------------------------------------------------------------------------- */
/* Test Suite: 7 Phases                                                       */
/* -------------------------------------------------------------------------- */

test.describe("Multi-phase Lesson Creation, 16:9 Cover Image & All 9 Stages / 13 Activity Types", () => {
  test("Phase 1 & Phase 2: Wizard 4 bước (kèm validation) + Tự sinh & Quản lý Ảnh bìa 16:9 (Chọn, Thay, Gỡ, Negative, Lưu)", async ({
    page,
  }) => {
    test.setTimeout(180_000);
    await login(page);

    /* ====================================================================== */
    /* PHASE 1: WIZARD TẠO BÀI HỌC 4 BƯỚC & KIỂM TRA VALIDATION (/lessons/new) */
    /* ====================================================================== */
    await page.goto("/lessons/new");

    // Bước 1 — Chọn sự kiện lịch sử
    const nextBtn = page.getByRole("button", { name: /tiếp tục/i });
    await expect(nextBtn).toBeDisabled();
    await page.getByRole("button", { name: /trận bạch đằng 938/i }).click({ timeout: 20_000 });
    await expect(nextBtn).toBeEnabled();
    await nextBtn.click();

    // Bước 2 — Chọn khung bài học
    await expect(nextBtn).toBeDisabled();
    await page.getByRole("button", { name: /điều tra sự kiện/i }).click();
    await expect(
      page.getByText(/Khung stage chuẩn cho bài điều tra sự kiện lịch sử/i),
    ).toBeVisible();
    await expect(nextBtn).toBeEnabled();
    await nextBtn.click();

    // Bước 3 — Thông tin cơ bản & Validation
    // Submit rỗng -> báo lỗi Tiêu đề, Câu hỏi trung tâm & Mục tiêu
    await page.getByRole("button", { name: /tiếp tục/i }).click();
    await expect(page.getByText("Vui lòng nhập tiêu đề bài học")).toBeVisible();
    await expect(page.getByText("Vui lòng nhập câu hỏi trung tâm")).toBeVisible();
    await expect(page.getByText("Không để trống mục tiêu")).toBeVisible();

    // Điền Tiêu đề & Câu hỏi trung tâm nhưng để trống Mục tiêu -> vẫn giữ lỗi mục tiêu
    await page.getByLabel(/tiêu đề bài học/i).fill("Chiến thắng Bạch Đằng năm 938 — Toàn diện");
    await page
      .getByLabel(/câu hỏi trung tâm/i)
      .fill("Vì sao Ngô Quyền đánh tan quân Nam Hán chỉ trong một con nước thủy triều?");
    await page.getByRole("button", { name: /tiếp tục/i }).click();
    await expect(page.getByText("Không để trống mục tiêu")).toBeVisible();

    // Thêm 3 mục tiêu, xoá mục tiêu thứ 3, giữ lại 2 mục tiêu
    await page.getByPlaceholder("Mục tiêu 1").fill("Phân tích địa thế hiểm yếu của cửa sông Bạch Đằng");
    await page.getByRole("button", { name: /\+ thêm mục tiêu/i }).click();
    await page.getByPlaceholder("Mục tiêu 2").fill("Đánh giá nghệ thuật quân sự lợi dụng thủy triều và bãi cọc");
    await page.getByRole("button", { name: /\+ thêm mục tiêu/i }).click();
    await page.getByPlaceholder("Mục tiêu 3").fill("Mục tiêu tạm để kiểm tra nút xoá");
    await page.getByRole("button", { name: "Xoá" }).last().click();
    await expect(page.getByPlaceholder("Mục tiêu 3")).toHaveCount(0);

    await page.getByRole("button", { name: /tiếp tục/i }).click();

    // Bước 4 — Xác nhận & lưu bản nháp
    await expect(page.getByText("Trận Bạch Đằng 938")).toBeVisible();
    await expect(page.getByText("Điều tra sự kiện")).toBeVisible();
    await expect(page.getByText("Chiến thắng Bạch Đằng năm 938 — Toàn diện")).toBeVisible();
    await expect(
      page.getByText("Phân tích địa thế hiểm yếu của cửa sông Bạch Đằng"),
    ).toBeVisible();
    await expect(
      page.getByText("Đánh giá nghệ thuật quân sự lợi dụng thủy triều và bãi cọc"),
    ).toBeVisible();

    await page.getByRole("button", { name: /lưu bản nháp/i }).click();
    await expect(page).toHaveURL(/\/lessons\/[0-9a-f-]{36}$/, { timeout: 30_000 });

    /* ====================================================================== */
    /* PHASE 2: TỰ SINH ẢNH 16:9 & QUẢN LÝ ẢNH BÌA BÀI HỌC (/lessons/[id])     */
    /* ====================================================================== */
    const pngCover1 = createSolidPng16x9(24, 90, 155, 320, 180); // Xanh lam Bạch Đằng 16:9
    const pngCover2 = createSolidPng16x9(180, 130, 35, 320, 180); // Vàng Hoàng Thành 16:9
    const coverFile1 = "cover-bach-dang-16x9.png";
    const coverFile2 = "cover-thang-long-16x9.png";

    // 2.1 Trạng thái ban đầu chưa có ảnh bìa
    await expect(page.getByText("Chưa có ảnh bìa bài học")).toBeVisible({ timeout: 20_000 });
    await expect(page.getByRole("button", { name: "Chọn ảnh", exact: true })).toBeVisible();

    // 2.2 Upload ảnh bìa 16:9 lần đầu qua AssetPickerDialog
    await page.getByRole("button", { name: "Chọn ảnh", exact: true }).click();
    const pickerDialog = page.getByRole("dialog");
    await expect(pickerDialog).toBeVisible();

    await pickerDialog.locator("input[type='file']").setInputFiles({
      name: coverFile1,
      mimeType: "image/png",
      buffer: pngCover1,
    });

    // Tự động chọn ảnh vừa upload, đóng dialog và lưu coverAssetId
    await expect(pickerDialog).toBeHidden({ timeout: 15_000 });
    await expect(page.getByText("Đã cập nhật ảnh bìa bài học.")).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText(coverFile1)).toBeVisible();

    // Kiểm tra ảnh 16:9 decode thật qua cơ chế xác thực Bearer (blob: URL, 320x180)
    const coverImg = page.locator("img[src^='blob:']").first();
    await expect(coverImg).toBeVisible({ timeout: 15_000 });
    await expect
      .poll(
        async () =>
          coverImg.evaluate(
            (el: HTMLImageElement) =>
              el.complete && el.naturalWidth === 320 && el.naturalHeight === 180,
          ),
        { timeout: 15_000 },
      )
      .toBe(true);

    // Nút đã chuyển thành "Thay ảnh" và "Gỡ ảnh"
    await expect(page.getByRole("button", { name: "Thay ảnh", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Gỡ ảnh", exact: true })).toBeVisible();

    // 2.3 Thay ảnh bìa bằng ảnh 16:9 thứ 2
    await page.getByRole("button", { name: "Thay ảnh", exact: true }).click();
    await expect(pickerDialog).toBeVisible();
    await pickerDialog.locator("input[type='file']").setInputFiles({
      name: coverFile2,
      mimeType: "image/png",
      buffer: pngCover2,
    });
    await expect(pickerDialog).toBeHidden({ timeout: 15_000 });
    await expect(page.getByText(coverFile2)).toBeVisible({ timeout: 15_000 });

    // Reload kiểm tra bền vững
    await page.reload();
    await expect(page.getByText(coverFile2)).toBeVisible({ timeout: 20_000 });

    // 2.4 Gỡ ảnh bìa -> về trạng thái trống nhưng asset vẫn còn trong thư viện
    await page.getByRole("button", { name: "Gỡ ảnh", exact: true }).click();
    await expect(page.getByText("Đã cập nhật ảnh bìa bài học.")).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText("Chưa có ảnh bìa bài học")).toBeVisible();

    // Mở lại picker: cả 2 ảnh vừa upload vẫn còn nguyên trong thư viện Media
    await page.getByRole("button", { name: "Chọn ảnh", exact: true }).click();
    await expect(pickerDialog).toBeVisible();
    await expect(pickerDialog.getByText(coverFile1)).toBeVisible();
    await expect(pickerDialog.getByText(coverFile2)).toBeVisible();

    // 2.5 Negative test: thử tải lên file .txt không hợp lệ
    await pickerDialog.locator("input[type='file']").setInputFiles({
      name: "invalid-format.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("not an image"),
    });
    await expect(
      pickerDialog.getByRole("alert").filter({ hasText: /Định dạng không hỗ trợ/i }),
    ).toBeVisible();

    // Chọn lại coverFile1 từ thư viện làm ảnh bìa chính thức
    await pickerDialog.getByText(coverFile1).click();
    await expect(pickerDialog).toBeHidden({ timeout: 15_000 });
    await expect(page.getByText(coverFile1)).toBeVisible();
    await expect(page.getByRole("button", { name: "Thay ảnh", exact: true })).toBeEnabled({
      timeout: 15_000,
    });

    // 2.6 Sửa thông tin cơ bản và bấm "Lưu thay đổi" -> không mất ảnh bìa
    await page
      .getByLabel(/tiêu đề \*/i)
      .fill("Chiến thắng Bạch Đằng năm 938 — Bản đầy đủ 9 giai đoạn");
    await page.getByRole("button", { name: /lưu thay đổi/i }).click();
    await expect(page.getByText("Đã lưu thay đổi.")).toBeVisible({ timeout: 15_000 });

    await page.reload();
    await expect(page.getByLabel(/tiêu đề \*/i)).toHaveValue(
      "Chiến thắng Bạch Đằng năm 938 — Bản đầy đủ 9 giai đoạn",
      { timeout: 20_000 },
    );
    await expect(page.getByText(coverFile1)).toBeVisible();
  });

  test("Phase 3, 4, 5, 6 & 7: Builder soạn đủ 9 StageTypes + 13 ActivityTypes, Upload ảnh VIEW_IMAGE, Local/Server Validate, Preview, Publish v1->v2 & Archive", async ({
    page,
  }) => {
    test.setTimeout(300_000);
    await login(page);

    // Tạo bài học mới trên sự kiện "Trận Bạch Đằng 938" (đã PUBLISHED)
    await page.goto("/lessons/new");
    await page.getByRole("button", { name: /trận bạch đằng 938/i }).click({ timeout: 20_000 });
    await page.getByRole("button", { name: /tiếp tục/i }).click();
    await page.getByRole("button", { name: /điều tra sự kiện/i }).click();
    await page.getByRole("button", { name: /tiếp tục/i }).click();
    await page.getByLabel(/tiêu đề bài học/i).fill("Bài học E2E — Đủ 9 Giai đoạn & 13 Hoạt động");
    await page.getByLabel(/câu hỏi trung tâm/i).fill("Làm thế nào để kiểm chứng lịch sử đa chiều?");
    await page.getByPlaceholder("Mục tiêu 1").fill("Thực hành trọn vẹn 13 loại hoạt động học tập");
    await page.getByRole("button", { name: /tiếp tục/i }).click();
    await page.getByRole("button", { name: /lưu bản nháp/i }).click();
    await expect(page).toHaveURL(/\/lessons\/[0-9a-f-]{36}$/, { timeout: 30_000 });
    const lessonId = page.url().substring(page.url().lastIndexOf("/") + 1);

    // Gắn ảnh bìa 16:9 cho bài học trước khi vào Builder
    const pngCover1 = createSolidPng16x9(30, 110, 160, 320, 180);
    const pngCover2 = createSolidPng16x9(190, 95, 40, 320, 180);
    const pngActivityImg = createSolidPng16x9(140, 45, 55, 320, 180);

    await page.getByRole("button", { name: "Chọn ảnh", exact: true }).click();
    await page.getByRole("dialog").locator("input[type='file']").setInputFiles({
      name: "cover-9stages-v1.png",
      mimeType: "image/png",
      buffer: pngCover1,
    });
    await expect(page.getByText("Đã cập nhật ảnh bìa bài học.")).toBeVisible({ timeout: 15_000 });

    /* ====================================================================== */
    /* PHASE 3: BUILDER — NHÓM TIẾP CẬN & BẰNG CHỨNG (CONTEXT, DISCOVERY, EVIDENCE) */
    /* ====================================================================== */
    await page.goto(`/lessons/${lessonId}/builder`, { timeout: 60_000 });
    await expect(page.getByText("Giai đoạn (2)")).toBeVisible({ timeout: 30_000 });

    // Xoá 2 giai đoạn mẫu từ presetJson để kiểm thử tính năng Xoá Stage và xây dựng mới đủ 9 Stage
    await page.getByRole("button", { name: "Xoá Bối cảnh (mẫu)" }).click();
    await page.getByRole("button", { name: "Xoá", exact: true }).click();
    await page.getByRole("button", { name: "Xoá Bằng chứng (mẫu)" }).click();
    await page.getByRole("button", { name: "Xoá", exact: true }).click();
    await expect(page.getByText("Giai đoạn (0)")).toBeVisible();

    // --- STAGE 1: CONTEXT (READ + VIEW_IMAGE) ---
    await addStage(page, "CONTEXT", "1. Bối cảnh sông Bạch Đằng", true);

    // Activity 1/13: READ (Đọc tư liệu + gắn nguồn bằng chứng)
    await pickActivity(page, "Đọc tư liệu");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Đọc tư liệu bối cảnh năm 938");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    await page
      .getByLabel("Nội dung đọc")
      .fill("Mùa đông năm 938, quân Nam Hán do Lưu Hoằng Tháo chỉ huy tiến vào cửa biển Bạch Đằng.");
    await pickFirstEvidenceInSection(page, "Nguồn tư liệu (bằng chứng lịch sử)");

    // Activity 2/13: VIEW_IMAGE (Quan sát hình ảnh + tự sinh & upload ảnh mới)
    await pickActivity(page, "Quan sát hình ảnh");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Quan sát sơ đồ trận địa cọc");
    await expect(page.getByText("Cần chọn hình ảnh để lưu hợp lệ.")).toBeVisible();
    await page.getByRole("button", { name: "Chọn ảnh từ thư viện" }).click();
    const actPicker = page.getByRole("dialog");
    await expect(actPicker).toBeVisible();
    await actPicker.locator("input[type='file']").setInputFiles({
      name: "so-do-coc-bach-dang-16x9.png",
      mimeType: "image/png",
      buffer: pngActivityImg,
    });
    await expect(actPicker).toBeHidden({ timeout: 15_000 });
    await expect(page.getByText("so-do-coc-bach-dang-16x9.png")).toBeVisible();
    await page.getByLabel("Chú thích hình").fill("Sơ đồ bố trí bãi cọc gỗ lim tại cửa sông Bạch Đằng");

    // --- STAGE 2: DISCOVERY (EXPLORE_MAP — UnsupportedEditor fallback) ---
    await addStage(page, "DISCOVERY", "2. Khám phá địa hình cửa biển", false);

    // Activity 3/13: EXPLORE_MAP (Khám phá bản đồ)
    await pickActivity(page, "Khám phá bản đồ");
    await expect(
      page.getByText(/Loại hoạt động Khám phá bản đồ chưa hỗ trợ chỉnh sửa trực quan/i),
    ).toBeVisible();
    await page.getByLabel("Hướng dẫn cho học viên").fill("Khám phá các nhánh sông Bạch Đằng");

    // --- STAGE 3: EVIDENCE (EVIDENCE_SELECT graded + MULTIPLE_CHOICE single) ---
    await addStage(page, "EVIDENCE", "3. Thu thập bằng chứng lịch sử", true);

    // Activity 4/13: EVIDENCE_SELECT (Chọn bằng chứng — chế độ graded:true)
    await pickActivity(page, "Chọn bằng chứng");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Chọn bằng chứng xác thực về bãi cọc");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    await pickFirstEvidenceInSection(page, "Bằng chứng học viên được xem");
    await page.getByLabel("Chấm điểm theo đáp án (graded)").check();
    await pickFirstEvidenceInSection(page, "Bằng chứng đúng (đáp án) *");
    await page.getByLabel("Số lần thử tối đa (có chấm)").fill("2");
    await page.getByLabel("Lượt sửa bài bổ sung (remedial)").fill("1");
    await page.getByLabel("Số bằng chứng tối thiểu phải chọn").fill("1");
    await fillRequiredFeedback(page);

    // Activity 5/13: MULTIPLE_CHOICE (Trắc nghiệm — Một đáp án)
    await pickActivity(page, "Trắc nghiệm");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Trả lời câu hỏi trắc nghiệm 1 đáp án");
    await page.getByLabel("Câu hỏi *").fill("Ai là người lãnh đạo quân dân ta trong trận Bạch Đằng năm 938?");
    await page.getByRole("button", { name: /thêm đáp án/i }).click();
    await page.getByRole("button", { name: /thêm đáp án/i }).click();
    await page.getByPlaceholder("Đáp án 1").fill("Ngô Quyền");
    await page.getByPlaceholder("Đáp án 2").fill("Lê Hoàn");
    await page.getByLabel("Đáp án đúng 1").check();
    await fillRequiredFeedback(page);

    /* ====================================================================== */
    /* PHASE 4: BUILDER — NHÓM SUY LUẬN, GIẢ THUYẾT & TÁI DỰNG (Stages 4–6)   */
    /* ====================================================================== */

    // --- STAGE 4: REASONING (MATCHING + REASONING_CONNECT + MULTIPLE_CHOICE multi) ---
    await addStage(page, "REASONING", "4. Phân tích & Suy luận chiến thuật", true);

    // Activity 6/13: MATCHING (Ghép cặp)
    await pickActivity(page, "Ghép cặp");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Nối nhân vật và sự vật với vai trò tương ứng");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    await page.getByRole("button", { name: /thêm cặp/i }).click();
    await page.getByRole("button", { name: /thêm cặp/i }).click();
    await page.getByPlaceholder("Vế trái 1").fill("Ngô Quyền");
    await page.getByPlaceholder("Vế phải 1").fill("Chủ soái quân Việt");
    await page.getByPlaceholder("Vế trái 2").fill("Lưu Hoằng Tháo");
    await page.getByPlaceholder("Vế phải 2").fill("Tướng tiên phong Nam Hán");
    await fillRequiredFeedback(page);

    // Activity 7/13: REASONING_CONNECT (Kết nối lập luận + graded expectedRelations)
    await pickActivity(page, "Kết nối lập luận");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Nối quan hệ nhân quả trong trận đánh");
    await page.getByRole("button", { name: /thêm khái niệm/i }).click();
    await page.getByRole("button", { name: /thêm khái niệm/i }).click();
    await page.getByLabel("Khái niệm 1", { exact: true }).fill("Thủy triều rút mạnh");
    await page.getByLabel("Khái niệm 2", { exact: true }).fill("Chiến thuyền Nam Hán vỡ đắm");
    await page.locator("main label", { hasText: "nguyên nhân" }).locator("input[type='checkbox']").check();
    await page.locator("main label", { hasText: "kết quả" }).locator("input[type='checkbox']").check();
    await page.getByLabel("Thêm quan hệ tuỳ ý").fill("dan-den");
    await page.getByLabel("Thêm quan hệ tuỳ ý").press("Enter");
    await page.getByLabel("Chấm điểm theo đáp án (graded)").check();
    await page.getByRole("button", { name: /thêm quan hệ đúng/i }).click();
    await fillRequiredFeedback(page);

    // Activity 5b/13: MULTIPLE_CHOICE (Trắc nghiệm — Nhiều đáp án `multi`)
    await pickActivity(page, "Trắc nghiệm");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Chọn tất cả các yếu tố tạo nên chiến thắng");
    await page.getByLabel("Câu hỏi *").fill("Những yếu tố nào góp phần trực tiếp vào chiến thắng Bạch Đằng?");
    await page.getByLabel("Nhiều đáp án").check();
    await page.getByRole("button", { name: /thêm đáp án/i }).click();
    await page.getByRole("button", { name: /thêm đáp án/i }).click();
    await page.getByRole("button", { name: /thêm đáp án/i }).click();
    await page.getByPlaceholder("Đáp án 1").fill("Lợi dụng quy luật thủy triều lên xuống");
    await page.getByPlaceholder("Đáp án 2").fill("Bố trí bãi cọc gỗ lim bịt sắt ngầm");
    await page.getByPlaceholder("Đáp án 3").fill("Viện binh từ phương Bắc tiếp ứng");
    await page.getByLabel("Đáp án đúng 1").check();
    await page.getByLabel("Đáp án đúng 2").check();
    await fillRequiredFeedback(page);

    // --- STAGE 5: HYPOTHESIS (HYPOTHESIS_CHOICE) ---
    await addStage(page, "HYPOTHESIS", "5. Đặt giả thuyết lịch sử", true);

    // Activity 8/13: HYPOTHESIS_CHOICE (Chọn giả thuyết)
    await pickActivity(page, "Chọn giả thuyết");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Đưa ra giả thuyết về mục đích nhử địch");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    await page.getByRole("button", { name: /thêm giả thuyết/i }).click();
    await page.getByRole("button", { name: /thêm giả thuyết/i }).click();
    await page
      .getByLabel("Giả thuyết 1", { exact: true })
      .fill("Ngô Quyền dùng thuyền nhẹ nhử địch vượt qua bãi cọc lúc triều lên");
    await page
      .getByLabel("Giả thuyết 2", { exact: true })
      .fill("Quân Nam Hán tự ý rút quân vì gặp bão lớn ngoài biển");
    await fillRequiredFeedback(page);

    // --- STAGE 6: RECONSTRUCTION (DRAG_ORDER) ---
    await addStage(page, "RECONSTRUCTION", "6. Tái dựng diễn biến trận đánh", true);

    // Activity 9/13: DRAG_ORDER (Sắp xếp diễn biến)
    await pickActivity(page, "Sắp xếp diễn biến");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Sắp xếp 3 mốc diễn biến theo trình tự thời gian");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    await page.getByRole("button", { name: /thêm bước/i }).click();
    await page.getByRole("button", { name: /thêm bước/i }).click();
    await page.getByRole("button", { name: /thêm bước/i }).click();
    await page.getByPlaceholder("Bước 1").fill("Thuyền nhẹ quân Việt ra khiêu chiến rồi giả thua rút chạy");
    await page.getByPlaceholder("Bước 2").fill("Lưu Hoằng Tháo dốc quân đuổi theo vượt qua bãi cọc ngầm");
    await page.getByPlaceholder("Bước 3").fill("Nước triều rút mạnh, quân Việt quay lại phản công quyết liệt");
    // Thử đổi chỗ bước 3 lên rồi chuyển xuống lại để kiểm tra nút điều hướng thứ tự
    await page.getByRole("button", { name: "Chuyển bước 3 lên" }).click();
    await page.getByRole("button", { name: "Chuyển bước 2 xuống" }).click();
    await fillRequiredFeedback(page);

    /* ====================================================================== */
    /* PHASE 5: BUILDER — KIỂM CHỨNG, KẾT LUẬN (CER & CER_CHOICE) & SUY NGẪM   */
    /* ====================================================================== */

    // --- STAGE 7: VERIFICATION (VERIFICATION) ---
    await addStage(page, "VERIFICATION", "7. Kiểm chứng giả thuyết", true);

    // Activity 10/13: VERIFICATION (Kiểm chứng)
    await pickActivity(page, "Kiểm chứng");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Đối chiếu giả thuyết với bằng chứng đã thu thập");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    // Chọn nguồn bằng chứng từ EVIDENCE_SELECT ở Stage 3
    await page.getByLabel("Nguồn bằng chứng đã thu thập").selectOption({ index: 1 });
    await pickFirstEvidenceInSection(page, "Bằng chứng học viên được xem");
    await pickFirstEvidenceInSection(page, "Bằng chứng bắt buộc phải dùng");
    await page.getByLabel("Số lần kiểm chứng tối đa").fill("2");
    await fillRequiredFeedback(page);
    const vfDetails = page.locator("main details").filter({ hasText: "Phản hồi cho học viên" });
    await vfDetails.getByLabel("Khi đúng một phần").fill("Bạn mới đối chiếu được một phần bằng chứng.");
    await vfDetails.getByLabel("Khi giả thuyết được củng cố").fill("Bằng chứng hoàn toàn củng cố giả thuyết!");
    await vfDetails.getByLabel("Khi giả thuyết bị bác bỏ").fill("Tư liệu lịch sử bác bỏ giả thuyết này.");
    await vfDetails.getByLabel("Khi hết lượt thử").fill("Đã hoàn thành lượt học, hãy xem giải thích chi tiết.");

    // --- STAGE 8: CONCLUSION (CER + CER_CHOICE) ---
    await addStage(page, "CONCLUSION", "8. Kết luận lịch sử có dẫn chứng", true);

    // Activity 11/13: CER (Kết luận có dẫn chứng — tự luận theo Rubric)
    await pickActivity(page, "Kết luận có dẫn chứng");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Viết đoạn lập luận Claim-Evidence-Reasoning");
    await page.getByRole("button", { name: /thêm tiêu chí/i }).click();
    await page.getByRole("button", { name: /thêm tiêu chí/i }).click();
    await page.getByLabel("Tiêu chí 1", { exact: true }).fill("Nêu rõ luận điểm về vai trò quyết định của Ngô Quyền");
    await page.getByLabel("Tiêu chí 2", { exact: true }).fill("Trích dẫn ít nhất 1 bằng chứng khảo cổ hoặc sử liệu");
    await pickFirstEvidenceInSection(page, "Bằng chứng bắt buộc phải dùng");
    await fillRequiredFeedback(page);

    // Activity 12/13: CER_CHOICE (Kết luận có dẫn chứng (chọn) — tổ hợp Claim + Evidence + Reasoning)
    await pickActivity(page, "Kết luận có dẫn chứng (chọn)");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Chọn tổ hợp Kết luận - Bằng chứng - Lập luận đúng");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();

    // Thêm 2 phương án Claim
    const addOptionBtns = page.locator("main").getByRole("button", { name: /thêm phương án/i });
    await addOptionBtns.first().click();
    await addOptionBtns.first().click();
    await page.getByLabel("Phương án kết luận (Claim) * 1", { exact: true }).fill("Chiến thắng Bạch Đằng chấm dứt hơn 1000 năm Bắc thuộc");
    await page.getByLabel("Phương án kết luận (Claim) * 2", { exact: true }).fill("Trận Bạch Đằng chỉ là cuộc xung đột biên giới nhỏ");

    // Thêm 2 phương án Reasoning
    await addOptionBtns.last().click();
    await addOptionBtns.last().click();
    await page.getByLabel("Phương án suy luận (Reasoning) * 1", { exact: true }).fill("Vì đã đập tan ý chí xâm lược của Nam Hán và mở ra kỷ nguyên độc lập");
    await page.getByLabel("Phương án suy luận (Reasoning) * 2", { exact: true }).fill("Vì quân Nam Hán vẫn tiếp tục cai trị Giao Châu");

    // Chọn bằng chứng trong pool
    await pickFirstEvidenceInSection(page, "Bằng chứng học viên được chọn");

    // Tạo tổ hợp đúng (acceptedCombos)
    await page.getByRole("button", { name: /thêm tổ hợp đúng/i }).click();
    await page.getByLabel("Tổ hợp 1 — kết luận").selectOption({ index: 1 });
    await page.getByLabel("Tổ hợp 1 — lập luận").selectOption({ index: 1 });
    // Tick chọn bằng chứng trong Tổ hợp 1
    await page
      .locator("main div")
      .filter({ hasText: "Tổ hợp 1" })
      .locator("input[type='checkbox']")
      .first()
      .check();
    await page.getByLabel("Tự điền bằng chứng từ hoạt động (tuỳ chọn)").selectOption({ index: 1 });
    await fillRequiredFeedback(page);

    // --- STAGE 9: REFLECTION (REFLECTION_PROMPT) ---
    await addStage(page, "REFLECTION", "9. Suy ngẫm & Bài học lịch sử", true);

    // Activity 13/13: REFLECTION_PROMPT (Câu hỏi suy ngẫm)
    await pickActivity(page, "Câu hỏi suy ngẫm");
    await page.getByLabel("Hướng dẫn cho học viên").fill("Chia sẻ suy ngẫm cá nhân sau bài học");
    await page.locator("main label", { hasText: "Bắt buộc hoàn thành" }).last().click();
    await page
      .getByLabel("Câu hỏi gợi mở suy ngẫm")
      .fill("Theo em, bài học về sự chủ động nắm bắt thời cơ của Ngô Quyền có ý nghĩa gì đối với thế hệ trẻ ngày nay?");

    await expect(page.getByText("Giai đoạn (9)")).toBeVisible();

    /* ====================================================================== */
    /* PHASE 6: LOCAL VALIDATION, LƯU NHÁP 9 STAGES & PREVIEW HỌC VIÊN        */
    /* ====================================================================== */

    // Lưu bản nháp chứa toàn bộ 9 Stages & 13 loại Activity
    await page.getByRole("button", { name: /lưu nháp/i }).click();
    await expect(page.getByText(/^đã lưu \d/i)).toBeVisible({ timeout: 20_000 });

    // Kiểm tra xuất bản ngay trên Builder
    await page.getByRole("button", { name: /kiểm tra xuất bản/i }).click();
    await expect(page.getByText(/sẵn sàng xuất bản/i)).toBeVisible({ timeout: 15_000 });

    // Mở trang Preview (/lessons/{id}/preview) và kiểm tra render cả 9 Stages
    await page.goto(`/lessons/${lessonId}/preview`);
    await expect(page.getByText(/chế độ xem trước/i)).toBeVisible({ timeout: 30_000 });

    // Stage 1: CONTEXT (Activity 1: READ -> Activity 2: VIEW_IMAGE)
    await expect(page.getByText(/Mùa đông năm 938, quân Nam Hán/i)).toBeVisible();
    await page.getByRole("button", { name: "Hoạt động tiếp" }).click();
    await expect(page.getByText("Sơ đồ bố trí bãi cọc gỗ lim tại cửa sông Bạch Đằng")).toBeVisible();

    // Stage 2: DISCOVERY (EXPLORE_MAP)
    await page.getByRole("tab", { name: /2\. Khám phá địa hình cửa biển/i }).click();
    await expect(page.getByText("Khám phá các nhánh sông Bạch Đằng")).toBeVisible();

    // Stage 3: EVIDENCE (Activity 1: EVIDENCE_SELECT -> Activity 2: MULTIPLE_CHOICE single)
    await page.getByRole("tab", { name: /3\. Thu thập bằng chứng lịch sử/i }).click();
    await expect(page.getByText("Chọn bằng chứng xác thực về bãi cọc")).toBeVisible();
    await page.getByRole("button", { name: "Hoạt động tiếp" }).click();
    await expect(
      page.getByText("Ai là người lãnh đạo quân dân ta trong trận Bạch Đằng năm 938?"),
    ).toBeVisible();

    // Stage 4: REASONING (Activity 1: MATCHING -> Activity 2: REASONING_CONNECT -> Activity 3: MC multi)
    await page.getByRole("tab", { name: /4\. Phân tích & Suy luận chiến thuật/i }).click();
    await expect(page.getByText("Chủ soái quân Việt")).toBeVisible();
    await page.getByRole("button", { name: "Hoạt động tiếp" }).click();
    await expect(page.getByText("Thủy triều rút mạnh")).toBeVisible();
    await page.getByRole("button", { name: "Hoạt động tiếp" }).click();
    await expect(
      page.getByText("Những yếu tố nào góp phần trực tiếp vào chiến thắng Bạch Đằng?"),
    ).toBeVisible();

    // Stage 5: HYPOTHESIS (HYPOTHESIS_CHOICE)
    await page.getByRole("tab", { name: /5\. Đặt giả thuyết lịch sử/i }).click();
    await expect(
      page.getByText("Ngô Quyền dùng thuyền nhẹ nhử địch vượt qua bãi cọc lúc triều lên"),
    ).toBeVisible();

    // Stage 6: RECONSTRUCTION (DRAG_ORDER)
    await page.getByRole("tab", { name: /6\. Tái dựng diễn biến trận đánh/i }).click();
    await expect(page.getByText("Sắp xếp 3 mốc diễn biến theo trình tự thời gian")).toBeVisible();

    // Stage 7: VERIFICATION (VERIFICATION)
    await page.getByRole("tab", { name: /7\. Kiểm chứng giả thuyết/i }).click();
    await expect(page.getByText("Đối chiếu giả thuyết với bằng chứng đã thu thập")).toBeVisible();

    // Stage 8: CONCLUSION (Activity 1: CER -> Activity 2: CER_CHOICE)
    await page.getByRole("tab", { name: /8\. Kết luận lịch sử có dẫn chứng/i }).click();
    await expect(page.getByText("Viết đoạn lập luận Claim-Evidence-Reasoning")).toBeVisible();
    await page.getByRole("button", { name: "Hoạt động tiếp" }).click();
    await expect(
      page.getByText("Chiến thắng Bạch Đằng chấm dứt hơn 1000 năm Bắc thuộc"),
    ).toBeVisible();

    // Stage 9: REFLECTION (REFLECTION_PROMPT)
    await page.getByRole("tab", { name: /9\. Suy ngẫm & Bài học lịch sử/i }).click();
    await expect(
      page.getByText(/Theo em, bài học về sự chủ động nắm bắt thời cơ của Ngô Quyền/i),
    ).toBeVisible();

    // Đảm bảo không lộ bất kỳ khoá đáp án nào ra HTML preview
    const previewHtml = await page.content();
    for (const secretKey of [
      "correctOptionIds",
      "correctPairs",
      "expectedOrder",
      "acceptedEvidenceIds",
      "acceptedCombos",
      "expectedRelations",
    ]) {
      expect(previewHtml).not.toContain(secretKey);
    }

    /* ====================================================================== */
    /* PHASE 7: XUẤT BẢN (v1 -> v2), ĐỔI ẢNH BÌA SAU PUBLISH & ARCHIVE        */
    /* ====================================================================== */
    await page.goto(`/lessons/${lessonId}/publish`);
    await page.getByRole("button", { name: /kiểm tra xuất bản/i }).click();
    await expect(page.getByText(/đủ điều kiện xuất bản/i)).toBeVisible({ timeout: 15_000 });

    await page.getByRole("button", { name: /xuất bản bài học/i }).click();
    await page.getByRole("button", { name: /^xuất bản$/i }).click();
    await expect(page.getByText(/đã xuất bản phiên bản 1 thành công/i)).toBeVisible({
      timeout: 15_000,
    });

    // Kiểm tra đổi ảnh bìa khi bài học đang PUBLISHED (không làm hỏng snapshot v1)
    await page.goto(`/lessons/${lessonId}`);
    await expect(page.getByText("cover-9stages-v1.png")).toBeVisible({ timeout: 15_000 });
    await page.getByRole("button", { name: "Thay ảnh", exact: true }).click();
    const pubPicker = page.getByRole("dialog");
    await pubPicker.locator("input[type='file']").setInputFiles({
      name: "cover-9stages-v2-published.png",
      mimeType: "image/png",
      buffer: pngCover2,
    });
    await expect(pubPicker).toBeHidden({ timeout: 15_000 });
    await expect(page.getByText("Đã cập nhật ảnh bìa bài học.")).toBeVisible();
    await expect(page.getByText("cover-9stages-v2-published.png")).toBeVisible();

    // Lưu trữ bài học (ARCHIVED) tại trang /publish -> quay lại /lessons/{id} kiểm tra khoá chỉnh sửa
    await page.goto(`/lessons/${lessonId}/publish`);
    await page.getByRole("button", { name: /lưu trữ bài học/i }).click();
    await page.getByRole("dialog").getByRole("button", { name: /^lưu trữ$/i }).click();
    await page.goto(`/lessons/${lessonId}`);
    await expect(page.getByText(/Bài học đã lưu trữ — chỉ xem/i)).toBeVisible({
      timeout: 15_000,
    });
    await expect(page.getByRole("button", { name: /lưu thay đổi/i })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Thay ảnh", exact: true })).toBeDisabled();
    await expect(page.getByRole("button", { name: "Gỡ ảnh", exact: true })).toBeDisabled();
  });
});
