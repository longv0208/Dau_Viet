-- Dấu Việt | V27 | GAME-05 FINAL FIX-3 — tách schemaVersion khỏi revision
-- per-item. rule_version trước đây vừa là "schema" (1=V1, >=2=V2) vừa là
-- revision → luồng setRule V1 (tương thích ngược) sau nhiều publish V2
-- ghi rule_version=1, làm revision LẶP/GIẢM so với các publish trước.
-- V27 thêm cột revision độc lập (monotonic, không giảm/reuse trong cùng
-- item), giữ rule_version=1 cho mọi rule publish qua API V1 để CHECK cũ
-- và semantic "V1 legacy" không đổi. provenance user_inventory giờ trace
-- theo revision (mới) + rule_id; unlock_rule_version cũ không đụng.

ALTER TABLE item_unlock_rule
    ADD COLUMN revision INTEGER;

-- Backfill: revision = rule_version hiện có (V1 → 1, các publish V2 đã
-- có 2/3/4... từ FIX-4 giữ nguyên — provenance cũ không viết lại).
UPDATE item_unlock_rule SET revision = rule_version WHERE revision IS NULL;

ALTER TABLE item_unlock_rule
    ALTER COLUMN revision SET NOT NULL,
    ALTER COLUMN revision SET DEFAULT 1,
    ADD CONSTRAINT chk_rule_revision CHECK (revision >= 1);
