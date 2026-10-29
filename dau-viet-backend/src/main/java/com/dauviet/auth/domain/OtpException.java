package com.dauviet.auth.domain;

/**
 * Base for OTP verification failures. Mapped to stable ErrorCodes in
 * GlobalExceptionHandler — subclasses differ only in which code/status
 * they surface.
 */
public abstract class OtpException extends RuntimeException {

    protected OtpException(String message) {
        super(message);
    }

    /** Wrong code — attempts left is surfaced in error details. */
    public static class Invalid extends OtpException {
        private final int attemptsLeft;

        public Invalid(int attemptsLeft) {
            super("Invalid OTP code");
            this.attemptsLeft = attemptsLeft;
        }

        public int getAttemptsLeft() { return attemptsLeft; }
    }

    /** Code is (or challenge is) past expires_at. */
    public static class Expired extends OtpException {
        public Expired() {
            super("OTP code expired");
        }
    }

    /** attempts reached max_attempts; challenge consumed, must re-request. */
    public static class MaxAttemptsExceeded extends OtpException {
        public MaxAttemptsExceeded() {
            super("OTP max attempts exceeded");
        }
    }

    /** Resend requested before resendCooldownSeconds elapsed. */
    public static class ResendCooldown extends OtpException {
        private final long retryAfterSeconds;

        public ResendCooldown(long retryAfterSeconds) {
            super("OTP resend cooldown active");
            this.retryAfterSeconds = retryAfterSeconds;
        }

        public long getRetryAfterSeconds() { return retryAfterSeconds; }
    }

    /** Resend requested for an (email,purpose) with no prior challenge. */
    public static class NoChallenge extends OtpException {
        public NoChallenge() {
            super("No pending OTP challenge");
        }
    }
}
