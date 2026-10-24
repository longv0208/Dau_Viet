-- Dấu Việt | V24 | GAME-05 Item Unlock Rule Engine V2.
-- item_unlock_rule mở rộng sang AST condition_json (rule_version=2) trong
-- khi giữ nguyên 3 cột/rule_type V1 — rule cũ tiếp tục được đánh giá bằng
-- ngữ nghĩa legacy (COLLECTION_COUNT đếm global, D2 gap report: không âm
-- thầm đổi ý nghĩa rule đã publish). user_inventory bổ sung provenance
-- (rule id/version + nguồn kích hoạt) phục vụ audit ITEM-01/03 — append
-- only, ownership đã cấp không đổi.

-- ---------- item_unlock_rule: rule v2 ----------

ALTER TABLE item_unlock_rule
    ADD COLUMN rule_version INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN condition_json JSONB,
    ADD COLUMN rule_metadata JSONB;

-- condition_json bắt buộc với rule v2; cấu trúc tối thiểu là một object
-- (AST hợp lệ đầy đủ do ItemConditionParser/Validator chặn ở service —
-- CHECK tầng DB chỉ là backstop shape).
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_rule_version CHECK (rule_version IN (1, 2));
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_rule_v2_condition CHECK (
        rule_version = 1
        OR (condition_json IS NOT NULL
            AND jsonb_typeof(condition_json) = 'object'));
ALTER TABLE item_unlock_rule
    ADD CONSTRAINT chk_rule_metadata CHECK (
        rule_metadata IS NULL OR jsonb_typeof(rule_metadata) = 'object');

-- Rule v1 tồn tại (V12 seed + admin set về sau): normalize sang
-- condition_json TƯƠNG ĐƯƠNG ngữ nghĩa — KHÔNG đổi rule_version (vẫn 1)
-- để evaluator phân biệt được rule gốc V1 vs rule admin viết tay V2.
-- COLLECTION_COUNT giữ ngữ nghĩa global (đếm mọi user_evidence) — rule
-- event-scoped mới phải dùng EVENT_EVIDENCE_COUNT của V2.
UPDATE item_unlock_rule
SET condition_json = CASE rule_type
    WHEN 'LESSON_COMPLETED' THEN
        jsonb_build_object('type', 'LESSON_COMPLETED',
                           'lessonId', lesson_id::text)
    WHEN 'COLLECTION_COUNT' THEN
        jsonb_build_object('type', 'COLLECTION_COUNT',
                           'threshold', threshold)
    WHEN 'LESSON_COUNT' THEN
        jsonb_build_object('type', 'LESSON_COUNT',
                           'threshold', threshold)
END
WHERE rule_version = 1 AND condition_json IS NULL;

-- ---------- user_inventory: provenance mở rộng (ITEM-03) ----------

ALTER TABLE user_inventory
    ADD COLUMN unlock_rule_id UUID REFERENCES item_unlock_rule(id),
    ADD COLUMN unlock_rule_version INTEGER,
    ADD COLUMN source_event_id UUID REFERENCES historical_events(id),
    ADD COLUMN cause_key TEXT;

CREATE UNIQUE INDEX ux_user_inventory_cause_key
    ON user_inventory(cause_key) WHERE cause_key IS NOT NULL;

-- acquisition_source: giữ nguyên giá trị cũ + nguồn V2. Trước hết gỡ
-- CHECK legacy của V12 rồi đặt lại danh sách đầy đủ — 'RULE_UNLOCK'
-- cho grant realtime bởi evaluator v2, 'RECONCILE_GRANT' cho backfill
-- (giữ ADMIN_GRANT vì reconcile V1 đã ghi và code đọc nó).
ALTER TABLE user_inventory DROP CONSTRAINT chk_inventory_source;
ALTER TABLE user_inventory
    ADD CONSTRAINT chk_inventory_source CHECK (acquisition_source IN (
        'LESSON_COMPLETED','COLLECTION_COUNT','LESSON_COUNT','ADMIN_GRANT',
        'RULE_UNLOCK','RECONCILE_GRANT'));

-- ---------- Seed audit: phân loại 8 item V12 ----------

-- Quy tắc phân loại (ghi vào rule_metadata.audit, không đoán event):
--   * 'valid-global': item không gắn một event cụ thể trong catalog seed
--     (HUY_HIEU_DIEN_BIEN_PHU LESSON_COUNT) — giữ nguyên.
--   * 'needs-mapping': item gắn mốc lịch sử cụ thể (Bạch Đằng, Hai Bà
--     Trưng, Cổ Loa, Thành nhà Hồ, Mỹ Sơn, Hội An, Đông Sơn) mà rule V1
--     đếm global → flag UNCONFIGURED-event trong metadata; admin phải
--     publish rule v2 event-scoped minh định (GAME-06 UI hoặc API). KHÔNG
--     tự gán eventId — không đoán mapping khi catalog không khai báo.
-- Ownership đã cấp giữ nguyên (EVT-05 / không revoke); item chỉ không
-- được grant MỚI tới khi có rule event-scoped đúng — evaluator v2 đọc
-- audit flag này và trạng thái event policy để quyết "unconfigured".
UPDATE item_unlock_rule r
SET rule_metadata = jsonb_build_object(
        'audit', 'needs-mapping',
        'note', 'V1 global-count cho item event-specific; chờ rule v2 '
              || 'event-scoped minh định (không tự gán eventId).')
FROM item_catalog c
WHERE r.item_id = c.id AND r.active = true
  AND c.code IN (
      'PHIEN_BAN_SO_COC_BACH_DANG',
      'PHIEN_BAN_SO_CO_LOA',
      'PHIEN_BAN_SO_PHO_HOI_AN',
      'MO_HINH_THANH_NHA_HO',
      'MO_HINH_TRONG_DONG_DONG_SON',
      'MO_HINH_CHUA_MY_SON',
      'HUY_HIEU_HAI_BA_TRUNG');

UPDATE item_unlock_rule r
SET rule_metadata = jsonb_build_object(
        'audit', 'valid-global',
        'note', 'Không gắn event cụ thể; giữ ngữ nghĩa global V1.')
FROM item_catalog c
WHERE r.item_id = c.id AND r.active = true
  AND c.code = 'HUY_HIEU_DIEN_BIEN_PHU';
