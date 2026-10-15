-- Dấu Việt MVP | V2 | users, authentication
-- Requires V1__create_historical_events.sql already applied.
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(320) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(120),
    role VARCHAR(32) NOT NULL DEFAULT 'LEARNER',
    status VARCHAR(24) NOT NULL DEFAULT 'ACTIVE',
    email_verified_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_users_role CHECK (role IN ('LEARNER','CONTENT_ADMIN')),
    CONSTRAINT chk_users_status CHECK (status IN ('ACTIVE','LOCKED','DISABLED')),
    CONSTRAINT chk_users_email_nonempty CHECK (length(btrim(email)) > 3)
);
-- Case-insensitive uniqueness without introducing CITEXT dependency.
CREATE UNIQUE INDEX ux_users_email_lower ON users (lower(email));
CREATE INDEX idx_users_role_status ON users(role, status);

CREATE TABLE auth_refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    token_family_id UUID NOT NULL,
    previous_token_id UUID REFERENCES auth_refresh_tokens(id),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    CONSTRAINT chk_refresh_expiry CHECK (expires_at > created_at)
);
CREATE INDEX idx_refresh_user ON auth_refresh_tokens(user_id);
CREATE INDEX idx_refresh_family ON auth_refresh_tokens(token_family_id);
CREATE INDEX idx_refresh_active_expiry ON auth_refresh_tokens(expires_at) WHERE revoked_at IS NULL;
