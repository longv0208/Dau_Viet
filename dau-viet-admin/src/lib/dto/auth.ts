/** Mirrors backend auth DTOs (com.dauviet.auth.api.dto). */

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface TokenResponse {
  accessToken: string;
  tokenType: string;
  /** Seconds until the access token expires (backend default 900). */
  expiresIn: number;
  refreshToken: string;
  refreshExpiresIn: number;
}

/** What BFF routes return to the browser — refresh token stripped. */
export interface ClientSession {
  accessToken: string;
  expiresIn: number;
}
