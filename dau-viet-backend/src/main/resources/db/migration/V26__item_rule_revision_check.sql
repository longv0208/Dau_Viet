-- Dấu Việt | V26 | GAME-05 FIX-4 — rule_version thành policy revision
-- per-item (1 = legacy/publish đầu, +1 mỗi lần admin thay rule) thay vì
-- hằng "2" cho mọi rule AST. V24 chỉ cho phép IN (1,2) nên revision 3+
-- sẽ vi phạm CHECK → nới ràng buộc. Không đụng dữ liệu: provenance cũ
-- giữ nguyên, rule v1 vẫn rule_version=1.

ALTER TABLE item_unlock_rule DROP CONSTRAINT chk_rule_version;
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_rule_version CHECK (rule_version >= 1);

ALTER TABLE item_unlock_rule DROP CONSTRAINT chk_rule_v2_condition;
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_rule_v2_condition CHECK (
        rule_version = 1
        OR (condition_json IS NOT NULL
            AND jsonb_typeof(condition_json) = 'object'));

ALTER TABLE item_unlock_rule DROP CONSTRAINT chk_unlock_rule_shape;
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_unlock_rule_shape CHECK (
        (rule_type = 'LESSON_COMPLETED' AND rule_version = 1
            AND lesson_id IS NOT NULL AND threshold IS NULL)
        OR (rule_type IN ('COLLECTION_COUNT','LESSON_COUNT')
            AND rule_version = 1
            AND threshold IS NOT NULL AND threshold > 0
            AND lesson_id IS NULL)
        OR (rule_type = 'RULE_V2' AND rule_version >= 2
            AND condition_json IS NOT NULL
            AND lesson_id IS NULL AND threshold IS NULL)
    );
