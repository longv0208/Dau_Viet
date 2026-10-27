-- Dấu Việt | V25 | GAME-05 fix — cho phép rule_type='RULE_V2' trong
-- item_unlock_rule. V12 CHECK chk_unlock_rule_type chỉ cho 3 loại V1 và
-- chk_unlock_rule_shape đòi threshold/lesson_id theo type; rule v2 mang
-- AST trong condition_json nên cột phẳng để NULL — cần mở rộng hai CHECK
-- để setRule v2 (AdminItemService.buildRule) insert được. Không đụng
-- dữ liệu đã có: rule v1 vẫn phải đúng shape V1.

ALTER TABLE item_unlock_rule DROP CONSTRAINT chk_unlock_rule_type;
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_unlock_rule_type CHECK (rule_type IN (
        'LESSON_COMPLETED','COLLECTION_COUNT','LESSON_COUNT','RULE_V2'));

ALTER TABLE item_unlock_rule DROP CONSTRAINT chk_unlock_rule_shape;
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_unlock_rule_shape CHECK (
        (rule_type = 'LESSON_COMPLETED' AND rule_version = 1
            AND lesson_id IS NOT NULL AND threshold IS NULL)
        OR (rule_type IN ('COLLECTION_COUNT','LESSON_COUNT')
            AND rule_version = 1
            AND threshold IS NOT NULL AND threshold > 0
            AND lesson_id IS NULL)
        OR (rule_version = 2
            AND condition_json IS NOT NULL
            AND lesson_id IS NULL AND threshold IS NULL)
    );
