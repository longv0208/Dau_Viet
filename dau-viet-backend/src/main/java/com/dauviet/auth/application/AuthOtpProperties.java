package com.dauviet.auth.application;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * `dauviet.auth.otp.*` — OTP challenge lifecycle knobs (Issue #34).
 * mailEnabled=false swaps in LoggingOtpSender; the sender only prints the
 * code when the "local" profile is active, so production never logs OTPs.
 */
@ConfigurationProperties(prefix = "dauviet.auth.otp")
public class AuthOtpProperties {

    /** Seconds a challenge stays valid (default 5 minutes). */
    private long ttlSeconds = 300;

    /** Minimum seconds between issues for the same (email,purpose). */
    private long resendCooldownSeconds = 60;

    /** Wrong-code submissions allowed before the challenge is consumed. */
    private int maxAttempts = 5;

    /** true → SmtpOtpSender via spring.mail.*; false → LoggingOtpSender. */
    private boolean mailEnabled = false;

    /** From: address on outgoing OTP mail. */
    private String senderAddress = "no-reply@dauviet.app";

    public long getTtlSeconds() { return ttlSeconds; }
    public void setTtlSeconds(long ttlSeconds) { this.ttlSeconds = ttlSeconds; }

    public long getResendCooldownSeconds() { return resendCooldownSeconds; }
    public void setResendCooldownSeconds(long resendCooldownSeconds) {
        this.resendCooldownSeconds = resendCooldownSeconds;
    }

    public int getMaxAttempts() { return maxAttempts; }
    public void setMaxAttempts(int maxAttempts) { this.maxAttempts = maxAttempts; }

    public boolean isMailEnabled() { return mailEnabled; }
    public void setMailEnabled(boolean mailEnabled) { this.mailEnabled = mailEnabled; }

    public String getSenderAddress() { return senderAddress; }
    public void setSenderAddress(String senderAddress) { this.senderAddress = senderAddress; }
}
