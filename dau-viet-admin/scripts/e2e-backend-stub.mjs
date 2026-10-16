/**
 * Controlled backend stub for Playwright e2e — a plain node:http server that
 * answers the /api/v1 surface the admin needs. NOT the real Spring Boot
 * backend; it keeps a small in-memory store so the authoring flow
 * (login → create event → create lesson → reopen) can be exercised
 * end-to-end in a real browser.
 *
 * Start: `node scripts/e2e-backend-stub.mjs` (listens on :8081 by default).
 */
import http from "node:http";
import crypto from "node:crypto";

const PORT = Number(process.env.BACKEND_STUB_PORT ?? 8081);

const TOKENS = {
  accessToken: "e2e-access-token",
  tokenType: "Bearer",
  expiresIn: 900,
  refreshToken: "e2e-refresh-token",
  refreshExpiresIn: 1209600,
};

const ADMIN = {
  id: "11111111-1111-1111-1111-111111111111",
  email: "admin@dauviet.local",
  displayName: "Quản trị viên E2E",
  role: "CONTENT_ADMIN",
  status: "ACTIVE",
  emailVerifiedAt: null,
  createdAt: "2026-01-01T00:00:00Z",
};

const NOW = "2026-01-01T00:00:00Z";
const EMPTY_PAGE = { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0 };

// In-memory store — reset on each stub start.
const events = [
  {
    id: "11111111-1111-1111-1111-111111111111",
    slug: "tran-bach-dang-938",
    title: "Trận Bạch Đằng 938",
    era: "Bắc thuộc lần 3",
    period: "Mùa Đông 938",
    startYear: 938,
    summary: "Ngô Quyền đánh bại quân Nam Hán trên sông Bạch Đằng.",
    description: null,
    location: "Sông Bạch Đằng",
    coverAssetKey: null,
    tags: ["ngô-quyền"],
    status: "PUBLISHED",
    rowVersion: 1,
    createdAt: NOW,
    updatedAt: NOW,
  },
];
const lessons = [];
const templates = [
  {
    id: "66666666-6666-6666-6666-666666666666",
    code: "EVENT_INVESTIGATION",
    name: "Điều tra sự kiện",
    description: "Khung stage chuẩn cho bài điều tra sự kiện lịch sử",
    schemaVersion: 1,
    presetJson: JSON.stringify({
      schemaVersion: 1,
      stages: [
        {
          id: "tpl-context",
          type: "CONTEXT",
          title: "Bối cảnh (mẫu)",
          required: true,
          nextStageIds: ["tpl-evidence"],
          activities: [
            {
              id: "tpl-act-read",
              type: "READ",
              required: false,
              instruction: "Đọc tư liệu nền",
              config: { text: "Nội dung mẫu…" },
            },
          ],
        },
        {
          id: "tpl-evidence",
          type: "EVIDENCE",
          title: "Bằng chứng (mẫu)",
          required: true,
          nextStageIds: [],
          activities: [],
        },
      ],
    }),
    enabled: true,
    createdAt: NOW,
    updatedAt: NOW,
  },
];

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json" });
  res.end(payload);
}

function readBody(req) {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        resolve(JSON.parse(body || "{}"));
      } catch {
        resolve(null);
      }
    });
  });
}

function pageOf(content, url) {
  return {
    content,
    page: 0,
    size: Number(url.searchParams.get("size") ?? 20),
    totalElements: content.length,
    totalPages: content.length === 0 ? 0 : 1,
  };
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url ?? "/", `http://localhost:${PORT}`);
  const path = url.pathname;
  const m = req.method;

  // --- auth ---
  if (m === "POST" && path === "/api/v1/auth/login") {
    const body = await readBody(req);
    if (body?.email === "admin@dauviet.local" && body?.password === "secret") {
      return json(res, 200, TOKENS);
    }
    return json(res, 401, { code: "INVALID_CREDENTIALS", message: "bad credentials" });
  }
  if (m === "POST" && path === "/api/v1/auth/refresh") return json(res, 200, TOKENS);
  if (m === "POST" && path === "/api/v1/auth/logout") {
    res.writeHead(204);
    return res.end();
  }
  if (m === "GET" && path === "/api/v1/users/me") return json(res, 200, ADMIN);
  if (m === "GET" && path === "/api/v1/admin/ping") return json(res, 200, { status: "ok" });

  // --- admin/events ---
  if (path === "/api/v1/admin/events") {
    if (m === "GET") {
      const q = (url.searchParams.get("q") ?? "").toLowerCase();
      const status = url.searchParams.get("status");
      let rows = events;
      if (q) rows = rows.filter((e) => e.title.toLowerCase().includes(q));
      if (status) rows = rows.filter((e) => e.status === status);
      return json(res, 200, pageOf(rows, url));
    }
    if (m === "POST") {
      const body = await readBody(req);
      if (!body || !body.slug || !body.title || !body.summary) {
        return json(res, 400, { code: "VALIDATION_ERROR", message: "missing fields" });
      }
      if (events.some((e) => e.slug === body.slug)) {
        return json(res, 409, {
          code: "DUPLICATE_SLUG",
          message: "slug đã tồn tại",
        });
      }
      const ev = {
        id: crypto.randomUUID(),
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
        createdAt: NOW,
        updatedAt: NOW,
      };
      events.push(ev);
      return json(res, 201, ev);
    }
  }
  const evMatch = path.match(/^\/api\/v1\/admin\/events\/([0-9a-f-]+)$/);
  if (evMatch) {
    const ev = events.find((e) => e.id === evMatch[1]);
    if (!ev) return json(res, 404, { code: "EVENT_NOT_FOUND", message: "not found" });
    if (m === "GET") return json(res, 200, ev);
    if (m === "PATCH") {
      const body = await readBody(req);
      if (body?.expectedRowVersion !== undefined && body.expectedRowVersion !== ev.rowVersion) {
        return json(res, 409, {
          code: "OPTIMISTIC_LOCK_CONFLICT",
          message: "modified concurrently",
        });
      }
      Object.assign(ev, {
        title: body.title ?? ev.title,
        slug: body.slug ?? ev.slug,
        era: body.era ?? ev.era,
        period: body.period ?? ev.period,
        startYear: body.startYear ?? ev.startYear,
        summary: body.summary ?? ev.summary,
        description: body.description ?? ev.description,
        location: body.location ?? ev.location,
        coverAssetKey: body.coverAssetKey ?? ev.coverAssetKey,
        tags: body.tags ?? ev.tags,
        rowVersion: ev.rowVersion + 1,
        updatedAt: NOW,
      });
      return json(res, 200, ev);
    }
  }

  // --- admin/lessons ---
  if (path === "/api/v1/admin/lessons") {
    if (m === "GET") {
      const eventId = url.searchParams.get("eventId");
      let rows = lessons;
      if (eventId) rows = rows.filter((l) => l.eventId === eventId);
      return json(res, 200, pageOf(rows, url));
    }
    if (m === "POST") {
      const body = await readBody(req);
      if (!body || !body.eventId || !body.templateId || !body.title || !body.centralQuestion) {
        return json(res, 400, { code: "VALIDATION_ERROR", message: "missing fields" });
      }
      const lesson = {
        id: crypto.randomUUID(),
        eventId: body.eventId,
        templateId: body.templateId,
        title: body.title,
        centralQuestion: body.centralQuestion,
        objectivesJson: body.objectivesJson ?? "[]",
        draftJson: body.draftJson ?? "{}",
        status: "DRAFT",
        currentVersionId: null,
        rowVersion: 1,
        createdBy: ADMIN.id,
        updatedBy: ADMIN.id,
        createdAt: NOW,
        updatedAt: NOW,
      };
      lessons.push(lesson);
      return json(res, 201, lesson);
    }
  }
  const lessonMatch = path.match(/^\/api\/v1\/admin\/lessons\/([0-9a-f-]+)$/);
  if (lessonMatch) {
    const lesson = lessons.find((l) => l.id === lessonMatch[1]);
    if (!lesson) return json(res, 404, { code: "LESSON_NOT_FOUND", message: "not found" });
    if (m === "GET") return json(res, 200, lesson);
    if (m === "PATCH") {
      const body = await readBody(req);
      if (
        body?.expectedRowVersion !== undefined &&
        body.expectedRowVersion !== lesson.rowVersion
      ) {
        return json(res, 409, {
          code: "OPTIMISTIC_LOCK_CONFLICT",
          message: "modified concurrently",
        });
      }
      Object.assign(lesson, {
        title: body.title ?? lesson.title,
        templateId: body.templateId ?? lesson.templateId,
        centralQuestion: body.centralQuestion ?? lesson.centralQuestion,
        objectivesJson: body.objectivesJson ?? lesson.objectivesJson,
        rowVersion: lesson.rowVersion + 1,
        updatedAt: NOW,
      });
      return json(res, 200, lesson);
    }
  }

  // --- admin/lessons/{id}/draft + /validate ---
  const draftMatch = path.match(/^\/api\/v1\/admin\/lessons\/([0-9a-f-]+)\/draft$/);
  if (draftMatch && m === "PUT") {
    const lesson = lessons.find((l) => l.id === draftMatch[1]);
    if (!lesson) return json(res, 404, { code: "LESSON_NOT_FOUND", message: "not found" });
    const body = await readBody(req);
    if (
      body?.expectedRowVersion !== undefined &&
      body.expectedRowVersion !== lesson.rowVersion
    ) {
      return json(res, 409, {
        code: "OPTIMISTIC_LOCK_CONFLICT",
        message: "modified concurrently",
      });
    }
    if (typeof body?.draftJson !== "string") {
      return json(res, 422, {
        code: "DRAFT_SCHEMA_INVALID",
        message: "draftJson must be a string",
        details: { errors: [{ path: "draftJson", code: "REQUIRED", message: "missing" }] },
      });
    }
    let parsed;
    try {
      parsed = JSON.parse(body.draftJson);
    } catch {
      return json(res, 422, {
        code: "DRAFT_SCHEMA_INVALID",
        message: "draftJson is not valid JSON",
        details: { errors: [{ path: "draftJson", code: "INVALID_JSON", message: "unparseable" }] },
      });
    }
    // Minimal SAVE-level check mirroring the real validator: MC needs question+options.
    const errors = [];
    (parsed.stages ?? []).forEach((s, si) => {
      (s.activities ?? []).forEach((a, ai) => {
        if (a.type === "MULTIPLE_CHOICE") {
          const cfg = a.config ?? {};
          if (!cfg.question || !Array.isArray(cfg.options) || cfg.options.length < 2) {
            errors.push({
              path: `stages[${si}].activities[${ai}].config`,
              code: "INVALID_CONFIG",
              message: "Trắc nghiệm cần câu hỏi và ≥2 đáp án",
            });
          }
        }
      });
    });
    if (errors.length) {
      return json(res, 422, {
        code: "DRAFT_SCHEMA_INVALID",
        message: "draft không hợp lệ",
        details: { errors },
      });
    }
    lesson.draftJson = body.draftJson;
    lesson.rowVersion += 1;
    lesson.updatedAt = NOW;
    return json(res, 200, lesson);
  }
  const validateMatch = path.match(/^\/api\/v1\/admin\/lessons\/([0-9a-f-]+)\/validate$/);
  if (validateMatch && m === "POST") {
    const lesson = lessons.find((l) => l.id === validateMatch[1]);
    if (!lesson) return json(res, 404, { code: "LESSON_NOT_FOUND", message: "not found" });
    // Canned readiness: ready when every required stage has ≥1 required activity.
    let draft;
    try {
      draft = JSON.parse(lesson.draftJson || "{}");
    } catch {
      draft = {};
    }
    const errors = [];
    (draft.stages ?? []).forEach((s, si) => {
      if (s.required && !(s.activities ?? []).some((a) => a.required)) {
        errors.push({
          path: `stages[${si}]`,
          code: "NO_REQUIRED_ACTIVITY",
          message: "Giai đoạn bắt buộc cần ít nhất một hoạt động bắt buộc",
        });
      }
    });
    return json(res, 200, {
      ready: errors.length === 0,
      errors,
      warnings: [],
      summary:
        errors.length === 0
          ? "Đủ điều kiện xuất bản"
          : `Còn ${errors.length} lỗi cần xử lý trước khi xuất bản`,
    });
  }

  if (m === "GET" && path === "/api/v1/admin/lesson-templates") {
    return json(res, 200, templates.filter((t) => t.enabled));
  }
  if (m === "GET" && path === "/api/v1/admin/evidences") {
    return json(res, 200, EMPTY_PAGE);
  }

  json(res, 404, { code: "NOT_FOUND", message: `no stub for ${m} ${path}` });
});

server.listen(PORT, () => {
  console.log(`e2e backend stub listening on http://localhost:${PORT}`);
});
