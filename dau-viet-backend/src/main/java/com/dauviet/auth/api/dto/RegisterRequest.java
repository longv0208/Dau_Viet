package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Learner self-registration. A non-null `role` is rejected by the service
 * (400) — public registration can never choose a privileged role.
 * Password max 72 = BCrypt input limit.
 */
public record RegisterRequest(
        @NotBlank @Email @Size(max = 320) String email,
        @NotBlank @Size(min = 8, max = 72) String password,
        @Size(max = 120) String displayName,
        @Size(max = 32) String role
) {}
