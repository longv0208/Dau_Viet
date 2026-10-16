"use client";

import { useEffect, useState } from "react";

import { apiFetch } from "@/lib/api-client";
import type { UserProfileDto } from "@/lib/dto/user";
import { ForbiddenState } from "@/components/forbidden-state";
import { Skeleton } from "@/components/ui/skeleton";

import { refreshSession } from "./use-auth";

type BootstrapState =
  | { kind: "loading" }
  | { kind: "ready"; user: UserProfileDto }
  | { kind: "forbidden"; user: UserProfileDto }
  | { kind: "unauthenticated" };

/**
 * Client-side session bootstrap (P0 fix for refresh-rotation cookie loss).
 *
 * The server-side layout can't propagate the rotated `dv_refresh` Set-Cookie
 * back to the browser — an internal fetch swallows it, and because the backend
 * revokes the old token on rotate (replay → revokeFamily), the browser would
 * hold a dead token. Doing refresh + /users/me from the browser means the
 * rotated cookie lands normally.
 *
 * middleware.ts already bounces cookie-less requests; this gates children
 * until the role is known so a LEARNER sees 403, not a flash of admin UI.
 */
export function SessionBootstrap({
  children,
}: {
  children: (user: UserProfileDto) => React.ReactNode;
}) {
  const [state, setState] = useState<BootstrapState>({ kind: "loading" });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const refreshed = await refreshSession();
      if (!refreshed) {
        if (!cancelled) setState({ kind: "unauthenticated" });
        return;
      }
      try {
        const me = await apiFetch<UserProfileDto>("/users/me");
        if (cancelled) return;
        setState(
          me.role === "CONTENT_ADMIN"
            ? { kind: "ready", user: me }
            : { kind: "forbidden", user: me },
        );
      } catch {
        if (!cancelled) setState({ kind: "unauthenticated" });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (state.kind === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-surface p-6">
        <Skeleton className="h-10 w-64" />
      </div>
    );
  }
  if (state.kind === "forbidden") return <ForbiddenState user={state.user} />;
  if (state.kind === "unauthenticated") {
    if (typeof window !== "undefined") window.location.assign("/login");
    return null;
  }
  return <>{children(state.user)}</>;
}
