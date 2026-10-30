package com.dauviet.auth.application;

import org.springframework.lang.Nullable;

import com.dauviet.auth.domain.GoogleTokenInvalidException;

/**
 * Verifies a Google-issued credential and returns the checked claims. Kept
 * as an interface so tests can stub verification without Google's JWKS /
 * tokeninfo endpoints. Exactly one of the two tokens is expected non-null:
 * idToken (Android/iOS JWT) or OAuth2 accessToken (Flutter Web — Issue #41).
 */
public interface GoogleTokenVerifier {

    /** Verified claims needed for sign-in/linking. */
    record VerifiedGoogleUser(String subject, String email, String displayName) {}

    /**
     * @throws GoogleTokenInvalidException on any verification failure
     *         (signature, iss, aud, exp, missing email, email_verified=false).
     */
    VerifiedGoogleUser verify(@Nullable String idToken, @Nullable String accessToken);
}
