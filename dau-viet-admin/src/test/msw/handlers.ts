import { http, HttpResponse } from "msw";

import {
  adminUserFixture,
  animationScenesPageFixture,
  assetsPageFixture,
  draftFixture,
  emptyPageFixture,
  eventsPageFixture,
  evidencesPageFixture,
  lessonsPageFixture,
  templatesFixture,
} from "../fixtures";

/**
 * MSW mirror of the backend learner projection — keep in sync with
 * LearnerProjectionService: hidden keys stripped, MATCHING pairs →
 * leftItems/rightItems, DRAG_ORDER items re-shuffled deterministically,
 * evidence[]/assets[] embedded for ids the draft references.
 */
const HIDDEN_CONFIG_KEYS = new Set([
  "correctOptionIds",
  "multiCorrect",
  "correctPairs",
  "correctOrder",
  "expectedOrder",
  "acceptedSequences",
  "requiredEvidenceIds",
  "expectedHypothesis",
  "answerKey",
  "answer",
  "key",
  "expected",
]);

type AnyObj = Record<string, unknown>;

function stripHiddenDeep(value: unknown): void {
  if (Array.isArray(value)) {
    value.forEach(stripHiddenDeep);
    return;
  }
  if (!value || typeof value !== "object") return;
  const o = value as AnyObj;
  for (const k of Object.keys(o)) {
    if (HIDDEN_CONFIG_KEYS.has(k)) delete o[k];
    else stripHiddenDeep(o[k]);
  }
}

function itemOf(raw: unknown): { id: string; label: string } | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as AnyObj;
  const id = String(r.id ?? "");
  if (!id) return null;
  return { id, label: String(r.label ?? r.text ?? "") };
}

/** Deterministic pseudo key — mirrors Objects.hash ordering spirit. */
function sortKey(activityId: string, itemId: string): number {
  const s = `${activityId}|${itemId}`;
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(h, 31) + s.charCodeAt(i)) | 0;
  return h;
}

function transformActivity(a: AnyObj): void {
  const cfg = a.config as AnyObj | undefined;
  if (!cfg) return;
  const activityId = String(a.id ?? "");
  if (a.type === "MATCHING" && Array.isArray(cfg.pairs)) {
    const left: { id: string; label: string }[] = [];
    let right: { id: string; label: string }[] = [];
    const partnerByLeft = new Map<string, string>();
    for (const p of cfg.pairs as AnyObj[]) {
      const l = itemOf(p?.left);
      const r = itemOf(p?.right);
      if (l) left.push(l);
      if (r) right.push(r);
      if (l && r) partnerByLeft.set(l.id, r.id);
    }
    // Mirror LearnerProjectionService: right column is deranged against the
    // real mapping — rotate by the first offset where no row is a correct pair.
    left.sort((x, y) => sortKey(activityId, x.id) - sortKey(activityId, y.id));
    right.sort((x, y) => sortKey(activityId, x.id) - sortKey(activityId, y.id));
    const n = Math.min(left.length, right.length);
    if (n >= 2) {
      const rightIds = right.map((x) => x.id);
      let chosen = -1;
      for (let offset = 1; offset < n && chosen < 0; offset++) {
        let ok = true;
        for (let i = 0; i < n; i++) {
          if (rightIds[(i + offset) % n] === partnerByLeft.get(left[i]!.id)) {
            ok = false;
            break;
          }
        }
        if (ok) chosen = offset;
      }
      right =
        chosen >= 0
          ? right.map((_, i) => right[(i + chosen) % right.length]!)
          : [...right].sort(
              (x, y) =>
                sortKey(`${activityId}#r`, x.id) - sortKey(`${activityId}#r`, y.id),
            );
    }
    delete cfg.pairs;
    cfg.leftItems = left;
    cfg.rightItems = right;
  }
  if (a.type === "DRAG_ORDER" && Array.isArray(cfg.items)) {
    const items = (cfg.items as AnyObj[]).map((it) => it);
    items.sort(
      (x, y) =>
        sortKey(activityId, String(x.id ?? "")) - sortKey(activityId, String(y.id ?? "")),
    );
    const projected = items.map((it) => String(it.id ?? ""));
    const expected =
      (Array.isArray(cfg.expectedOrder) ? (cfg.expectedOrder as unknown[]) : null) ??
      (Array.isArray(cfg.correctOrder) ? (cfg.correctOrder as unknown[]) : null) ??
      (cfg.items as AnyObj[]).map((it) => it.id);
    const answer = (expected as unknown[]).map((x) => String(x ?? ""));
    if (projected.length >= 2 && JSON.stringify(projected) === JSON.stringify(answer)) {
      items.reverse();
    }
    cfg.items = items;
  }
  // MULTIPLE_CHOICE legacy compat — mirror LearnerProjectionService.
  if (
    a.type === "MULTIPLE_CHOICE" &&
    cfg.multiSelect === undefined &&
    Array.isArray(cfg.multiCorrect) &&
    cfg.multiCorrect.length > 1
  ) {
    cfg.multiSelect = true;
  }
}

function collectIds(node: unknown, field: string, out: Set<string>): void {
  if (!node || typeof node !== "object") return;
  const v = (node as AnyObj)[field];
  if (Array.isArray(v)) v.forEach((x) => out.add(String(x ?? "")));
}

function embedEvidence(draft: AnyObj): AnyObj[] {
  const ids = new Set<string>();
  for (const s of (draft.stages as AnyObj[]) ?? []) {
    for (const a of (s.activities as AnyObj[]) ?? []) {
      collectIds(a, "evidenceRefs", ids);
      const cfg = a.config as AnyObj | undefined;
      if (cfg) {
        collectIds(cfg, "visibleEvidenceIds", ids);
        collectIds(cfg, "requiredEvidenceIds", ids);
        collectIds(cfg, "visibleSourceIds", ids);
      }
    }
    collectIds(s, "requiredEvidenceIds", ids);
  }
  return evidencesPageFixture.content
    .filter((e) => ids.has(e.id))
    .map((e) => ({
      id: e.id,
      title: e.title,
      evidenceType: e.evidenceType,
      description: e.description ?? undefined,
      source: {
        title: e.sourceTitle,
        author: e.sourceAuthor ?? undefined,
        url: e.sourceUrl ?? undefined,
        citation: e.sourceCitation ?? undefined,
      },
      reliability: e.reliability ?? undefined,
      relevance: e.relevance ?? undefined,
      assetId: e.assetId ?? undefined,
    }));
}

function embedAssets(evidence: AnyObj[], draft: AnyObj): AnyObj[] {
  const ids = new Set<string>();
  for (const e of evidence) if (e.assetId) ids.add(String(e.assetId));
  for (const s of (draft.stages as AnyObj[]) ?? []) {
    for (const a of (s.activities as AnyObj[]) ?? []) {
      const cfg = a.config as AnyObj | undefined;
      if (cfg?.imageAssetId) ids.add(String(cfg.imageAssetId));
    }
  }
  return assetsPageFixture.content
    .filter((a) => ids.has(a.id))
    .map((a) => ({
      id: a.id,
      storageKey: a.contentUrl,
      mimeType: a.mimeType,
      sizeBytes: a.sizeBytes,
      originalFilename: a.originalFilename,
      altText: a.altText ?? undefined,
    }));
}

/** Full learner-facing projection: transform + strip + embed. */
function projectDraft(draftJson: string): AnyObj {
  const draft = JSON.parse(draftJson) as AnyObj;
  const evidence = embedEvidence(draft);
  const assets = embedAssets(evidence, draft);
  for (const s of (draft.stages as AnyObj[]) ?? []) {
    delete s.requiredEvidenceIds;
    for (const a of (s.activities as AnyObj[]) ?? []) {
      transformActivity(a);
      delete a.validation;
      delete a.evidenceRefs;
      stripHiddenDeep(a.config);
      stripHiddenDeep(a.feedback);
    }
  }
  draft.evidence = evidence;
  draft.assets = assets;
  return draft;
}

/**
 * Default stubs for component tests. MSW intercepts the BROWSER-FACING URLs
 * (/api/auth/*, /api/proxy/*), not the upstream backend — the proxy route is a
 * server-side boundary and never runs in jsdom.
 * Individual tests override with server.use(...) for error/edge cases.
 */
export const handlers = [
  // BFF auth routes (browser-facing)
  http.post("*/api/auth/login", () =>
    HttpResponse.json({ accessToken: "test-access-token", expiresIn: 900 }),
  ),
  http.post("*/api/auth/refresh", () =>
    HttpResponse.json({ accessToken: "test-access-token", expiresIn: 900 }),
  ),
  http.post("*/api/auth/logout", () => new HttpResponse(null, { status: 204 })),
  http.get("*/api/auth/session", () =>
    HttpResponse.json({ user: adminUserFixture, accessToken: "t", expiresIn: 900 }),
  ),

  // BFF proxy → backend (client calls /api/proxy/<path>)
  http.get("*/api/proxy/users/me", () => HttpResponse.json(adminUserFixture)),
  http.get("*/api/proxy/admin/ping", () => HttpResponse.json({ status: "ok" })),
  http.get("*/api/proxy/admin/events", () => HttpResponse.json(eventsPageFixture)),
  http.post("*/api/proxy/admin/events", async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(
      {
        id: "99999999-9999-9999-9999-999999999999",
        slug: body.slug,
        title: body.title,
        era: body.era ?? null,
        period: body.period ?? null,
        startYear: body.startYear ?? null,
        summary: body.summary,
        description: body.description ?? null,
        location: body.location ?? null,
        coverAssetKey: body.coverAssetKey ?? null,
        tags: body.tags ?? [],
        status: "DRAFT",
        rowVersion: 1,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      { status: 201 },
    );
  }),
  http.get("*/api/proxy/admin/events/:id", ({ params }) => {
    const ev = eventsPageFixture.content.find((e) => e.id === params.id);
    if (!ev) return HttpResponse.json({ code: "EVENT_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({
      ...ev,
      period: null,
      summary: "Tóm tắt sự kiện",
      description: null,
      location: null,
      coverAssetKey: null,
      rowVersion: 1,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    });
  }),
  http.patch("*/api/proxy/admin/events/:id", async ({ params, request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    const ev = eventsPageFixture.content.find((e) => e.id === params.id);
    if (!ev) return HttpResponse.json({ code: "EVENT_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({
      ...ev,
      ...body,
      period: null,
      summary: body.summary ?? "Tóm tắt sự kiện",
      description: body.description ?? null,
      location: body.location ?? null,
      coverAssetKey: body.coverAssetKey ?? null,
      rowVersion: (ev as { rowVersion?: number }).rowVersion ?? 2,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-02T00:00:00Z",
    });
  }),
  http.get("*/api/proxy/admin/lessons", () => HttpResponse.json(lessonsPageFixture)),
  http.post("*/api/proxy/admin/lessons", async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(
      {
        id: "88888888-8888-8888-8888-888888888888",
        eventId: body.eventId,
        templateId: body.templateId,
        title: body.title,
        centralQuestion: body.centralQuestion,
        objectivesJson: body.objectivesJson ?? "[]",
        draftJson: body.draftJson ?? "{}",
        status: "DRAFT",
        currentVersionId: null,
        rowVersion: 1,
        createdBy: adminUserFixture.id,
        updatedBy: adminUserFixture.id,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      { status: 201 },
    );
  }),
  http.get("*/api/proxy/admin/lessons/:id", ({ params }) => {
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({
      ...l,
      templateId: templatesFixture[0]!.id,
      centralQuestion: "Vì sao Ngô Quyền thắng?",
      objectivesJson: '["Hiểu bối cảnh lịch sử"]',
      draftJson: draftFixture,
      createdBy: adminUserFixture.id,
      updatedBy: adminUserFixture.id,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    });
  }),
  http.patch("*/api/proxy/admin/lessons/:id", async ({ params, request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({
      ...l,
      ...body,
      templateId: templatesFixture[0]!.id,
      centralQuestion: body.centralQuestion ?? "Vì sao Ngô Quyền thắng?",
      objectivesJson: body.objectivesJson ?? "[]",
      draftJson: "{}",
      rowVersion: l.rowVersion + 1,
      createdBy: adminUserFixture.id,
      updatedBy: adminUserFixture.id,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-02T00:00:00Z",
    });
  }),
  http.put("*/api/proxy/admin/lessons/:id/draft", async ({ params, request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    if (typeof body.draftJson !== "string") {
      return HttpResponse.json({ code: "DRAFT_SCHEMA_INVALID" }, { status: 422 });
    }
    return HttpResponse.json({
      id: l.id,
      eventId: l.eventId,
      templateId: templatesFixture[0]!.id,
      title: l.title,
      centralQuestion: "Vì sao Ngô Quyền thắng?",
      objectivesJson: "[]",
      draftJson: body.draftJson,
      status: l.status,
      currentVersionId: l.currentVersionId,
      rowVersion: ((body.expectedRowVersion as number | undefined) ?? l.rowVersion) + 1,
      createdBy: adminUserFixture.id,
      updatedBy: adminUserFixture.id,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-02T00:00:00Z",
    });
  }),
  http.post("*/api/proxy/admin/lessons/:id/validate", ({ params }) => {
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({
      ready: false,
      errors: [
        {
          path: "stages[3]",
          code: "NO_REQUIRED_ACTIVITY",
          message: "Giai đoạn bắt buộc cần ít nhất một hoạt động bắt buộc",
        },
      ],
      warnings: [],
      // Backend contract: summary is Map<String,Object>, not a string.
      summary: {
        stageCount: 4,
        activityCount: 3,
        evidenceRefs: 0,
        schemaVersion: 1,
        errorCount: 1,
        warningCount: 0,
      },
    });
  }),
  http.post("*/api/proxy/admin/lessons/:id/preview", ({ params }) => {
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({
      lessonId: l.id,
      lessonVersionId: null,
      versionNo: null,
      content: projectDraft(draftFixture),
    });
  }),
  http.post("*/api/proxy/admin/lessons/:id/publish", async ({ params, request }) => {
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    const body = (await request.json().catch(() => ({}))) as Record<string, unknown>;
    if (
      body?.expectedRowVersion !== undefined &&
      body.expectedRowVersion !== l.rowVersion
    ) {
      return HttpResponse.json(
        { code: "OPTIMISTIC_LOCK_CONFLICT", message: "conflict" },
        { status: 409 },
      );
    }
    return HttpResponse.json({
      lessonId: l.id,
      lessonVersionId: "v-" + l.id.slice(0, 8),
      versionNo: l.status === "PUBLISHED" ? 2 : 1,
      status: "PUBLISHED",
      publishedAt: "2026-01-02T00:00:00Z",
    });
  }),
  http.get("*/api/proxy/lessons/:id/content", ({ params }) => {
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l || l.status !== "PUBLISHED") {
      return HttpResponse.json({ code: "LESSON_NOT_PUBLISHED" }, { status: 404 });
    }
    return HttpResponse.json({
      lessonId: l.id,
      lessonVersionId: l.currentVersionId,
      versionNo: 1,
      content: projectDraft(draftFixture),
    });
  }),
  http.post("*/api/proxy/admin/lessons/:id/archive", ({ params }) => {
    const l = lessonsPageFixture.content.find((x) => x.id === params.id);
    if (!l) return HttpResponse.json({ code: "LESSON_NOT_FOUND" }, { status: 404 });
    if (l.status === "ARCHIVED") {
      return HttpResponse.json(
        { code: "INVALID_STATUS_TRANSITION", message: "already archived" },
        { status: 409 },
      );
    }
    return HttpResponse.json({ ...l, status: "ARCHIVED", rowVersion: l.rowVersion + 1 });
  }),
  http.post("*/api/proxy/admin/events/:id/publish", ({ params }) => {
    const ev = eventsPageFixture.content.find((e) => e.id === params.id);
    if (!ev) return HttpResponse.json({ code: "EVENT_NOT_FOUND" }, { status: 404 });
    if (ev.status !== "DRAFT") {
      return HttpResponse.json(
        { code: "INVALID_STATUS_TRANSITION", message: "not draft" },
        { status: 409 },
      );
    }
    return HttpResponse.json({
      ...ev,
      period: null,
      summary: "Tóm tắt sự kiện",
      description: null,
      location: null,
      coverAssetKey: null,
      status: "PUBLISHED",
      rowVersion: 2,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-02T00:00:00Z",
    });
  }),
  http.post("*/api/proxy/admin/events/:id/archive", ({ params }) => {
    const ev = eventsPageFixture.content.find((e) => e.id === params.id);
    if (!ev) return HttpResponse.json({ code: "EVENT_NOT_FOUND" }, { status: 404 });
    if (ev.status === "ARCHIVED") {
      return HttpResponse.json(
        { code: "INVALID_STATUS_TRANSITION", message: "already archived" },
        { status: 409 },
      );
    }
    // Backend contract: block khi còn bài học chưa lưu trữ (EventInUseException).
    const hasActiveLessons = lessonsPageFixture.content.some(
      (l) => l.eventId === ev.id && l.status !== "ARCHIVED",
    );
    if (hasActiveLessons) {
      return HttpResponse.json(
        {
          code: "EVENT_IN_USE",
          message: "event still has non-archived lessons; archive them first",
        },
        { status: 409 },
      );
    }
    return HttpResponse.json({ ...ev, status: "ARCHIVED", rowVersion: 2 });
  }),
  http.get("*/api/proxy/admin/lesson-templates", () =>
    HttpResponse.json(templatesFixture),
  ),
  // Evidence library
  http.get("*/api/proxy/admin/evidences", ({ request }) => {
    const url = new URL(request.url);
    const status = url.searchParams.get("status");
    const eventId = url.searchParams.get("eventId");
    const q = (url.searchParams.get("q") ?? "").toLowerCase();
    let content = evidencesPageFixture.content;
    if (status) content = content.filter((e) => e.status === status);
    if (eventId) content = content.filter((e) => e.eventId === eventId);
    if (q) content = content.filter((e) => e.title.toLowerCase().includes(q));
    return HttpResponse.json({
      ...emptyPageFixture,
      content,
      totalElements: content.length,
      totalPages: content.length ? 1 : 0,
    });
  }),
  http.get("*/api/proxy/admin/evidences/:id", ({ params }) => {
    const e = evidencesPageFixture.content.find((x) => x.id === params.id);
    if (!e) return HttpResponse.json({ code: "EVIDENCE_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json(e);
  }),
  http.post("*/api/proxy/admin/evidences", async ({ request }) => {
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json(
      {
        id: "e9999999-9999-9999-9999-999999999999",
        ...body,
        status: "DRAFT",
        createdBy: adminUserFixture.id,
        createdAt: "2026-01-03T00:00:00Z",
        updatedAt: "2026-01-03T00:00:00Z",
        rowVersion: 1,
      },
      { status: 201 },
    );
  }),
  http.patch("*/api/proxy/admin/evidences/:id", async ({ params, request }) => {
    const e = evidencesPageFixture.content.find((x) => x.id === params.id);
    if (!e) return HttpResponse.json({ code: "EVIDENCE_NOT_FOUND" }, { status: 404 });
    const body = (await request.json()) as Record<string, unknown>;
    return HttpResponse.json({ ...e, ...body, rowVersion: e.rowVersion + 1 });
  }),
  http.post("*/api/proxy/admin/evidences/:id/approve", ({ params }) => {
    const e = evidencesPageFixture.content.find((x) => x.id === params.id);
    if (!e) return HttpResponse.json({ code: "EVIDENCE_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({ ...e, status: "APPROVED", rowVersion: e.rowVersion + 1 });
  }),
  http.post("*/api/proxy/admin/evidences/:id/archive", ({ params }) => {
    const e = evidencesPageFixture.content.find((x) => x.id === params.id);
    if (!e) return HttpResponse.json({ code: "EVIDENCE_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json({ ...e, status: "ARCHIVED", rowVersion: e.rowVersion + 1 });
  }),

  // Asset library
  http.get("*/api/proxy/admin/assets", () => HttpResponse.json(assetsPageFixture)),
  http.get("*/api/proxy/admin/assets/:id", ({ params }) => {
    const a = assetsPageFixture.content.find((x) => x.id === params.id);
    if (!a) return HttpResponse.json({ code: "ASSET_NOT_FOUND" }, { status: 404 });
    return HttpResponse.json(a);
  }),
  http.post("*/api/proxy/admin/assets", async () =>
    HttpResponse.json(assetsPageFixture.content[0], { status: 201 }),
  ),

  /* ---------- Animation scenes (builder picker) ---------- */
  http.get("*/api/proxy/admin/animation-scenes", ({ request }) => {
    const url = new URL(request.url);
    const status = url.searchParams.get("status");
    const q = (url.searchParams.get("q") ?? "").toLowerCase();
    let rows = animationScenesPageFixture.content;
    if (status) rows = rows.filter((s) => s.status === status);
    if (q) rows = rows.filter((s) => s.title.toLowerCase().includes(q));
    return HttpResponse.json({
      ...animationScenesPageFixture,
      content: rows,
      totalElements: rows.length,
    });
  }),
  http.get("*/api/proxy/admin/animation-scenes/:id", ({ params }) => {
    const s = animationScenesPageFixture.content.find((x) => x.id === params.id);
    if (!s) {
      return HttpResponse.json(
        { code: "ANIMATION_SCENE_NOT_FOUND", message: "not found" },
        { status: 404 },
      );
    }
    return HttpResponse.json({
      ...s,
      templateCode: s.rendererCode,
      draftJson: "{}",
      createdBy: adminUserFixture.id,
      updatedBy: adminUserFixture.id,
      createdAt: s.updatedAt,
    });
  }),
];
