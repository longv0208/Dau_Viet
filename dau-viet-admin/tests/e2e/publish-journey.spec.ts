import { expect, test, type Page } from "@playwright/test";

/**
 * TASK-0017 publish journey against the controlled node:http stub (NOT the
 * real backend). §8 same-event scenario: create+publish an event → lesson on
 * that exact event → MC + MATCHING + DRAG_ORDER authored via the real draft
 * API → preview → validate → publish → learner content carries the authored
 * shape without leaking answer keys → draft edit keeps published snapshot
 * immutable → republish bumps versionNo.
 */

async function login(page: Page) {
  await page.goto("/login");
  await page.getByLabel(/email/i).fill("admin@dauviet.local");
  await page.getByLabel(/mật khẩu/i).fill("secret");
  await page.getByRole("button", { name: /đăng nhập/i }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 20_000 });
}

async function createAndPublishEvent(page: Page, title: string, slug: string) {
  await page.goto("/events/new");
  await page.getByLabel(/tiêu đề/i).fill(title);
  await page.getByLabel(/slug/i).fill(slug);
  await page.getByLabel(/tóm tắt/i).fill("Sự kiện e2e cho publish journey");
  await page.getByRole("button", { name: /tạo sự kiện/i }).click();
  await expect(page).toHaveURL(/\/events\/[0-9a-f-]{36}$/, { timeout: 30_000 });
  const id = page.url().substring(page.url().lastIndexOf("/") + 1);
  await page.getByRole("button", { name: /xuất bản sự kiện/i }).click();
  await expect(page.getByText(/xuất bản sự kiện này\?/i)).toBeVisible();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  await expect(page.getByRole("button", { name: /xuất bản sự kiện/i })).toHaveCount(0, {
    timeout: 15_000,
  });
  return id;
}

async function createLessonOnEvent(page: Page, eventTitle: string, title: string) {
  await page.goto("/lessons/new");
  await page.getByRole("button", { name: new RegExp(eventTitle, "i") }).click({ timeout: 20_000 });
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
 * Seed a publishable draft through the REAL draft API (PUT /draft) — the
 * complex activities (MC/MATCHING/DRAG_ORDER) exercise the projection
 * contract, not the editor UX. Both answers and distractors are authored
 * here so the learner projection can be asserted structurally.
 */
/**
 * Learner /content demands a Bearer token; page.request doesn't carry the
 * in-memory access token, so fetch it via the cookie-backed session endpoint.
 */
async function learnerContent(page: Page, lessonId: string) {
  const session = await page.request.get("/api/auth/session");
  const { accessToken } = (await session.json()) as { accessToken: string };
  const res = await page.request.get(`/api/proxy/lessons/${lessonId}/content`, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  expect(res.ok()).toBeTruthy();
  return res;
}

async function seedDraft(page: Page, lessonId: string, draftJson: string, rowVersion: number) {
  const res = await page.request.put(`/api/proxy/admin/lessons/${lessonId}/draft`, {
    data: { draftJson, expectedRowVersion: rowVersion },
  });
  expect(res.ok()).toBeTruthy();
  const body = (await res.json()) as { rowVersion: number };
  return body.rowVersion;
}

const EV_ID = "e1111111-1111-1111-1111-111111111111"; // seeded evidence row

function complexDraft(variant: 1 | 2) {
  return JSON.stringify({
    schemaVersion: 1,
    stages: [
      {
        id: "st-evidence",
        type: "EVIDENCE",
        title: "Bằng chứng",
        required: true,
        nextStageIds: ["st-reasoning"],
        activities: [
          {
            id: "act-mc",
            type: "MULTIPLE_CHOICE",
            required: true,
            instruction: "Chọn yếu tố then chốt",
            config: {
              question: variant === 1 ? "Yếu tố nào quyết định?" : "Điều gì lặp lại?",
              options: [
                { id: "o-tide", label: "Thủy triều" },
                { id: "o-wind", label: "Gió" },
                { id: "o-fog", label: "Sương mù" },
              ],
              correctOptionIds: ["o-tide"],
              multiSelect: false,
              visibleEvidenceIds: [EV_ID],
            },
          },
        ],
      },
      {
        id: "st-reasoning",
        type: "REASONING",
        title: "Ghép nối",
        required: true,
        nextStageIds: ["st-reconstruction"],
        activities: [
          {
            id: "act-match",
            type: "MATCHING",
            required: true,
            instruction: "Nối nhân vật — vai trò",
            config: {
              pairs: [
                { left: { id: "l-ngo", label: "Ngô Quyền" }, right: { id: "r-cot", label: "Chủ soái" } },
                { left: { id: "l-kieu", label: "Kiều Công Tiễn" }, right: { id: "r-ally", label: "Cầu viện Nam Hán" } },
                { left: { id: "l-hoan", label: "Lưu Hoằng Tháo" }, right: { id: "r-dead", label: "Chết trận" } },
              ],
              correctPairs: [
                { left: "l-ngo", right: "r-cot" },
                { left: "l-kieu", right: "r-ally" },
                { left: "l-hoan", right: "r-dead" },
              ],
            },
          },
        ],
      },
      {
        id: "st-reconstruction",
        type: "RECONSTRUCTION",
        title: "Tái dựng",
        required: true,
        nextStageIds: [],
        activities: [
          {
            id: "act-order",
            type: "DRAG_ORDER",
            required: true,
            instruction: "Sắp xếp diễn biến",
            config: {
              items: [
                { id: "it-1", label: "Nam Hán vào cửa sông lúc triều lên" },
                { id: "it-2", label: "Triều xuống, thuyền vướng cọc" },
                { id: "it-3", label: "Ngô Quyền phản công" },
              ],
              expectedOrder: ["it-1", "it-2", "it-3"],
            },
          },
        ],
      },
    ],
    completion: { requireAllRequiredStages: true },
  });
}

test("publish journey: same-event full path with MC + MATCHING + DRAG_ORDER", async ({
  page,
}) => {
  test.setTimeout(300_000);
  await login(page);

  // 1) Same-event: create + publish the event, lesson must bind to THAT id.
  const eventTitle = "Hải chiến Bạch Đằng e2e";
  await createAndPublishEvent(page, eventTitle, "bach-dang-e2e-full");

  // 2) Lesson on that exact event (title picked in wizard step 1).
  const lessonId = await createLessonOnEvent(page, eventTitle, "E2E — full journey");

  // 3) Seed the draft via the real API: MC + MATCHING + DRAG_ORDER +
  //    EVIDENCE reference so evidence embedding can be asserted.
  const detail = await page.request.get(`/api/proxy/admin/lessons/${lessonId}`);
  const rowVersion = ((await detail.json()) as { rowVersion: number }).rowVersion;
  await seedDraft(page, lessonId, complexDraft(1), rowVersion);

  // 4) Preview — learner projection must render every activity shape.
  await page.goto(`/lessons/${lessonId}/preview`);
  await expect(page.getByText(/chế độ xem trước/i)).toBeVisible({ timeout: 30_000 });
  await expect(page.getByText("Yếu tố nào quyết định?")).toBeVisible({ timeout: 15_000 });
  // MC radio (single mode) — no answer marker in DOM.
  await expect(page.getByText("Thủy triều")).toBeVisible();
  // Evidence title resolves from embedded doc — not a bare uuid label.
  await page.getByRole("tab", { name: /ghép nối/i }).click();
  await expect(page.getByText("Ngô Quyền")).toBeVisible();
  // MATCHING: two independent columns, never a paired row.
  const matchSection = page.locator(".grid.grid-cols-2");
  await expect(matchSection.getByText("Chủ soái")).toBeVisible();
  await page.getByRole("tab", { name: /tái dựng/i }).click();
  await expect(page.getByText("Sắp xếp diễn biến")).toBeVisible();
  // Reorder in preview → move the LAST item up; state is preview-local.
  const orderRows = page.locator(".flex.items-center.gap-2.rounded-md.border.border-border");
  const lastLabel = await orderRows.last().locator(".flex-1").innerText();
  // Anchor at end: the item label itself may contain "lên" (e.g. "triều lên"),
  // which would also match the "xuống" button's accessible name.
  await orderRows.last().getByRole("button", { name: /lên$/i }).click();
  // After the move the same row index holds a different label.
  expect(await orderRows.nth(1).locator(".flex-1").innerText()).toBe(lastLabel);
  // Navigate away + back → remount resets to the projected display order.
  await page.getByRole("tab", { name: /ghép nối/i }).click();
  await page.getByRole("tab", { name: /tái dựng/i }).click();
  await expect(page.getByText("Sắp xếp diễn biến")).toBeVisible();
  // Row 2 shows its original projected item again — local reorder is gone.
  await expect(orderRows.nth(1).locator(".flex-1")).not.toHaveText(lastLabel);
  // No hidden key may reach the DOM.
  const html = await page.content();
  for (const k of [
    "correctOptionIds",
    "multiCorrect",
    "correctPairs",
    "expectedOrder",
    "requiredEvidenceIds",
    "\"pairs\"",
  ]) {
    expect(html).not.toContain(k);
  }

  // 5) Validate → publish → v1.
  await page.goto(`/lessons/${lessonId}/publish`);
  await page.getByRole("button", { name: /kiểm tra xuất bản/i }).click();
  await expect(page.getByText(/đủ điều kiện xuất bản/i)).toBeVisible({ timeout: 15_000 });
  await page.getByRole("button", { name: /xuất bản bài học/i }).click();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  await expect(page.getByText(/đã xuất bản phiên bản 1 thành công/i)).toBeVisible({
    timeout: 15_000,
  });

  // 6) Learner content — versionNo 1, authored shape, structural non-reveal.
  await page.getByRole("button", { name: /kiểm tra nội dung learner/i }).click();
  await expect(page.getByText(/phiên bản 1 đang phát hành/i)).toBeVisible({ timeout: 15_000 });
  const contentRes = await learnerContent(page, lessonId);
  const learner = (await contentRes.json()) as { content: Record<string, unknown> };
  const content = learner.content;
  const serialized = JSON.stringify(content);
  expect(serialized).not.toContain("correctOptionIds");
  expect(serialized).not.toContain("multiCorrect");
  expect(serialized).not.toContain("correctPairs");
  expect(serialized).not.toContain("expectedOrder");
  // MATCHING: pairs[] removed, leftItems/rightItems emitted independently.
  const stages = content.stages as { id: string; activities: { id: string; type: string; config: Record<string, unknown> }[] }[];
  const matching = stages
    .flatMap((s) => s.activities)
    .find((a) => a.type === "MATCHING");
  expect(matching).toBeDefined();
  expect(matching!.config.pairs).toBeUndefined();
  const leftItems = matching!.config.leftItems as { id: string }[];
  const rightItems = matching!.config.rightItems as { id: string }[];
  expect(leftItems.map((x) => x.id).sort()).toEqual(["l-hoan", "l-kieu", "l-ngo"]);
  expect(rightItems.map((x) => x.id).sort()).toEqual(["r-ally", "r-cot", "r-dead"]);
  // Structural non-reveal: zipping index i → authored partner must not hold
  // for every row (left asc, right desc ⇒ mapping can't be reconstructed).
  const authored = { "l-ngo": "r-cot", "l-kieu": "r-ally", "l-hoan": "r-dead" } as Record<string, string>;
  const zipped = leftItems.every((l, i) => authored[l.id] === rightItems[i]!.id);
  expect(zipped).toBe(false);
  // DRAG_ORDER: items present but never in expectedOrder sequence.
  const drag = stages.flatMap((s) => s.activities).find((a) => a.type === "DRAG_ORDER");
  const items = (drag!.config.items as { id: string }[]).map((x) => x.id);
  expect([...items].sort()).toEqual(["it-1", "it-2", "it-3"]);
  // Presentation order must differ from the authored/expected sequence.
  expect(items).not.toEqual(["it-1", "it-2", "it-3"]);
  // Evidence doc embedded — learner sees title, not just an id.
  const embedded = content.evidence as { id: string; title: string }[];
  expect(embedded.some((e) => e.id === EV_ID && e.title.length > 0)).toBe(true);

  // 7) Draft edit does NOT touch the published snapshot.
  const v1 = await learnerContent(page, lessonId);
  const snap1 = ((await v1.json()) as { content: Record<string, unknown> }).content;
  await seedDraft(page, lessonId, complexDraft(2), await currentRowVersion(page, lessonId));
  const still = await learnerContent(page, lessonId);
  const snapStill = ((await still.json()) as { content: Record<string, unknown> }).content;
  expect(snapStill).toEqual(snap1);

  // 8) Republish → versionNo 2 with the NEW draft content.
  await page.goto(`/lessons/${lessonId}/publish`);
  await page.getByRole("button", { name: /xuất bản phiên bản mới/i }).click();
  await page.getByRole("button", { name: /^xuất bản$/i }).click();
  await expect(page.getByText(/đã xuất bản phiên bản 2 thành công/i)).toBeVisible({
    timeout: 15_000,
  });
  const v2 = await learnerContent(page, lessonId);
  const body2 = (await v2.json()) as { versionNo: number; content: Record<string, unknown> };
  expect(body2.versionNo).toBe(2);
  expect(JSON.stringify(body2.content)).toContain("Điều gì lặp lại?");
});

test("publish blocked when parent event is still DRAFT", async ({ page }) => {
  test.setTimeout(240_000);
  await login(page);

  // Event mới ở DRAFT — KHÔNG publish. Lesson gắn eventId của event nháp để
  // publish bị chặn với EVENT_NOT_PUBLISHED.
  await page.goto("/events/new");
  await page.getByLabel(/tiêu đề/i).fill("Sự kiện nháp e2e");
  await page.getByLabel(/slug/i).fill("draft-event-e2e");
  await page.getByLabel(/tóm tắt/i).fill("Sự kiện e2e nháp");
  await page.getByRole("button", { name: /tạo sự kiện/i }).click();
  await expect(page).toHaveURL(/\/events\/[0-9a-f-]{36}$/, { timeout: 30_000 });

  const lessonId = await createLessonOnEvent(page, "Sự kiện nháp e2e", "E2E — event nháp chặn publish");
  const detail = await page.request.get(`/api/proxy/admin/lessons/${lessonId}`);
  const rowVersion = ((await detail.json()) as { rowVersion: number }).rowVersion;
  await seedDraft(page, lessonId, complexDraft(1), rowVersion);

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

async function currentRowVersion(page: Page, lessonId: string): Promise<number> {
  const res = await page.request.get(`/api/proxy/admin/lessons/${lessonId}`);
  return ((await res.json()) as { rowVersion: number }).rowVersion;
}
