-- Dấu Việt MVP | V4 | Learner state, retries, evidence collection, idempotent rewards.
CREATE TABLE learner_attempts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    lesson_version_id UUID NOT NULL REFERENCES lesson_versions(id),
    status VARCHAR(24) NOT NULL DEFAULT 'IN_PROGRESS',
    current_stage_id VARCHAR(100),
    current_activity_id VARCHAR(100),
    state_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_attempt_status CHECK (status IN ('IN_PROGRESS','COMPLETED','ABANDONED')),
    CONSTRAINT chk_attempt_state CHECK (jsonb_typeof(state_json) = 'object'),
    CONSTRAINT chk_attempt_completion CHECK (status <> 'COMPLETED' OR completed_at IS NOT NULL)
);
CREATE INDEX idx_attempt_user_status ON learner_attempts(user_id, status);
CREATE INDEX idx_attempt_version ON learner_attempts(lesson_version_id);
-- Allow history/retries after completion, but at most one active attempt per learner+version.
CREATE UNIQUE INDEX ux_attempt_active_user_version
    ON learner_attempts(user_id, lesson_version_id) WHERE status = 'IN_PROGRESS';

CREATE TABLE activity_attempts (
    id UUID PRIMARY KEY,
    learner_attempt_id UUID NOT NULL REFERENCES learner_attempts(id),
    activity_id VARCHAR(100) NOT NULL,
    attempt_no INTEGER NOT NULL CHECK (attempt_no >= 1),
    submitted_answer_json JSONB NOT NULL,
    result_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (learner_attempt_id, activity_id, attempt_no),
    CONSTRAINT chk_activity_result CHECK (jsonb_typeof(result_json) = 'object')
);
CREATE INDEX idx_activity_attempt_history ON activity_attempts(learner_attempt_id, activity_id, created_at);

CREATE TABLE idempotency_records (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    idempotency_key VARCHAR(160) NOT NULL,
    operation VARCHAR(100) NOT NULL,
    request_hash VARCHAR(128) NOT NULL,
    response_json JSONB,
    http_status INTEGER CHECK (http_status BETWEEN 100 AND 599),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    UNIQUE (user_id, operation, idempotency_key),
    CONSTRAINT chk_idempotency_response CHECK (response_json IS NULL OR jsonb_typeof(response_json) = 'object')
);
CREATE INDEX idx_idempotency_expiry ON idempotency_records(expires_at);

CREATE TABLE lesson_results (
    id UUID PRIMARY KEY,
    learner_attempt_id UUID NOT NULL UNIQUE REFERENCES learner_attempts(id),
    score NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (score >= 0),
    result_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_lesson_result_json CHECK (jsonb_typeof(result_json) = 'object')
);

CREATE TABLE user_evidence (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    learner_attempt_id UUID NOT NULL REFERENCES learner_attempts(id),
    evidence_id UUID NOT NULL REFERENCES evidences(id),
    collected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (learner_attempt_id, evidence_id)
);
CREATE INDEX idx_user_evidence_user ON user_evidence(user_id, collected_at DESC);

CREATE TABLE reward_transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    learner_attempt_id UUID REFERENCES learner_attempts(id),
    reward_type VARCHAR(48) NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    reason VARCHAR(160) NOT NULL,
    cause_key VARCHAR(200) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_reward_user_created ON reward_transactions(user_id, created_at DESC);
CREATE INDEX idx_reward_attempt ON reward_transactions(learner_attempt_id);
