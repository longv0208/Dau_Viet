package com.dauviet.auth.domain;

/**
 * Google idToken failed verification (bad signature, wrong iss/aud, expired,
 * or email_verified=false). Surfaced as 401 GOOGLE_TOKEN_INVALID — the
 * failure detail stays server-side so clients can't probe which check failed.
 */
public class GoogleTokenInvalidException extends RuntimeException {

    public GoogleTokenInvalidException(String reason) {
        super(reason);
    }

    public GoogleTokenInvalidException(String reason, Throwable cause) {
        super(reason, cause);
    }
}
