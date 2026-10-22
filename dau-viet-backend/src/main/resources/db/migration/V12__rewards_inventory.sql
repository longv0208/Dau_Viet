-- Dấu Việt MVP | V12 | TASK-0023 Rewards, Inventory & Item Unlock Rules.
-- item_catalog: danh mục vật phẩm server-side (mô hình/phiên bản số/huy hiệu
-- kỷ niệm — KHÔNG phải cổ vật thật, không bịa provenance). user_inventory
-- ghi một lần duy nhất mỗi (user, item): non-stackable, insert bởi unlock
-- evaluator, không bao giờ revoke khi rule đổi. item_unlock_rule là cấu hình
-- tối thiểu — admin quản qua API, không CMS đầy đủ.
CREATE TABLE item_catalog (
    id UUID PRIMARY KEY,
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(160) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    category VARCHAR(48) NOT NULL,
    item_type VARCHAR(48) NOT NULL,
    rarity VARCHAR(24) NOT NULL DEFAULT 'COMMON',
    asset_id UUID REFERENCES assets(id),
    source_metadata JSONB,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_item_type CHECK (item_type IN (
        'HISTORICAL_REPLICA','DIGITAL_EDITION','COMMEMORATIVE_BADGE')),
    CONSTRAINT chk_item_rarity CHECK (rarity IN (
        'COMMON','UNCOMMON','RARE','EPIC')),
    CONSTRAINT chk_item_source_meta CHECK (source_metadata IS NULL
        OR jsonb_typeof(source_metadata) = 'object')
);
CREATE INDEX idx_item_catalog_active ON item_catalog(active) WHERE active;

CREATE TABLE item_unlock_rule (
    id UUID PRIMARY KEY,
    item_id UUID NOT NULL REFERENCES item_catalog(id),
    rule_type VARCHAR(48) NOT NULL,
    -- LESSON_COMPLETED: lesson cụ thể; COLLECTION_COUNT: N evidence khác
    -- nhau trong bộ sưu tập; LESSON_COUNT: N bài khác nhau hoàn thành.
    lesson_id UUID REFERENCES lessons(id),
    threshold INTEGER,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_unlock_rule_type CHECK (rule_type IN (
        'LESSON_COMPLETED','COLLECTION_COUNT','LESSON_COUNT')),
    CONSTRAINT chk_unlock_rule_shape CHECK (
        (rule_type = 'LESSON_COMPLETED' AND lesson_id IS NOT NULL
            AND threshold IS NULL)
        OR (rule_type IN ('COLLECTION_COUNT','LESSON_COUNT')
            AND threshold IS NOT NULL AND threshold > 0
            AND lesson_id IS NULL))
);
-- Một rule type duy nhất mỗi item cho MVP (đủ cover catalog hiện tại; mở
-- rộng sau khi cần nhiều điều kiện OR).
CREATE UNIQUE INDEX ux_item_unlock_rule_item ON item_unlock_rule(item_id)
    WHERE active;
CREATE INDEX idx_item_unlock_rule_lesson ON item_unlock_rule(lesson_id)
    WHERE lesson_id IS NOT NULL;

CREATE TABLE user_inventory (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    item_id UUID NOT NULL REFERENCES item_catalog(id),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    acquisition_source VARCHAR(48) NOT NULL,
    source_lesson_id UUID REFERENCES lessons(id),
    -- Attempt đã kích hoạt unlock (kể cả rule đếm) — GET /attempts/{id}/result
    -- enrich "vật phẩm vừa mở khóa" mà không phải đoán theo acquired_at.
    source_attempt_id UUID REFERENCES learner_attempts(id),
    CONSTRAINT chk_inventory_source CHECK (acquisition_source IN (
        'LESSON_COMPLETED','COLLECTION_COUNT','LESSON_COUNT','ADMIN_GRANT')),
    CONSTRAINT ux_user_inventory UNIQUE (user_id, item_id)
);
CREATE INDEX idx_user_inventory_user ON user_inventory(user_id, acquired_at DESC);

-- Catalog khởi tạo: 8 vật phẩm gắn mốc lịch sử trong nội dung đã publish.
-- Tên/mô tả luôn ghi "Mô hình" / "Phiên bản số" / "Huy hiệu" — không gọi
-- là cổ vật/bảo vật quốc gia, không bịa xuất xứ. source_metadata trỏ tới
-- bảo tàng/đơn vị lưu giữ hiện vật thật để minh bạch tham chiếu.
INSERT INTO item_catalog (id, code, name, description, category, item_type,
                          rarity, source_metadata, active)
VALUES
    (gen_random_uuid(), 'MO_HINH_TRONG_DONG_DONG_SON',
     'Mô hình trống đồng Đông Sơn',
     'Mô hình thu nhỏ của trống đồng Đông Sơn — biểu tượng nền văn hóa Đông Sơn (khoảng thế kỷ VII TCN đến thế kỷ I SCN). Sưu tầm đủ bằng chứng khảo cổ để mở khóa.',
     'MO_HINH', 'HISTORICAL_REPLICA', 'RARE',
     '{"referenceArtifact":"Trống đồng Đông Sơn","heldBy":"Bảo tàng Lịch sử Quốc gia","note":"Mô hình phục vụ học tập, không phải hiện vật thật"}'::jsonb,
     true),
    (gen_random_uuid(), 'PHIEN_BAN_SO_COC_BACH_DANG',
     'Phiên bản số cọc ngầm Bạch Đằng',
     'Phiên bản số tái hiện cọc ngầm trận Bạch Đằng 938 — di chỉ cọc gỗ được nghiên cứu niên đại C-14. Mở khóa khi sưu tầm đủ tư liệu về trận thủy chiến.',
     'PHIEN_BAN_SO', 'DIGITAL_EDITION', 'UNCOMMON',
     '{"referenceSite":"Bãi cọc Yên Giang, Quảng Yên","note":"Tái hiện số cho mục đích giáo dục"}'::jsonb,
     true),
    (gen_random_uuid(), 'MO_HINH_THANH_NHA_HO',
     'Mô hình Thành nhà Hồ',
     'Mô hình thu nhỏ Thành nhà Hồ (Vĩnh Lộc, Thanh Hóa) — di sản thế giới UNESCO công nhận 2011. Sưu tầm đủ bằng chứng kiến trúc đá để mở khóa.',
     'MO_HINH', 'HISTORICAL_REPLICA', 'RARE',
     '{"referenceSite":"Thành nhà Hồ, Thanh Hóa","recognizedBy":"UNESCO World Heritage","note":"Mô hình phục vụ học tập"}'::jsonb,
     true),
    (gen_random_uuid(), 'PHIEN_BAN_SO_CO_LOA',
     'Phiên bản số thành Cổ Loa',
     'Phiên bản số sơ đồ ba vòng thành xoắn ốc Cổ Loa — kinh đô Âu Lạc thế kỷ III TCN. Mở khóa khi sưu tầm đủ tư liệu thời kỳ An Dương Vương.',
     'PHIEN_BAN_SO', 'DIGITAL_EDITION', 'UNCOMMON',
     '{"referenceSite":"Khu di tích Cổ Loa, Hà Nội","note":"Tái hiện số cho mục đích giáo dục"}'::jsonb,
     true),
    (gen_random_uuid(), 'HUY_HIEU_HAI_BA_TRUNG',
     'Huy hiệu kỷ niệm Hai Bà Trưng',
     'Huy hiệu kỷ niệm khởi nghĩa Hai Bà Trưng năm 40 — tinh thần độc lập đầu tiên sau thời kỳ Bắc thuộc. Mở khóa khi sưu tầm đủ bằng chứng về khởi nghĩa.',
     'HUY_HIEU', 'COMMEMORATIVE_BADGE', 'COMMON',
     '{"commemorates":"Khởi nghĩa Hai Bà Trưng, 40 SCN","note":"Huy hiệu kỷ niệm, không phải hiện vật"}'::jsonb,
     true),
    (gen_random_uuid(), 'MO_HINH_CHUA_MY_SON',
     'Mô hình tháp Mỹ Sơn',
     'Mô hình thu nhỏ tháp Chăm tại thánh địa Mỹ Sơn — di sản thế giới UNESCO 1999. Sưu tầm đủ bằng chứng về vương quốc Chăm Pa để mở khóa.',
     'MO_HINH', 'HISTORICAL_REPLICA', 'EPIC',
     '{"referenceSite":"Thánh địa Mỹ Sơn, Quảng Nam","recognizedBy":"UNESCO World Heritage","note":"Mô hình phục vụ học tập"}'::jsonb,
     true),
    (gen_random_uuid(), 'PHIEN_BAN_SO_PHO_HOI_AN',
     'Phiên bản số phố cổ Hội An',
     'Phiên bản số một góc phố cổ Hội An — thương cảng quốc tế thế kỷ XVI-XVII, di sản UNESCO 1999. Mở khóa khi sưu tầm đủ tư liệu thương mại.',
     'PHIEN_BAN_SO', 'DIGITAL_EDITION', 'UNCOMMON',
     '{"referenceSite":"Phố cổ Hội An","recognizedBy":"UNESCO World Heritage","note":"Tái hiện số cho mục đích giáo dục"}'::jsonb,
     true),
    (gen_random_uuid(), 'HUY_HIEU_DIEN_BIEN_PHU',
     'Huy hiệu kỷ niệm Điện Biên Phủ',
     'Huy hiệu kỷ niệm chiến dịch Điện Biên Phủ 1954. Mở khóa khi hoàn thành đủ số bài học đầu tiên của hành trình lịch sử.',
     'HUY_HIEU', 'COMMEMORATIVE_BADGE', 'COMMON',
     '{"commemorates":"Chiến dịch Điện Biên Phủ, 1954","note":"Huy hiệu kỷ niệm, không phải hiện vật"}'::jsonb,
     true);

-- Unlock rules: chỉ dùng COLLECTION_COUNT / LESSON_COUNT — hai loại không
-- cần lesson_id production (LESSON_COMPLETED do admin gán qua API sau khi
-- biết lesson thật). Ngưỡng chọn theo quy mô collection thực tế (49 evidence,
-- 25 lesson trong content pack).
INSERT INTO item_unlock_rule (id, item_id, rule_type, threshold, active)
SELECT gen_random_uuid(), c.id,
       CASE c.code
           WHEN 'HUY_HIEU_DIEN_BIEN_PHU' THEN 'LESSON_COUNT'
           ELSE 'COLLECTION_COUNT'
       END,
       CASE c.code
           WHEN 'HUY_HIEU_HAI_BA_TRUNG' THEN 3
           WHEN 'PHIEN_BAN_SO_COC_BACH_DANG' THEN 5
           WHEN 'PHIEN_BAN_SO_CO_LOA' THEN 6
           WHEN 'PHIEN_BAN_SO_PHO_HOI_AN' THEN 8
           WHEN 'MO_HINH_THANH_NHA_HO' THEN 10
           WHEN 'MO_HINH_TRONG_DONG_DONG_SON' THEN 12
           WHEN 'MO_HINH_CHUA_MY_SON' THEN 15
           WHEN 'HUY_HIEU_DIEN_BIEN_PHU' THEN 5
       END,
       true
FROM item_catalog c;
