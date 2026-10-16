import { http, HttpResponse } from "msw";

import {
  adminUserFixture,
  emptyPageFixture,
  eventsPageFixture,
  lessonsPageFixture,
  templatesFixture,
} from "../fixtures";

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
      draftJson: "{}",
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
  http.get("*/api/proxy/admin/lesson-templates", () =>
    HttpResponse.json(templatesFixture),
  ),
  http.get("*/api/proxy/admin/evidences", () => HttpResponse.json(emptyPageFixture)),
];
