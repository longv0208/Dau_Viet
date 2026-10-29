package com.dauviet.auth.domain;

/**
 * OTP challenge purposes (V51 auth_otp_challenges.purpose CHECK constraint).
 * Keep in sync with the migration.
 */
public enum OtpPurpose {
    REGISTER_VERIFY,
    PASSWORD_RESET
}
