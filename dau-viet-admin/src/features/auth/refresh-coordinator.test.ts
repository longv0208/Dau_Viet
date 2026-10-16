import { http, HttpResponse } from "msw";
import { afterEach, describe, expect, it } from "vitest";

import { server } from "@/test/msw/server";

import { authStore } from "./auth-store";
import { coordinatedRefresh } from "./refresh-coordinator";

/**
 * Regression tests for the refresh-rotation concurrency bug: the backend
 * revokes the presented token on rotate and treats a replay as theft
 * (revokeFamily → forced logout). StrictMode remounts, racing 401s and a
 * second tab must therefore share ONE in-flight rotation.
 */

function trackRefreshCalls() {
  let calls = 0;
  server.use(
    http.post("*/api/auth/refresh", async () => {
      calls += 1;
      // Slow enough that a second call would overlap an uncoordinated first.
      await new Promise((r) => setTimeout(r, 30));
      return HttpResponse.json({
        accessToken: `rotated-${calls}`,
        expiresIn: 900,
      });
    }),
  );
  return () => calls;
}

describe("coordinatedRefresh", () => {
  afterEach(() => authStore.clear());

  it("single-flights N concurrent calls into one upstream request", async () => {
    const count = trackRefreshCalls();
    const results = await Promise.all([
      coordinatedRefresh(),
      coordinatedRefresh(),
      coordinatedRefresh(),
      coordinatedRefresh(),
    ]);
    expect(results).toEqual([true, true, true, true]);
    expect(count()).toBe(1);
    expect(authStore.getAccessToken()).toBe("rotated-1");
  });

  it("runs a new rotation once the previous one settles", async () => {
    const count = trackRefreshCalls();
    await coordinatedRefresh();
    await coordinatedRefresh();
    expect(count()).toBe(2);
    expect(authStore.getAccessToken()).toBe("rotated-2");
  });

  it("returns false and leaves the store empty when the BFF rejects", async () => {
    server.use(
      http.post("*/api/auth/refresh", () =>
        HttpResponse.json({ code: "UNAUTHORIZED" }, { status: 401 }),
      ),
    );
    const ok = await coordinatedRefresh();
    expect(ok).toBe(false);
    expect(authStore.getAccessToken()).toBeNull();
  });

  it("returns false on network error instead of throwing", async () => {
    server.use(http.post("*/api/auth/refresh", () => HttpResponse.error()));
    await expect(coordinatedRefresh()).resolves.toBe(false);
  });

  it("adopts a token broadcast by another tab via BroadcastChannel", async () => {
    const received = new Promise<string | null>((resolve) => {
      const bc = new BroadcastChannel("dv-auth");
      bc.onmessage = () => resolve(authStore.getAccessToken());
      // Give this tab a token as if it just refreshed.
      bc.postMessage({
        type: "refreshed",
        accessToken: "cross-tab-token",
        expiresIn: 900,
      });
      setTimeout(() => resolve(authStore.getAccessToken()), 100);
    });
    expect(await received).toBe("cross-tab-token");
  });
});

describe("apiFetch 401 → coordinated refresh", () => {
  afterEach(() => authStore.clear());

  it("concurrent 401s trigger a single rotation, then retry", async () => {
    const { apiFetch } = await import("@/lib/api-client");
    let refreshCalls = 0;
    let protectedCalls = 0;
    server.use(
      http.post("*/api/auth/refresh", async () => {
        refreshCalls += 1;
        await new Promise((r) => setTimeout(r, 30));
        return HttpResponse.json({ accessToken: "fresh", expiresIn: 900 });
      }),
      http.get("*/api/proxy/users/me", ({ request }) => {
        protectedCalls += 1;
        const auth = request.headers.get("authorization");
        if (auth !== "Bearer fresh") {
          return HttpResponse.json({ code: "UNAUTHORIZED" }, { status: 401 });
        }
        return HttpResponse.json({ id: "u1", email: "a@b.c", role: "CONTENT_ADMIN" });
      }),
    );

    const [a, b] = await Promise.all([
      apiFetch("/users/me"),
      apiFetch("/users/me"),
    ]);
    expect(refreshCalls).toBe(1);
    expect(protectedCalls).toBe(4); // 2 initial 401s + 2 retried with fresh token
    expect(a).toMatchObject({ role: "CONTENT_ADMIN" });
    expect(b).toMatchObject({ role: "CONTENT_ADMIN" });
  });
});
