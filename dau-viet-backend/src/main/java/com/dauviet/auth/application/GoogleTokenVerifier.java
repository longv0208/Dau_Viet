package com.dauviet.auth.application;

import com.dauviet.auth.domain.GoogleTokenInvalidException;

/**
 * Verifies a Google-issued idToken and returns the checked claims. Kept as
 * an interface so tests can stub verification without Google's JWKS; the
 * production implementation is GoogleIdTokenVerifier-backed.
 */
public interface GoogleTokenVerifier {

    /** Verified claims needed for sign-in/linking. */
    record VerifiedGoogleUser(String subject, String email, String displayName) {}

    /**
     * @throws GoogleTokenInvalidException on any verification failure
     *         (signature, iss, aud, exp, missing email, email_verified=false).
     */
    VerifiedGoogleUser verify(String idToken);
}
