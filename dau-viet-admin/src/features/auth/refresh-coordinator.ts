import { authStore } from "./auth-store";

/**
 * Refresh coordination — one in-flight rotation per tab, plus a cross-tab
 * BroadcastChannel so two tabs don't rotate the same cookie and trip the
 * backend's replay→revokeFamily theft detection.
 *
 * The backend revokes the presented token on every rotate; replaying a
 * revoked token revokes the whole family. StrictMode effect remounts, rapid
 * reloads and simultaneous 401 recovery can all fire a second rotate before
 * the first one's Set-Cookie lands — this module is the single choke point.
 */

interface SessionBody {
  accessToken: string;
  expiresIn: number;
}

let inFlight: Promise<boolean> | null = null;
const bc: BroadcastChannel | null =
  typeof window !== "undefined" && "BroadcastChannel" in window
    ? new BroadcastChannel("dv-auth")
    : null;

// Listen for another tab finishing a rotation — adopt its access token so we
// never rotate the same refresh token twice across tabs.
if (bc) {
  bc.onmessage = (ev: MessageEvent) => {
    const data = ev.data as { type?: string; accessToken?: string; expiresIn?: number };
    if (data?.type === "refreshed" && data.accessToken && data.expiresIn) {
      authStore.setAccessToken(data.accessToken, data.expiresIn);
    }
  };
}

async function doRefresh(): Promise<boolean> {
  try {
    const res = await fetch("/api/auth/refresh", { method: "POST" });
    if (!res.ok) return false;
    const body = (await res.json()) as SessionBody;
    authStore.setAccessToken(body.accessToken, body.expiresIn);
    bc?.postMessage({
      type: "refreshed",
      accessToken: body.accessToken,
      expiresIn: body.expiresIn,
    });
    return true;
  } catch {
    return false;
  }
}

/**
 * Single-flight refresh. Concurrent callers (StrictMode remount, multiple
 * apiFetch 401s, bootstrap + query racing) all await the same Promise — only
 * one rotate ever reaches the backend per tab per moment.
 */
export function coordinatedRefresh(): Promise<boolean> {
  if (!inFlight) {
    inFlight = doRefresh().finally(() => {
      inFlight = null;
    });
  }
  return inFlight;
}

/** True when we already hold a usable access token — skip the refresh entirely. */
export function hasFreshAccessToken(): boolean {
  return authStore.getAccessToken() !== null;
}
