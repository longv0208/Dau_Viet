/**
 * Controlled backend stub for Playwright e2e — a plain node:http server that
 * answers the minimal /api/v1 surface the admin needs to login and render the
 * dashboard. NOT the real Spring Boot backend; bodies are canned fixtures.
 *
 * Start: `node scripts/e2e-backend-stub.mjs` (listens on :8081 by default).
 */
import http from "node:http";

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

const EMPTY_PAGE = { content: [], page: 0, size: 20, totalElements: 0, totalPages: 0 };

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json" });
  res.end(payload);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", `http://localhost:${PORT}`);
  const path = url.pathname;

  if (req.method === "POST" && path === "/api/v1/auth/login") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        const { email, password } = JSON.parse(body);
        if (email === "admin@dauviet.local" && password === "secret") {
          return json(res, 200, TOKENS);
        }
        return json(res, 401, { code: "INVALID_CREDENTIALS", message: "bad credentials" });
      } catch {
        return json(res, 400, { code: "BAD_REQUEST", message: "malformed" });
      }
    });
    return;
  }

  if (req.method === "POST" && path === "/api/v1/auth/refresh") {
    return json(res, 200, TOKENS);
  }
  if (req.method === "POST" && path === "/api/v1/auth/logout") {
    res.writeHead(204);
    return res.end();
  }
  if (req.method === "GET" && path === "/api/v1/users/me") {
    return json(res, 200, ADMIN);
  }
  if (req.method === "GET" && path === "/api/v1/admin/ping") {
    return json(res, 200, { status: "ok" });
  }
  if (req.method === "GET" && path === "/api/v1/admin/events") {
    return json(res, 200, EMPTY_PAGE);
  }
  if (req.method === "GET" && path === "/api/v1/admin/lessons") {
    return json(res, 200, EMPTY_PAGE);
  }
  if (req.method === "GET" && path === "/api/v1/admin/lesson-templates") {
    return json(res, 200, []);
  }

  json(res, 404, { code: "NOT_FOUND", message: `no stub for ${req.method} ${path}` });
});

server.listen(PORT, () => {
  console.log(`e2e backend stub listening on http://localhost:${PORT}`);
});
