package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import com.dauviet.auth.domain.OtpPurpose;

/** Resend request for REGISTER_VERIFY or PASSWORD_RESET. */
public record ResendOtpRequest(
        @NotBlank @Email @Size(max = 320) String email,
        @NotNull OtpPurpose purpose
) {}
