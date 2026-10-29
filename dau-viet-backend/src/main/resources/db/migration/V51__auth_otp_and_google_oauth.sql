-- Dấu Việt | V51 | Issue #34: OTP challenges + Google OAuth account linking
-- 1) users.password_hash -> nullable: Google-only accounts have no local
--    password until they set one (login path treats NULL hash as
--    INVALID_CREDENTIALS after timing equalization).
-- 2) auth_otp_challenges: hashed 6-digit OTP for REGISTER_VERIFY and
--    PASSWORD_RESET; at most one ACTIVE challenge per (email, purpose)
--    enforced by ux_otp_active partial unique index.
-- 3) user_oauth_accounts: (provider, provider_subject) -> user link.

ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

CREATE TABLE auth_otp_challenges (
    id            UUID PRIMARY KEY,
    email         VARCHAR(320) NOT NULL,
    purpose       VARCHAR(32)  NOT NULL,
    code_hash     VARCHAR(128) NOT NULL,
    payload_json  JSONB,
    attempts      INT NOT NULL DEFAULT 0,
    max_attempts  INT NOT NULL DEFAULT 5,
    expires_at    TIMESTAMPTZ NOT NULL,
    consumed_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_otp_purpose CHECK (purpose IN ('REGISTER_VERIFY','PASSWORD_RESET')),
    CONSTRAINT chk_otp_attempts CHECK (attempts >= 0 AND attempts <= max_attempts)
);
CREATE INDEX idx_otp_email_purpose_created
    ON auth_otp_challenges (lower(email), purpose, created_at DESC);
CREATE UNIQUE INDEX ux_otp_active
    ON auth_otp_challenges (lower(email), purpose) WHERE consumed_at IS NULL;

CREATE TABLE user_oauth_accounts (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider         VARCHAR(32)  NOT NULL,
    provider_subject VARCHAR(255) NOT NULL,
    provider_email   VARCHAR(320),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_oauth_provider CHECK (provider IN ('GOOGLE')),
    CONSTRAINT ux_oauth_provider_subject UNIQUE (provider, provider_subject)
);
CREATE INDEX idx_oauth_user ON user_oauth_accounts(user_id);
