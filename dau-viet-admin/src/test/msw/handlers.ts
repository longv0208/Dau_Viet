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
  http.get("*/api/proxy/admin/lessons", () => HttpResponse.json(lessonsPageFixture)),
  http.get("*/api/proxy/admin/lesson-templates", () =>
    HttpResponse.json(templatesFixture),
  ),
  http.get("*/api/proxy/admin/evidences", () => HttpResponse.json(emptyPageFixture)),
];
