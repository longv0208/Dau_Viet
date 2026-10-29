import { test, expect } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createE2EFixture } from '../fixtures/test-harness.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const evidenceDir = path.resolve(__dirname, '../test-results/evidence');
fs.mkdirSync(evidenceDir, { recursive: true });

const OVERFLOW_OR_ERROR_RE =
  /RenderFlex overflowed|A RenderFlex overflowed|FlutterError|Assertion failed|Uncaught/i;

/**
 * Attach runtime, console overflow, and broken asset monitors to the page (Phase 06: TC-VIS-01 & TC-VIS-02).
 */
function attachRuntimeAndOverflowMonitor(page) {
  const overflowAndRuntimeErrors = [];
  const failedAssetUrls = [];

  page.on('pageerror', (err) => {
    overflowAndRuntimeErrors.push(`pageerror: ${err.message || String(err)}`);
  });

  page.on('console', (msg) => {
    const text = msg.text();
    if (OVERFLOW_OR_ERROR_RE.test(text)) {
      overflowAndRuntimeErrors.push(`console.${msg.type()}: ${text}`);
    }
  });

  page.on('response', (res) => {
    const url = res.url();
    if (url.includes('/assets/') && res.status() >= 400) {
      failedAssetUrls.push(`${res.status()} ${url}`);
    }
  });

  return { overflowAndRuntimeErrors, failedAssetUrls };
}

/**
 * Verify a visible locator's bounding box lies completely within the active viewport (Phase 06: TC-VIS-03).
 */
async function assertWithinViewport(page, locator, label) {
  await expect(locator, `${label} should be visible`).toBeVisible();
  const box = await locator.boundingBox();
  const vp = page.viewportSize() || { width: 390, height: 844 };
  expect(box, `${label} boundingBox should exist`).not.toBeNull();
  expect(box.x, `${label} x >= -1`).toBeGreaterThanOrEqual(-1);
  expect(box.y, `${label} y >= -1`).toBeGreaterThanOrEqual(-1);
  expect(box.x + box.width, `${label} right edge <= ${vp.width}`).toBeLessThanOrEqual(vp.width + 2);
  expect(box.y + box.height, `${label} bottom edge <= ${vp.height}`).toBeLessThanOrEqual(
    vp.height + 2,
  );
}

/**
 * Fill a Flutter Web TextFormField via accessibility label/textbox role.
 */
async function fillFlutterTextField(page, labelText, value) {
  const input = page.getByLabel(labelText, { exact: false }).first();
  await expect(input).toBeVisible({ timeout: 20_000 });
  await input.click();
  await input.fill(value);
}

/**
 * Log in a learner through the real Flutter Mobile UI (/auth -> /dashboard).
 */
async function loginLearnerViaUi(page, { email, password }) {
  await page.addInitScript(() => {
    window.localStorage.setItem('flutter.onboarding_seen_v1', 'true');
  });

  await page.goto('/#/auth');
  await fillFlutterTextField(page, 'Nhập email hoặc tên đăng nhập', email);
  await fillFlutterTextField(page, 'Nhập mật khẩu', password);

  const loginBtn = page.getByRole('button', { name: 'Đăng nhập' }).last();
  await assertWithinViewport(page, loginBtn, 'Nút Đăng nhập');
  await loginBtn.click();

  await expect(page.getByText('Hành trình của bạn')).toBeVisible({ timeout: 25_000 });
}

test.describe('Issue #27 — [E2E] Mobile: Đảo Di Sản và bài học (390x844 & 360x800 Chrome, real backend)', () => {
  let fixture = null;
  let monitor = null;

  test.beforeEach(async ({ page }) => {
    monitor = attachRuntimeAndOverflowMonitor(page);
    fixture = await createE2EFixture();
  });

  test.afterEach(async () => {
    try {
      if (monitor) {
        expect(monitor.overflowAndRuntimeErrors).toEqual([]);
        expect(monitor.failedAssetUrls).toEqual([]);
      }
    } finally {
      if (fixture) {
        const f = fixture;
        fixture = null;
        f.cleanup();
        const remainingRows = f.verifyCleanup();
        expect(remainingRows).toBe(0);
      }
    }
  });

  test('Phase 02 (AC-1 & AC-2): Luồng bài học (READ + MULTIPLE_CHOICE, feedback từ server, reload giữ đúng attempt & version, hoàn tất + idempotent retry, không đè badge Thể lực)', async ({
    page,
  }) => {
    // 1. Đăng nhập learner qua giao diện (TC-LES-01)
    await loginLearnerViaUi(page, fixture.learner);

    // 2. Từ Trang chủ (/dashboard) điều hướng vào Sự kiện nổi bật -> bài học đã publish
    const featuredEventCta = page.getByText('Xem chi tiết →').first();
    await featuredEventCta.scrollIntoViewIfNeeded();
    await expect(featuredEventCta).toBeVisible();
    await featuredEventCta.click();

    await expect(page.getByText('BÀI HỌC LỊCH SỬ')).toBeVisible({ timeout: 20_000 });
    const lessonCard = page.getByLabel(fixture.lesson.title, { exact: false }).first();
    await expect(lessonCard).toBeVisible({ timeout: 15_000 });
    await lessonCard.click();

    // Màn LessonEntryScreen (/learning/lesson/:lessonId)
    await expect(page.getByText(fixture.lesson.centralQuestion)).toBeVisible({ timeout: 20_000 });
    await page.screenshot({ path: path.join(evidenceDir, 'ac1-lesson-entry-cover.png') });
    const startAttemptRespPromise = page.waitForResponse(
      (res) =>
        res.url().includes(`/api/v1/lessons/${fixture.lesson.id}/attempts`) &&
        res.request().method() === 'POST',
    );
    const startBtn = page.getByRole('button', { name: /BẮT ĐẦU HỌC|TIẾP TỤC HỌC/i }).first();
    await assertWithinViewport(page, startBtn, 'Nút BẮT ĐẦU HỌC');
    await startBtn.click();

    const startAttemptResp = await startAttemptRespPromise;
    expect(startAttemptResp.status()).toBe(200);
    const startAttemptJson = await startAttemptResp.json();
    const attemptId = startAttemptJson.attemptId;
    expect(attemptId).toMatch(/^[0-9a-f-]{36}$/i);

    // 3. Bắt đầu attempt: Activity 1 (READ) (TC-LES-02)
    await expect(page.getByText(fixture.lesson.readInstruction)).toBeVisible({ timeout: 20_000 });
    await expect(page.getByText('0/2')).toBeVisible();
    expect(page.url()).toContain(`/learning/attempt/${attemptId}`);

    const finishReadBtn = page.getByRole('button', { name: 'ĐÃ ĐỌC XONG, TIẾP TỤC' });
    await assertWithinViewport(page, finishReadBtn, 'Nút ĐÃ ĐỌC XONG, TIẾP TỤC');
    await finishReadBtn.click();

    // Kiểm chứng UI hiển thị phản hồi từ server trước khi sang bước tiếp theo
    await expect(page.getByText('CHÍNH XÁC! XUẤT SẮC!')).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText(fixture.lesson.readServerFeedback)).toBeVisible();

    const continueBtn = page.getByRole('button', { name: /TIẾP TỤC/i }).first();
    await assertWithinViewport(page, continueBtn, 'Nút TIẾP TỤC');
    await continueBtn.click();

    // 4. Đang ở Activity 2 (MULTIPLE_CHOICE, tiến độ 1/2) (TC-LES-03)
    await expect(page.getByText(fixture.lesson.mcInstruction)).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('1/2')).toBeVisible();
    // Kiểm chứng BUG-06 đã sửa: câu trắc nghiệm 2 lựa chọn chữ dài không báo nhầm "chọn Đúng hoặc Sai"
    await expect(page.getByText(/chọn Đúng hoặc Sai/i)).toHaveCount(0);

    // Xuất bản version mới (v2) của lesson khi attempt đang dở dang để kiểm chứng version pinning
    const { lessonVersionV2Id, versionNo } = await fixture.publishLessonV2();
    expect(versionNo).toBe(2);
    expect(lessonVersionV2Id).not.toBe(fixture.lesson.versionV1Id);

    // Tải lại trang trình duyệt giữa bài (AC-2)
    const contentRespPromise = page.waitForResponse(
      (res) =>
        res.url().includes(`/api/v1/attempts/${attemptId}/content`) && res.status() === 200,
    );
    await page.reload();
    const contentResp = await contentRespPromise;
    const contentJson = await contentResp.json();

    // Xác nhận sau reload vẫn tiếp tục đúng attemptId, đúng phiên bản bài học v1, và đúng tiến độ 1/2
    expect(page.url()).toContain(`/learning/attempt/${attemptId}`);
    expect(contentJson.lessonVersionId).toBe(fixture.lesson.versionV1Id);
    expect(contentJson.versionNo).toBe(1);
    await expect(page.getByText(fixture.lesson.mcInstruction)).toBeVisible({ timeout: 20_000 });
    await expect(page.getByText('1/2')).toBeVisible();

    // 5. Làm activity tương tác (MULTIPLE_CHOICE): thử chọn đáp án sai trước -> nhận feedback từ server (TC-LES-04)
    await page.getByText(fixture.lesson.mcWrongLabel).first().click();
    const submitAnswerBtn = page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' });
    await assertWithinViewport(page, submitAnswerBtn, 'Nút GỬI CÂU TRẢ LỜI');
    await submitAnswerBtn.click();

    await expect(page.getByText(fixture.lesson.mcWrongFeedback)).toBeVisible({ timeout: 15_000 });

    // Chọn đáp án đúng -> Gửi câu trả lời -> UI hiển thị feedback từ server, toast -10 Thể lực cũ đã bị gỡ (BUG-04)
    await page.getByText(fixture.lesson.mcCorrectLabel).first().click();
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();

    await expect(page.getByText(fixture.lesson.mcCorrectFeedback)).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('-10 Thể lực', { exact: true })).toHaveCount(0);

    await page.screenshot({ path: path.join(evidenceDir, 'ac1-lesson-server-feedback.png') });

    // 6. Hoàn tất bài học -> hiển thị màn kết quả & progress từ backend (TC-LES-05)
    const completeLessonBtn = page.getByRole('button', { name: 'HOÀN THÀNH BÀI HỌC' });
    await assertWithinViewport(page, completeLessonBtn, 'Nút HOÀN THÀNH BÀI HỌC');
    await completeLessonBtn.click();

    await expect(page.getByText('HOÀN THÀNH BÀI HỌC', { exact: true })).toBeVisible({
      timeout: 20_000,
    });
    await expect(page.getByText('Bạn thật tuyệt vời!')).toBeVisible();
    await expect(page.getByText('+100 XP', { exact: true })).toBeVisible();

    await page.screenshot({ path: path.join(evidenceDir, 'ac2-lesson-result-screen.png') });

    const progressAfter = await fixture.getLearnerProgressFromApi();
    expect(progressAfter.completedCount).toBe(1);
    expect(progressAfter.inProgress.length).toBe(0);

    // 7. Retry thao tác hoàn tất (cùng Idempotency-Key và không key) không tạo kết quả hoặc phần thưởng trùng (TC-LES-06)
    const retry1 = await fixture.postCompleteAttemptDirect(attemptId, `e2e-retry-key-${fixture.runId}`);
    const retry2 = await fixture.postCompleteAttemptDirect(attemptId, `e2e-retry-key-${fixture.runId}`);
    const retry3 = await fixture.postCompleteAttemptDirect(attemptId, null);
    expect(retry1.status).toBe(200);
    expect(retry1.data.alreadyCompleted).toBe(true);
    expect(retry2.status).toBe(200);
    expect(retry2.data.alreadyCompleted).toBe(true);
    expect(retry3.status).toBe(200);
    expect(retry3.data.alreadyCompleted).toBe(true);

    const dbCounts = fixture.getAttemptDbCounts(attemptId);
    expect(dbCounts.lessonResultsCount).toBe(1);
    expect(dbCounts.expRewardsCount).toBe(1);
    expect(dbCounts.pointsRewardsCount).toBe(1);
  });

  test('Phase 03 (AC-3): Luồng Đảo Di Sản (kiểm tra Header không cắt chữ, đóng thẻ chào mừng, kiểm tra 3 loại slot, Kho vật phẩm, đặt rồi cất vật phẩm và reload xác nhận backend)', async ({
    page,
  }) => {
    await loginLearnerViaUi(page, fixture.learner);

    // Từ giao diện Trang chủ mở Đảo Di Sản (TC-ISL-01)
    const islandCard = page.getByText('Đảo Di Sản').first();
    await islandCard.scrollIntoViewIfNeeded();
    await expect(islandCard).toBeVisible();
    await islandCard.click();

    const headerTitle = page.getByText('ĐẢO DI SẢN', { exact: true });
    await assertWithinViewport(page, headerTitle, 'Tiêu đề ĐẢO DI SẢN');

    // Chờ tường minh và đóng thẻ chào mừng lần đầu (BUG-05)
    const skipWelcomeBtn = page.getByRole('button', { name: 'BỎ QUA' });
    await expect(skipWelcomeBtn).toBeVisible({ timeout: 10_000 });
    await skipWelcomeBtn.click();
    await expect(page.getByText('Chào mừng đến Đảo Di Sản!')).toHaveCount(0);

    const { occupiedSlot, emptySlot, lockedSlot, item1, item2 } = fixture.island;

    // 1. Kiểm tra trạng thái slot có vật phẩm (occupiedSlot) (TC-ISL-02)
    const occupiedSlotBtn = page.getByRole('button', {
      name: new RegExp(`Ô di sản ${occupiedSlot.stableSlotKey}`),
    });
    await expect(occupiedSlotBtn).toBeAttached({ timeout: 15_000 });
    await occupiedSlotBtn.dispatchEvent('click');
    await expect(page.getByText('Đã xây dựng • Đang trưng bày di sản')).toBeVisible();
    await expect(page.getByText(item1.name).first()).toBeVisible();
    await expect(page.getByRole('button', { name: 'CẤT VÀO KHO' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'ĐỔI VẬT PHẨM' })).toBeVisible();

    // 2. Kiểm tra trạng thái slot bị khóa (lockedSlot)
    const lockedSlotBtn = page.getByRole('button', {
      name: new RegExp(`Ô khóa ${lockedSlot.stableSlotKey}`),
    });
    await expect(lockedSlotBtn).toBeAttached({ timeout: 15_000 });
    await lockedSlotBtn.dispatchEvent('click');
    await expect(
      page.getByText(`Yêu cầu mở rộng Đảo Cấp ${lockedSlot.tierRequired}`),
    ).toBeVisible();
    await expect(page.getByRole('button', { name: 'XEM ĐIỀU KIỆN MỞ KHÓA' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'ĐẶT VẬT PHẨM DI SẢN' })).toHaveCount(0);

    // 3. Kiểm tra trạng thái slot trống (emptySlot) và mở danh sách vật phẩm theo tài khoản (TC-ISL-03)
    const emptySlotBtn = page.getByRole('button', {
      name: `Ô trống ${emptySlot.stableSlotKey}`,
    });
    await expect(emptySlotBtn).toBeAttached({ timeout: 15_000 });
    await emptySlotBtn.dispatchEvent('click');
    await expect(page.getByText('Ô đất trống • Sẵn sàng xây dựng')).toBeVisible();
    const openInventoryBtn = page.getByRole('button', { name: 'ĐẶT VẬT PHẨM DI SẢN' });
    await assertWithinViewport(page, openInventoryBtn, 'Nút ĐẶT VẬT PHẨM DI SẢN');
    await openInventoryBtn.click();

    // Kiểm tra danh sách vật phẩm theo tài khoản trong Kho vật phẩm trang trí
    await expect(page.getByText('KHO VẬT PHẨM TRANG TRÍ')).toBeVisible({ timeout: 15_000 });
    const ownedFilterChip = page.getByRole('checkbox', { name: 'Đã sở hữu' });
    await expect(ownedFilterChip).toBeAttached();
    await ownedFilterChip.dispatchEvent('click');
    await expect(page.getByLabel(new RegExp(item1.name)).first()).toBeVisible();
    await expect(page.getByRole('button', { name: new RegExp(item2.name) })).toBeVisible();

    // Chuyển về bộ lọc 'Có thể đặt' và đặt item2 lên emptySlot (TC-ISL-04)
    const placeableFilterChip = page.getByRole('checkbox', { name: 'Có thể đặt' });
    await placeableFilterChip.dispatchEvent('click');
    const placeBtn = page.getByRole('button', { name: new RegExp(`${item2.name}.*ĐẶT`) }).first();
    await expect(placeBtn).toBeVisible();
    await placeBtn.click();
    await expect(
      page.getByText('Đã đặt vật phẩm lên Đảo Di Sản thành công!').first(),
    ).toBeVisible({ timeout: 15_000 });

    await page.screenshot({ path: path.join(evidenceDir, 'ac3-island-item-placed.png') });

    // 4. Tải lại trang và xác nhận vật phẩm vừa đặt được lưu ở backend + hiển thị trên UI (không bị thẻ chào mừng che)
    await page.reload();
    await expect(page.getByText('ĐẢO DI SẢN', { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByText('Chào mừng đến Đảo Di Sản!')).toHaveCount(0);

    const islandAfterPlace = await fixture.getLearnerIslandFromApi();
    const slotAfterPlace = islandAfterPlace.slots.find((s) => s.slotId === emptySlot.slotId);
    expect(slotAfterPlace?.placedItemId).toBe(item2.id);

    const newlyOccupiedBtn = page.getByRole('button', {
      name: new RegExp(`Ô di sản ${emptySlot.stableSlotKey}`),
    });
    await expect(newlyOccupiedBtn).toBeAttached({ timeout: 15_000 });
    await newlyOccupiedBtn.dispatchEvent('click');
    await expect(page.getByText('Đã xây dựng • Đang trưng bày di sản')).toBeVisible();
    await expect(page.getByText(item2.name).first()).toBeVisible();

    // 5. Cất vật phẩm hợp lệ vừa đặt về kho (TC-ISL-05)
    const removeBtn = page.getByRole('button', { name: 'CẤT VÀO KHO' });
    await assertWithinViewport(page, removeBtn, 'Nút CẤT VÀO KHO');
    await removeBtn.click();

    await expect(
      page.getByText('Đã cất vật phẩm về kho. Bạn có thể chọn vật phẩm khác cho ô này.').first(),
    ).toBeVisible({ timeout: 15_000 });

    // 6. Tải lại trang lần 2 và xác nhận trạng thái đã cất được lưu ở backend + hiển thị ô trống trên UI
    await page.reload();
    await expect(page.getByText('ĐẢO DI SẢN', { exact: true })).toBeVisible({ timeout: 20_000 });
    await expect(page.getByText('Chào mừng đến Đảo Di Sản!')).toHaveCount(0);

    const islandAfterRemove = await fixture.getLearnerIslandFromApi();
    const slotAfterRemove = islandAfterRemove.slots.find((s) => s.slotId === emptySlot.slotId);
    expect(slotAfterRemove?.placedItemId).toBeNull();

    const emptyAgainBtn = page.getByRole('button', {
      name: `Ô trống ${emptySlot.stableSlotKey}`,
    });
    await expect(emptyAgainBtn).toBeAttached({ timeout: 15_000 });
    await emptyAgainBtn.dispatchEvent('click');
    await expect(page.getByText('Ô đất trống • Sẵn sàng xây dựng')).toBeVisible();

    await page.screenshot({ path: path.join(evidenceDir, 'ac3-island-item-removed-reloaded.png') });
  });

  test('Phase 04 (AC-4): Kiểm tra các đường lỗi (chưa đăng nhập bị chuyển về đăng nhập, lỗi API có thông báo + thử lại, slot bị khóa không thể đặt vật phẩm, không giả lập thành công)', async ({
    page,
  }) => {
    // 1. Chưa đăng nhập truy cập màn bài học hoặc Đảo Di Sản -> bị chuyển về /auth (TC-ERR-01)
    await page.goto(`/#/learning/lesson/${fixture.lesson.id}`);
    await expect(page.getByRole('button', { name: 'Đăng nhập' }).last()).toBeVisible({
      timeout: 20_000,
    });
    expect(page.url()).toContain('/auth');

    await page.goto('/#/island');
    await expect(page.getByRole('button', { name: 'Đăng nhập' }).last()).toBeVisible({
      timeout: 20_000,
    });
    expect(page.url()).toContain('/auth');

    // 2. Đăng nhập learner để kiểm tra đường lỗi API ở luồng bài học và Đảo Di Sản
    await loginLearnerViaUi(page, fixture.learner);

    // 2a. Đường lỗi luồng bài học: lỗi API khi nộp activity -> hiện thông báo lỗi, KHÔNG giả lập thành công, bấm gửi lại thành công (TC-ERR-02)
    await page.goto(`/#/learning/lesson/${fixture.lesson.id}`);
    const startBtn = page.getByRole('button', { name: /BẮT ĐẦU HỌC|TIẾP TỤC HỌC/i }).first();
    await expect(startBtn).toBeVisible({ timeout: 20_000 });
    await startBtn.click();

    await expect(page.getByText(fixture.lesson.readInstruction)).toBeVisible({ timeout: 20_000 });

    let failSubmitOnce = true;
    await page.route('**/api/v1/attempts/*/activities/*/submissions', async (route) => {
      if (failSubmitOnce && route.request().method() === 'POST') {
        failSubmitOnce = false;
        await route.fulfill({
          status: 503,
          contentType: 'application/json',
          body: JSON.stringify({
            code: 'SERVICE_UNAVAILABLE',
            message: 'Máy chủ bài học tạm thời gián đoạn, vui lòng thử lại.',
            details: {},
            traceId: 'e2e-lesson-submit-err',
          }),
        });
        return;
      }
      await route.continue();
    });

    await page.getByRole('button', { name: 'ĐÃ ĐỌC XONG, TIẾP TỤC' }).click();

    // Xác nhận hiển thị lỗi từ API và KHÔNG giả lập hoàn thành (vẫn ở bước 0/2, không hiện màn chúc mừng)
    await expect(
      page.getByText('Máy chủ bài học tạm thời gián đoạn, vui lòng thử lại.'),
    ).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('CHÍNH XÁC! XUẤT SẮC!')).toHaveCount(0);
    await expect(page.getByText('0/2')).toBeVisible();

    await page.screenshot({ path: path.join(evidenceDir, 'ac4-lesson-api-error-no-fake-success.png') });

    // Thao tác thử lại: bấm lại nút nộp -> thành công thật từ server
    await page.getByRole('button', { name: 'ĐÃ ĐỌC XONG, TIẾP TỤC' }).click();
    await expect(page.getByText('CHÍNH XÁC! XUẤT SẮC!')).toBeVisible({ timeout: 15_000 });

    // 2b. Đường lỗi luồng Đảo Di Sản: lỗi tải đảo + nút THỬ LẠI (TC-ERR-03)
    let failIslandGetOnce = true;
    await page.route('**/api/v1/me/island', async (route) => {
      if (failIslandGetOnce && route.request().method() === 'GET') {
        failIslandGetOnce = false;
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({
            code: 'INTERNAL_ERROR',
            message: 'Mất kết nối máy chủ Đảo Di Sản khi tải dữ liệu.',
            details: {},
            traceId: 'e2e-island-load-err',
          }),
        });
        return;
      }
      await route.continue();
    });

    await page.goto('/#/island');
    await expect(page.getByText('Không thể kết nối Đảo Di Sản')).toBeVisible({ timeout: 20_000 });
    await expect(
      page.getByText('Mất kết nối máy chủ Đảo Di Sản khi tải dữ liệu.'),
    ).toBeVisible();

    await page.screenshot({ path: path.join(evidenceDir, 'ac4-island-load-error-retry.png') });

    // Nhấn nút THỬ LẠI -> tải thành công Đảo Di Sản từ backend thật
    const retryIslandBtn = page.getByRole('button', { name: 'THỬ LẠI' });
    await assertWithinViewport(page, retryIslandBtn, 'Nút THỬ LẠI');
    await retryIslandBtn.click();

    await expect(page.getByText('ĐẢO DI SẢN', { exact: true })).toBeVisible({ timeout: 20_000 });
    const skipWelcomeBtn = page.getByRole('button', { name: 'BỎ QUA' });
    await expect(skipWelcomeBtn).toBeVisible({ timeout: 10_000 });
    await skipWelcomeBtn.click();

    const { emptySlot, lockedSlot, item2 } = fixture.island;

    // Kiểm tra lỗi API khi đặt vật phẩm lên ô trống: KHÔNG giả lập thành công trên UI hoặc backend (TC-ERR-04)
    let failPlacementOnce = true;
    await page.route(`**/api/v1/me/island/placements/${emptySlot.slotId}`, async (route) => {
      if (failPlacementOnce && route.request().method() === 'PUT') {
        failPlacementOnce = false;
        await route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({
            code: 'INTERNAL_ERROR',
            message: 'Không thể lưu vị trí vật phẩm do lỗi máy chủ.',
            details: {},
            traceId: 'e2e-island-place-err',
          }),
        });
        return;
      }
      await route.continue();
    });

    const emptySlotErrBtn = page.getByRole('button', { name: `Ô trống ${emptySlot.stableSlotKey}` });
    await expect(emptySlotErrBtn).toBeAttached({ timeout: 15_000 });
    await emptySlotErrBtn.dispatchEvent('click');
    await page.getByRole('button', { name: 'ĐẶT VẬT PHẨM DI SẢN' }).click();
    await expect(page.getByText('KHO VẬT PHẨM TRANG TRÍ')).toBeVisible({ timeout: 15_000 });
    await page
      .getByRole('button', { name: new RegExp(`${item2.name}.*ĐẶT`) })
      .first()
      .click();

    await expect(
      page.getByText('Không thể lưu vị trí vật phẩm do lỗi máy chủ.').first(),
    ).toBeVisible({ timeout: 15_000 });
    // Ô vẫn phải là ô trống, tuyệt đối không giả lập đã đặt vật phẩm
    await expect(page.getByText('Ô đất trống • Sẵn sàng xây dựng')).toBeVisible();
    const islandStateAfterFailedPlace = await fixture.getLearnerIslandFromApi();
    const emptySlotState = islandStateAfterFailedPlace.slots.find(
      (s) => s.slotId === emptySlot.slotId,
    );
    expect(emptySlotState?.placedItemId).toBeNull();

    // Kiểm tra slot bị khóa không thể đặt vật phẩm (cả trên UI và từ chối ở Backend 403 SLOT_LOCKED) (TC-ERR-05)
    const lockedSlotErrBtn = page.getByRole('button', {
      name: new RegExp(`Ô khóa ${lockedSlot.stableSlotKey}`),
    });
    await expect(lockedSlotErrBtn).toBeAttached({ timeout: 15_000 });
    await lockedSlotErrBtn.dispatchEvent('click');
    await expect(
      page.getByText(`Yêu cầu mở rộng Đảo Cấp ${lockedSlot.tierRequired}`),
    ).toBeVisible();
    await expect(page.getByRole('button', { name: 'ĐẶT VẬT PHẨM DI SẢN' })).toHaveCount(0);

    const lockedPlaceAttempt = await fixture.putPlacementDirect(
      lockedSlot.slotId,
      item2.id,
      islandStateAfterFailedPlace.rowVersion,
    );
    expect(lockedPlaceAttempt.status).toBe(403);
    expect(lockedPlaceAttempt.data?.code).toBe('SLOT_LOCKED');
  });

  test('Phase 05 (TC-ENG-01..03): Làm sai nhiều lần dẫn đến cạn Thể lực (15 -> 5 -> 0 clamp), chặn 409 ENERGY_DEPLETED, hiện Dialog Hết Thể lực -> Viện Thái Y (/energy), và hồi phục Thể lực để hoàn thành bài học', async ({
    page,
  }) => {
    // Khởi tạo learner chỉ còn 5 Thể lực (nhỏ hơn mức phạt 10 để kiểm chứng cả clamp -5 về 0)
    fixture.setLearnerEnergy(5, 0);

    await loginLearnerViaUi(page, fixture.learner);

    await page.goto(`/#/learning/lesson/${fixture.lesson.id}`);
    const startBtn = page.getByRole('button', { name: /BẮT ĐẦU HỌC|TIẾP TỤC HỌC/i }).first();
    await expect(startBtn).toBeVisible({ timeout: 20_000 });
    await startBtn.click();

    // Activity 1 (READ - không tốn Thể lực, vẫn nộp bình thường)
    await expect(page.getByText(fixture.lesson.readInstruction)).toBeVisible({ timeout: 20_000 });
    await page.getByRole('button', { name: 'ĐÃ ĐỌC XONG, TIẾP TỤC' }).click();
    await expect(page.getByText('CHÍNH XÁC! XUẤT SẮC!')).toBeVisible({ timeout: 15_000 });
    await page.getByRole('button', { name: /TIẾP TỤC/i }).first().click();

    // Activity 2 (MULTIPLE_CHOICE, maxAttempts: 2)
    await expect(page.getByText(fixture.lesson.mcInstruction)).toBeVisible({ timeout: 15_000 });
    const attemptUrl = page.url();

    // Lượt sai 1: Số dư 5 < 10 -> bị clamp trừ đúng −5 Thể lực về 0 (TC-ENG-01)
    await page.getByText(fixture.lesson.mcWrongLabel).first().click();
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();

    await expect(
      page.getByText(`${fixture.lesson.mcWrongFeedback} −5 Thể lực`),
    ).toBeVisible({ timeout: 15_000 });

    const txAfterDeplete = fixture.getEnergyTransactions();
    expect(txAfterDeplete.length).toBe(1);
    expect(txAfterDeplete[0].direction).toBe('DEBIT');
    expect(txAfterDeplete[0].amount).toBe(5);
    expect(txAfterDeplete[0].balanceAfter).toBe(0);

    // Lượt 2 khi currentEnergy == 0: cố nộp câu trả lời -> bị chặn 409 ENERGY_DEPLETED, bật Dialog "Hết Thể lực" (TC-ENG-02)
    await page.getByText(fixture.lesson.mcCorrectLabel).first().click();
    const depletedRespPromise = page.waitForResponse(
      (res) =>
        res.url().includes('/activities/act-mc-verify/submissions') &&
        res.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();
    const depletedResp = await depletedRespPromise;
    expect(depletedResp.status()).toBe(409);
    const depletedJson = await depletedResp.json();
    expect(depletedJson.code).toBe('ENERGY_DEPLETED');
    expect(depletedJson.details?.currentEnergy).toBe(0);

    // Kiểm tra Dialog "Hết Thể lực" hiển thị đầy đủ trên màn hình điện thoại
    await expect(page.getByText('Hết Thể lực', { exact: true })).toBeVisible({ timeout: 10_000 });
    await expect(
      page.getByText(/Hệ thống sẽ tự hồi \+5 Thể lực sau/i),
    ).toBeVisible();

    await page.screenshot({ path: path.join(evidenceDir, 'phase5-energy-depleted-dialog.png') });

    // Nhấn "Ở LẠI XEM TIẾP" -> đóng dialog, không mất lựa chọn
    const stayBtn = page.getByRole('button', { name: 'Ở LẠI XEM TIẾP' });
    await assertWithinViewport(page, stayBtn, 'Nút Ở LẠI XEM TIẾP');
    await stayBtn.click();
    await expect(page.getByText('Hết Thể lực', { exact: true })).toHaveCount(0);

    // Nhấn lại GỬI CÂU TRẢ LỜI -> mở lại dialog -> nhấn "VIỆN THÁI Y" để sang màn /energy
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();
    const clinicBtn = page.getByRole('button', { name: 'VIỆN THÁI Y' });
    await assertWithinViewport(page, clinicBtn, 'Nút VIỆN THÁI Y');
    await clinicBtn.click();

    // Kiểm tra màn Viện Thái Y (/energy) hiển thị 0 / 100 và cảnh báo cạn thể lực
    await expect(page.getByText('QUẢN LÝ THỂ LỰC')).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('0 / 100')).toBeVisible();
    await expect(
      page.getByText(/Thể lực đã cạn\. Bạn vẫn có thể đọc tư liệu/i),
    ).toBeVisible();

    await page.screenshot({ path: path.join(evidenceDir, 'phase5-vien-thai-y-0-energy.png') });

    // Giả lập thời gian hồi phục đã qua 20 phút (>= 1 chu kỳ 15 phút -> lazy-recover +5 Thể lực) (TC-ENG-03)
    fixture.setLearnerEnergy(0, 20);

    // Quay lại bài học đang dở, nộp đáp án đúng -> thành công và hoàn tất bài học
    await page.goto(attemptUrl);
    await expect(page.getByText(fixture.lesson.mcInstruction)).toBeVisible({ timeout: 20_000 });
    await page.getByText(fixture.lesson.mcCorrectLabel).first().click();
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();

    await expect(page.getByText(fixture.lesson.mcCorrectFeedback)).toBeVisible({ timeout: 15_000 });
    await page.getByRole('button', { name: 'HOÀN THÀNH BÀI HỌC' }).click();
    await expect(page.getByText('HOÀN THÀNH BÀI HỌC', { exact: true })).toBeVisible({
      timeout: 20_000,
    });
  });

  test('Phase 05 & 06 (TC-ENG-04, TC-ISL-06 & TC-VIS-03): Làm sai cạn lượt thử maxAttempts không bị kẹt (anti-soft-lock), kiểm tra giới hạn tài nguyên Đảo/Shop và kiểm chứng không tràn giao diện ở viewport hẹp 360x800', async ({
    page,
  }) => {
    // Chạy toàn bộ kịch bản này trên viewport điện thoại nhỏ 360x800 (TC-VIS-03)
    await page.setViewportSize({ width: 360, height: 800 });

    await loginLearnerViaUi(page, fixture.learner);

    // 1. Làm sai hết sạch số lượt thử của câu hỏi (maxAttempts = 2) khi vẫn còn đầy Thể lực (TC-ENG-04)
    await page.goto(`/#/learning/lesson/${fixture.lesson.id}`);
    const startBtn = page.getByRole('button', { name: /BẮT ĐẦU HỌC|TIẾP TỤC HỌC/i }).first();
    await assertWithinViewport(page, startBtn, 'Nút BẮT ĐẦU HỌC (360x800)');
    await startBtn.click();

    await expect(page.getByText(fixture.lesson.readInstruction)).toBeVisible({ timeout: 20_000 });
    await page.getByRole('button', { name: 'ĐÃ ĐỌC XONG, TIẾP TỤC' }).click();
    await expect(page.getByText('CHÍNH XÁC! XUẤT SẮC!')).toBeVisible({ timeout: 15_000 });
    await page.getByRole('button', { name: /TIẾP TỤC/i }).first().click();

    // Lượt sai 1/2
    await expect(page.getByText(fixture.lesson.mcInstruction)).toBeVisible({ timeout: 15_000 });
    await page.getByText(fixture.lesson.mcWrongLabel).first().click();
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();
    await expect(page.getByText(fixture.lesson.mcWrongFeedback)).toBeVisible({ timeout: 15_000 });

    // Lượt sai 2/2 (cạn maxAttempts -> exhausted: true, cho phép hoàn thành bài học để không bị kẹt)
    const secondWrongRespPromise = page.waitForResponse(
      (res) =>
        res.url().includes('/activities/act-mc-verify/submissions') &&
        res.request().method() === 'POST',
    );
    await page.getByRole('button', { name: 'GỬI CÂU TRẢ LỜI' }).click();
    const secondWrongResp = await secondWrongRespPromise;
    expect(secondWrongResp.status()).toBe(200);
    const secondWrongJson = await secondWrongResp.json();
    expect(secondWrongJson.evaluation?.output?.exhausted).toBe(true);
    expect(secondWrongJson.completion?.complete).toBe(true);

    await expect(
      page.getByText(/Chưa chính xác — đã hết lượt thử\. Đi tiếp nhé\./i),
    ).toBeVisible({ timeout: 15_000 });

    const resultRespPromise = page.waitForResponse(
      (res) => res.url().includes('/result') && res.request().method() === 'GET',
    );
    const completeBtn = page.getByRole('button', { name: 'HOÀN THÀNH BÀI HỌC' });
    await assertWithinViewport(page, completeBtn, 'Nút HOÀN THÀNH BÀI HỌC sau khi cạn lượt thử');
    await completeBtn.click();

    const resultResp = await resultRespPromise;
    expect(resultResp.status()).toBe(200);
    const resultJson = await resultResp.json();
    expect(resultJson.status).toBe('COMPLETED');
    expect(resultJson.result?.knowledgeScore).toBe(0);

    await expect(page.getByText('HOÀN THÀNH BÀI HỌC', { exact: true })).toBeVisible({
      timeout: 20_000,
    });
    // 2. Kiểm tra Đảo Di Sản, Bảng Mở rộng Đảo và Cửa Hàng Di Sản ở viewport hẹp 360x800 (TC-ISL-06 & TC-VIS-03)
    await page.goto('/#/island');
    const islandTitle = page.getByText('ĐẢO DI SẢN', { exact: true });
    await assertWithinViewport(page, islandTitle, 'Tiêu đề ĐẢO DI SẢN (360x800)');

    const skipWelcomeBtn = page.getByRole('button', { name: 'BỎ QUA' });
    await expect(skipWelcomeBtn).toBeVisible({ timeout: 10_000 });
    await skipWelcomeBtn.click();

    // Mở bảng Mở rộng đảo khi chưa đủ Level (Level 1, 100 EXP < 500 EXP)
    await page.getByText('Mở rộng đảo').first().click();
    await expect(page.getByText('MỞ RỘNG ĐẢO DI SẢN')).toBeVisible({ timeout: 15_000 });
    const continueLearnBtn = page.getByRole('button', {
      name: 'TIẾP TỤC HỌC ĐỂ TÍCH LŨY EXP',
    });
    await assertWithinViewport(page, continueLearnBtn, 'Nút TIẾP TỤC HỌC ĐỂ TÍCH LŨY EXP (360x800)');

    const upgradeAttempt = await fixture.postUpgradeIslandDirect(1);
    expect(upgradeAttempt.status).toBe(422);
    expect(upgradeAttempt.data?.code).toBe('ISLAND_UPGRADE_INSUFFICIENT_LEVEL');

    // Mở Cửa Hàng Di Sản (/island/shop) ở viewport 360x800: kiểm tra vật phẩm ĐÃ SỞ HỮU và vật phẩm không đủ Điểm Sử Ký
    await page.goto('/#/island/shop');
    await expect(page.getByText('CỬA HÀNG DI SẢN')).toBeVisible({ timeout: 15_000 });
    await expect(page.getByLabel(/ĐÃ SỞ HỮU/).first()).toBeVisible({ timeout: 15_000 });

    const shopItems = await fixture.getShopItemsFromApi();
    const expensiveUnowned = shopItems.find(
      (i) =>
        i.purchasable &&
        i.pricePoints > 100 &&
        i.itemId !== fixture.island.item1.id &&
        i.itemId !== fixture.island.item2.id,
    );
    if (expensiveUnowned) {
      const buyRes = await fixture.postPurchaseShopItemDirect(expensiveUnowned.itemId);
      expect(buyRes.status).toBe(409);
      expect(buyRes.data?.code).toBe('INSUFFICIENT_FUNDS');
    }

    await page.screenshot({ path: path.join(evidenceDir, 'phase6-island-shop-360x800.png') });
  });
});
