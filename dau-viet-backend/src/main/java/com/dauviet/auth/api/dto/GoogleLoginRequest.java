package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;

import com.fasterxml.jackson.annotation.JsonIgnore;

/**
 * Google Sign-In (Issue #41): accepts either a Google idToken (Android/iOS)
 * or an OAuth2 accessToken (Flutter Web, where google_sign_in_web's token
 * client doesn't mint an idToken). Exactly one may be present; the server
 * verifies whichever is supplied against the same aud whitelist.
 */
public record GoogleLoginRequest(
        @Size(max = 8192) String idToken,
        @Size(max = 8192) String accessToken
) {
    @JsonIgnore
    @AssertTrue(message = "idToken or accessToken required")
    public boolean hasCredential() {
        return (idToken != null && !idToken.isBlank())
            || (accessToken != null && !accessToken.isBlank());
    }
}
