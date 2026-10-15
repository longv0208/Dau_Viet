package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.NotBlank;

/** Shared body for /auth/refresh and /auth/logout. */
public record RefreshRequest(
        @NotBlank String refreshToken
) {}
