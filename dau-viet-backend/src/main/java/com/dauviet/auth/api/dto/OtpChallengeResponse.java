package com.dauviet.auth.api.dto;

/** 202 response for OTP-issuing endpoints (register, resend). */
public record OtpChallengeResponse(
        String email,
        String otpPurpose,
        long otpTtlSeconds,
        long resendCooldownSeconds
) {}
