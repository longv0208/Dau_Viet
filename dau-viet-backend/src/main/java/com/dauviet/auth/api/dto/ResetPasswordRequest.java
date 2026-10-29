package com.dauviet.auth.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Password reset via OTP. Password max 72 = BCrypt input limit. */
public record ResetPasswordRequest(
        @NotBlank @Email @Size(max = 320) String email,
        @NotBlank @Pattern(regexp = "\\d{6}", message = "otpCode must be 6 digits") String otpCode,
        @NotBlank @Size(min = 8, max = 72) String newPassword
) {}
