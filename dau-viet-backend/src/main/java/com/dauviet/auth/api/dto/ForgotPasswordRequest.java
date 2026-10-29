package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Forgot-password kickoff. Always 200 — never reveals account existence. */
public record ForgotPasswordRequest(
        @NotBlank @Email @Size(max = 320) String email
) {}
