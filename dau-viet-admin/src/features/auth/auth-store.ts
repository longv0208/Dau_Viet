/**
 * In-memory access-token store. The access token is NEVER persisted —
 * no localStorage, sessionStorage, or cookie. On reload it is rehydrated
 * via POST /api/auth/refresh (which rotates the HttpOnly refresh cookie).
 */
let accessToken: string | null = null;
let expiresAt = 0;

export const authStore = {
  getAccessToken(): string | null {
    // Treat tokens expiring within 15s as expired — avoids using a token
    // that dies mid-flight.
    if (accessToken && Date.now() < expiresAt - 15_000) return accessToken;
    return null;
  },
  setAccessToken(token: string, expiresIn: number) {
    accessToken = token;
    expiresAt = Date.now() + expiresIn * 1000;
  },
  clear() {
    accessToken = null;
    expiresAt = 0;
  },
};
