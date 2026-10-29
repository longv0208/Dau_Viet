package com.dauviet.auth.application;

import com.dauviet.auth.domain.OtpPurpose;

/**
 * Delivers the plaintext 6-digit OTP to the user. The code exists here and
 * in the mail body only — it is never stored unhashed and never logged in
 * production (LoggingOtpSender prints it only under the "local" profile).
 */
public interface OtpSender {

    void sendOtp(String email, OtpPurpose purpose, String code);
}
