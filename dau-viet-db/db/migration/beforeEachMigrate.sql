-- Dấu Việt | Flyway SQL callback: chạy TRƯỚC mỗi versioned migration.
-- Mục đích duy nhất: đảm bảo legacy DB có duplicate (user_id, evidence_id)
-- trong user_evidence được dọn TRƯỚC khi V10 tạo
-- ux_user_evidence_user_evidence UNIQUE(user_id, evidence_id).
--
-- Bối cảnh:
--   V4 cho phép cùng learner collect cùng evidence qua nhiều attempt
--   (UNIQUE chỉ trên (learner_attempt_id, evidence_id)). V10 sau đó thêm
--   UNIQUE(user_id, evidence_id). Trên DB legacy có sẵn duplicates, V10
--   fail tại CREATE UNIQUE INDEX và Flyway abort — V11 (chạy sau V10)
--   không bao giờ tới được. Callback này chạy trước V10 nên xử lý đúng
--   chỗ: archive TOÀN BỘ duplicate rows vào bảng bền vững, rồi giữ lại
--   canonical row sớm nhất trước khi index được tạo.
--
-- An toàn:
--   * Guard bằng to_regclass('ux_user_evidence_user_evidence'): index đã
--     tồn tại → bảng đã sạch & upgraded → no-op thoát sớm.
--   * Bảng user_evidence chưa tồn tại (fresh DB trước V4) → no-op.
--   * Idempotent: canonical giữ MIN(collected_at, id) deterministic;
--     archive insert dùng NOT EXISTS nên chạy lại không nhân đôi.
--   * KHÔNG drop archive — lịch sử không bao giờ xoá ngầm (req. §1.5/1.7).
--   * Chạy trong cùng transaction của migration → rollback cùng V10.
DO $$
DECLARE
    dup_count INT;
BEGIN
    -- Đã upgrade xong (index tồn tại) hoặc bảng chưa có → không làm gì.
    IF to_regclass('ux_user_evidence_user_evidence') IS NOT NULL
       OR to_regclass('user_evidence') IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*) INTO dup_count
    FROM (
        SELECT user_id, evidence_id
        FROM user_evidence
        GROUP BY user_id, evidence_id
        HAVING COUNT(*) > 1
    ) d;

    IF dup_count = 0 THEN
        RETURN;
    END IF;

    -- Archive bền vững — giữ nguyên row gốc + lý do + canonical pointer.
    -- PK trên id gốc: mỗi row active chỉ được archive đúng một lần dù
    -- callback chạy lại (archived_at không nằm trong PK để rerun không
    -- nhân đôi bản ghi).
    CREATE TABLE IF NOT EXISTS user_evidence_legacy_archive (
        id              UUID        NOT NULL PRIMARY KEY,
        user_id         UUID        NOT NULL,
        learner_attempt_id UUID     NOT NULL,
        evidence_id     UUID        NOT NULL,
        collected_at    TIMESTAMPTZ NOT NULL,
        archived_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
        archive_reason  VARCHAR(64) NOT NULL
                        DEFAULT 'v10_dedup',
        canonical_id    UUID
    );

    -- Canonical = row sớm nhất theo (collected_at, id) — deterministic.
    -- Mọi duplicate (kể cả canonical của nhóm? KHÔNG — chỉ non-canonical)
    -- được sao vào archive trước khi xoá.
    WITH ranked AS (
        SELECT id, user_id, evidence_id,
               FIRST_VALUE(id) OVER (
                   PARTITION BY user_id, evidence_id
                   ORDER BY collected_at ASC, id ASC
               ) AS canonical_id,
               ROW_NUMBER() OVER (
                   PARTITION BY user_id, evidence_id
                   ORDER BY collected_at ASC, id ASC
               ) AS rn
        FROM user_evidence
    )
    INSERT INTO user_evidence_legacy_archive
        (id, user_id, learner_attempt_id, evidence_id, collected_at,
         archive_reason, canonical_id)
    SELECT ue.id, ue.user_id, ue.learner_attempt_id, ue.evidence_id,
           ue.collected_at, 'v10_dedup', r.canonical_id
    FROM user_evidence ue
    JOIN ranked r ON r.id = ue.id
    WHERE r.rn > 1
    ON CONFLICT DO NOTHING;

    -- Xoá non-canonical khỏi bảng active — chỉ sau khi đã archive đủ.
    DELETE FROM user_evidence a
    WHERE EXISTS (
        SELECT 1 FROM user_evidence b
        WHERE b.user_id = a.user_id
          AND b.evidence_id = a.evidence_id
          AND (b.collected_at, b.id) < (a.collected_at, a.id)
    );

    RAISE NOTICE 'user_evidence dedup pre-V10: % duplicate groups archived',
        dup_count;
END $$;
