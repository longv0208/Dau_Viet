package com.dauviet.auth.api.dto;

/**
 * Token pair returned by login and refresh. The raw refresh token exists
 * only here and in the client — the DB stores its SHA-256.
 */
public record TokenResponse(
        String accessToken,
        String tokenType,
        long expiresIn,
        String refreshToken,
        long refreshExpiresIn
) {}
