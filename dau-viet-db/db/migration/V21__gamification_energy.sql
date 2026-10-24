-- Dấu Việt | V21 | GAME-02 Hệ thống Thể lực server-authoritative.
-- user_energy: đúng 1 dòng/user (PK = user_id), lazy-create 100/100 lần đầu
-- cần energy — KHÔNG seed hàng loạt, không reset khi đăng nhập.
-- energy_transactions: ledger append-only; cause_key UNIQUE chặn ghi trùng
-- (retry/concurrent); balance_after phản ánh đúng trạng thái sau bút toán.
CREATE TABLE user_energy (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    current_energy INTEGER NOT NULL DEFAULT 100,
    -- Mốc server-time các chu kỳ hồi đã tiêu hao được tính tới (giữ phần
    -- lẻ: debit set về now(), recover advance theo bội số 15 phút).
    last_recovery_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_user_energy_range CHECK (current_energy BETWEEN 0 AND 100)
);

CREATE TABLE energy_transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    direction VARCHAR(8) NOT NULL,
    amount INTEGER NOT NULL,
    reason VARCHAR(40) NOT NULL,
    cause_key VARCHAR(200) NOT NULL,
    balance_after INTEGER NOT NULL,
    reference_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_energy_tx_direction CHECK (direction IN ('CREDIT','DEBIT')),
    CONSTRAINT chk_energy_tx_amount CHECK (amount > 0),
    CONSTRAINT chk_energy_tx_reason CHECK (reason IN (
        'GRADED_INCORRECT','NATURAL_RECOVERY','REFILL_PURCHASE','ADMIN_ADJUST')),
    CONSTRAINT chk_energy_tx_balance CHECK (balance_after BETWEEN 0 AND 100),
    CONSTRAINT chk_energy_tx_ref CHECK (reference_json IS NULL
        OR jsonb_typeof(reference_json) = 'object'),
    CONSTRAINT ux_energy_tx_cause UNIQUE (cause_key)
);
CREATE INDEX idx_energy_tx_user_created ON energy_transactions(user_id, created_at DESC);
