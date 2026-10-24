-- Dấu Việt MVP | V11 | TASK-0022 data-preserving dedup for V10.
-- V10 thêm ux_user_evidence_user_evidence UNIQUE(user_id, evidence_id) đúng
-- ý đồ trên bảng trống, nhưng trên DB đã tồn tại (V4 cho phép repeat
-- (user_id, evidence_id) qua các attempt khác nhau) CREATE UNIQUE INDEX
-- sẽ fail. Chiến lược data-preserving:
--   1. Backup user_evidence ra user_evidence_v10_backup (schema identical).
--   2. Delete các row duplicate (user_id, evidence_id), giữ đúng 1 row
--      (MIN(id)) — deterministic.
--   3. CREATE UNIQUE INDEX lại trên bảng đã sạch.
--   4. Drop backup — V10 đã chạy xong nên Flyway không chạy lại file V10,
--      nhưng kịch bản "restore lại DB cũ rồi chạy Flyway từ đầu" vẫn an toàn:
--      backup/delete chỉ chạy khi bảng thực sự có duplicate.
-- Không xoá/sửa V10 — Flyway checksum của file đã applied giữ nguyên.
DO $$
DECLARE
    dup_count INT;
BEGIN
    SELECT COUNT(*) INTO dup_count
    FROM (
        SELECT user_id, evidence_id
        FROM user_evidence
        GROUP BY user_id, evidence_id
        HAVING COUNT(*) > 1
    ) d;

    IF dup_count > 0 THEN
        CREATE TABLE IF NOT EXISTS user_evidence_v10_backup
            (LIKE user_evidence INCLUDING ALL);
        INSERT INTO user_evidence_v10_backup SELECT * FROM user_evidence;

        DELETE FROM user_evidence a
        USING user_evidence b
        WHERE a.user_id = b.user_id
          AND a.evidence_id = b.evidence_id
          AND a.id > b.id;

        DROP TABLE user_evidence_v10_backup;
    END IF;
END $$;
