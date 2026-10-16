"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";

import { ApiClientError } from "@/lib/api-error";

import { authStore } from "./auth-store";
import { coordinatedRefresh } from "./refresh-coordinator";

interface SessionResponse {
  accessToken: string;
  expiresIn: number;
}

/** POST /api/auth/login — returns the session minus the refresh token. */
export function useLogin() {
  return useMutation({
    mutationFn: async (input: { email: string; password: string }) => {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(input),
      });
      const body = await res.json().catch(() => null);
      if (!res.ok) throw ApiClientError.from(body, res.status);
      const session = body as SessionResponse;
      authStore.setAccessToken(session.accessToken, session.expiresIn);
      return session;
    },
  });
}

/** POST /api/auth/logout — always clears local state + cookie. */
export function useLogout() {
  const router = useRouter();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async () => {
      await fetch("/api/auth/logout", { method: "POST" });
    },
    onSettled: () => {
      authStore.clear();
      qc.clear();
      router.replace("/login");
    },
  });
}

/**
 * Token rehydration (page reload / bootstrap). Delegates to the shared
 * single-flight coordinator so StrictMode remounts, a racing apiFetch 401 and
 * this call all await ONE rotation instead of double-rotating the cookie.
 */
export function refreshSession(): Promise<boolean> {
  return coordinatedRefresh();
}
