-- Dấu Việt | V32 | ISLAND-BE-01 Heritage Island + Wallet Core + Island Shop.
-- Phạm vi: backend Đảo Di Sản theo GAMIFICATION_TECHNICAL_CONTRACT §2.3 (wallet)
-- và GAMIFICATION_BUSINESS_RULES §5/§9 (Điểm Sử Ký chi tiêu, DECOR non-stackable).
-- Không sửa ngược bảng đã áp dụng; mọi ALTER là mở rộng CHECK/cột additive.
-- Không ghi dữ liệu user; seed chỉ gồm config có version + catalog/shop reference.

-- ================= wallet_accounts =================
-- Số dư Điểm Sử Ký spendable (POINT-10). Một row/(user,currency); V1 chỉ
-- HISTORY_POINTS — EXP không bao giờ vào wallet (không chi tiêu được).
-- balance CHECK >= 0 là backstop tầng DB (POINT-06); row_version giữ
-- optimistic lock phụ — đường ghi chính serialize qua findForUpdate.
CREATE TABLE wallet_accounts (
    user_id UUID NOT NULL REFERENCES users(id),
    currency VARCHAR(32) NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    row_version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_wallet_accounts PRIMARY KEY (user_id, currency),
    CONSTRAINT chk_wallet_currency CHECK (currency IN ('HISTORY_POINTS')),
    CONSTRAINT chk_wallet_balance CHECK (balance >= 0)
);

-- ================= wallet_transactions =================
-- Ledger append-only cho mọi biến động Điểm Sử Ký (POINT-05/08).
-- amount luôn > 0, chiều ở direction — KHÔNG BAO GIỜ ghi amount âm
-- (reward_transactions cũng giữ quy ước này, §5.4 note).
-- cause_key UNIQUE: 'BRIDGE:'||reward_transactions.id (credit cũ),
-- 'PURCHASE:'||purchaseKey (mua shop), 'REFILL:'||key (GAME-02/07 sau).
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    currency VARCHAR(32) NOT NULL,
    direction VARCHAR(8) NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(80) NOT NULL,
    cause_key VARCHAR(200) NOT NULL,
    source_ref VARCHAR(160),
    balance_after BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_wallet_tx_direction CHECK (direction IN ('CREDIT','DEBIT')),
    CONSTRAINT chk_wallet_tx_amount CHECK (amount > 0),
    CONSTRAINT chk_wallet_tx_currency CHECK (currency IN ('HISTORY_POINTS')),
    CONSTRAINT chk_wallet_tx_balance CHECK (balance_after >= 0),
    CONSTRAINT ux_wallet_tx_cause UNIQUE (cause_key)
);
CREATE INDEX idx_wallet_tx_user ON wallet_transactions(user_id, created_at DESC);

-- ================= island_tier_policies =================
-- Ngưỡng nâng cấp đảo, có version (NFR §14.3): thay đổi = config_version+1
-- (row mới), KHÔNG update ngược. Tier eligibility đếm từ user_event_progress
-- milestone EVENT_COMPLETED — chỉ sự kiện thật, không lesson đơn lẻ.
-- max_tier = bậc cao nhất policy này định nghĩa.
CREATE TABLE island_tier_policies (
    id UUID PRIMARY KEY,
    config_version INTEGER NOT NULL,
    tier INTEGER NOT NULL,
    slot_count INTEGER NOT NULL,
    required_completed_events INTEGER NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_island_tier CHECK (tier BETWEEN 1 AND 9),
    CONSTRAINT chk_island_slot_count CHECK (slot_count BETWEEN 1 AND 64),
    CONSTRAINT chk_island_required CHECK (required_completed_events >= 0),
    CONSTRAINT ux_island_tier_policy UNIQUE (config_version, tier)
);
-- Một (config_version, tier) active duy nhất tại một thời điểm (partial unique).
CREATE UNIQUE INDEX ux_island_tier_policy_active_version
    ON island_tier_policies(config_version, tier) WHERE active;

-- ================= island_slots =================
-- 12 ô đất catalog cố định của một layout đảo (V1: layout 'heritage-v1').
-- slot_index 1..12 duy nhất trong layout; tier_required là bậc đảo tối thiểu
-- để slot mở khoá. Toạ độ tương đối 0..1 để client render, không hard-px.
CREATE TABLE island_slots (
    id UUID PRIMARY KEY,
    layout_code VARCHAR(48) NOT NULL,
    slot_index INTEGER NOT NULL,
    tier_required INTEGER NOT NULL,
    coord_x DOUBLE PRECISION NOT NULL,
    coord_y DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_island_slot_idx CHECK (slot_index BETWEEN 1 AND 64),
    CONSTRAINT chk_island_slot_tier CHECK (tier_required BETWEEN 1 AND 9),
    CONSTRAINT chk_island_slot_coord CHECK (
        coord_x BETWEEN 0 AND 1 AND coord_y BETWEEN 0 AND 1),
    CONSTRAINT ux_island_slot UNIQUE (layout_code, slot_index)
);

-- ================= user_islands =================
-- Một đảo/user; tier nâng bởi user-initiated upgrade (POST /me/island/upgrade),
-- KHÔNG tự nâng, KHÔNG tự hạ khi policy đổi (policy copy-on-write giống
-- event_completion_policies — tier hiện hữu giữ nguyên dù config sau nới lỏng).
-- row_version phục vụ expectedRevision trên PUT/DELETE placements.
CREATE TABLE user_islands (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    tier INTEGER NOT NULL DEFAULT 1,
    layout_code VARCHAR(48) NOT NULL DEFAULT 'heritage-v1',
    row_version BIGINT NOT NULL DEFAULT 0,
    upgraded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_user_island_tier CHECK (tier BETWEEN 1 AND 9)
);

-- ================= user_island_placements =================
-- Vật phẩm decor đang đặt trên đảo. Hai unique đảm bảo tính vật lý V1:
-- một ô chứa tối đa một vật phẩm; một vật phẩm (non-stackable) xuất hiện
-- tối đa một lần trên đảo. item_id phải nằm trong user_inventory (checked
-- ở service — FK tới (user_id,item_id) composite của user_inventory).
CREATE TABLE user_island_placements (
    user_id UUID NOT NULL,
    slot_id UUID NOT NULL REFERENCES island_slots(id),
    item_id UUID NOT NULL REFERENCES item_catalog(id),
    placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_user_island_placements PRIMARY KEY (user_id, slot_id),
    CONSTRAINT ux_user_island_item UNIQUE (user_id, item_id),
    CONSTRAINT fk_user_island_owner FOREIGN KEY (user_id)
        REFERENCES users(id),
    CONSTRAINT fk_user_island_inv FOREIGN KEY (user_id, item_id)
        REFERENCES user_inventory(user_id, item_id)
);
CREATE INDEX idx_island_placements_user ON user_island_placements(user_id);

-- ================= island_shop_items =================
-- Chính sách bán tách khỏi catalog nội dung (plan quyết định 3): catalog là
-- content, shop là commerce — giá/cờ bán thay đổi độc lập item rule.
-- price_points NULL = chỉ trưng bày catalog, không bán (ITEM_NOT_FOR_SALE).
CREATE TABLE island_shop_items (
    item_id UUID PRIMARY KEY REFERENCES item_catalog(id),
    price_points BIGINT,
    active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_shop_price CHECK (price_points IS NULL OR price_points > 0)
);

-- ================= ALTER item_catalog =================
-- DECOR là item_type mới (BUSINESS §9.2): mua được, placeable được cấu hình
-- riêng — không gộp vào HISTORICAL_REPLICA vì type quyết định ngữ nghĩa
-- trưng bày. placeable/render_key additive, mặc định false/null cho item cũ.
ALTER TABLE item_catalog DROP CONSTRAINT chk_item_type;
ALTER TABLE item_catalog ADD CONSTRAINT chk_item_type CHECK (item_type IN (
    'HISTORICAL_REPLICA','DIGITAL_EDITION','COMMEMORATIVE_BADGE','DECOR'));
ALTER TABLE item_catalog ADD COLUMN placeable BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE item_catalog ADD COLUMN render_key VARCHAR(80);

-- ================= ALTER user_inventory =================
-- SHOP_PURCHASE: provenance mua qua shop — phân biệt grant rule/unlock.
-- Giữ nguyên toàn bộ giá trị V24 đã mở (RULE_UNLOCK/RECONCILE_GRANT) —
-- chỉ thêm SHOP_PURCHASE vào danh sách.
ALTER TABLE user_inventory DROP CONSTRAINT chk_inventory_source;
ALTER TABLE user_inventory ADD CONSTRAINT chk_inventory_source CHECK (
    acquisition_source IN ('LESSON_COMPLETED','COLLECTION_COUNT',
        'LESSON_COUNT','ADMIN_GRANT','RULE_UNLOCK','RECONCILE_GRANT',
        'SHOP_PURCHASE'));

-- ================= SEED =================
-- Config version 1: T1=4 slot miễn phí; T2=8 slot tại 2 EVENT_COMPLETED;
-- T3=12 slot tại 4 EVENT_COMPLETED (task ISLAND-BE-01). required=0 cho T1.
INSERT INTO island_tier_policies
    (id, config_version, tier, slot_count, required_completed_events, active)
VALUES
    (gen_random_uuid(), 1, 1, 4, 0, true),
    (gen_random_uuid(), 1, 2, 8, 2, true),
    (gen_random_uuid(), 1, 3, 12, 4, true);

-- 12 slot layout heritage-v1: 4 ô T1, 4 ô T2, 4 ô T3. Toạ độ lưới tương đối
-- 3x4 — client tự scale; giữ deterministic để IT assert slot_id/lock.
INSERT INTO island_slots
    (id, layout_code, slot_index, tier_required, coord_x, coord_y)
VALUES
    (gen_random_uuid(), 'heritage-v1', 1, 1, 0.15, 0.20),
    (gen_random_uuid(), 'heritage-v1', 2, 1, 0.50, 0.20),
    (gen_random_uuid(), 'heritage-v1', 3, 1, 0.85, 0.20),
    (gen_random_uuid(), 'heritage-v1', 4, 1, 0.15, 0.45),
    (gen_random_uuid(), 'heritage-v1', 5, 2, 0.50, 0.45),
    (gen_random_uuid(), 'heritage-v1', 6, 2, 0.85, 0.45),
    (gen_random_uuid(), 'heritage-v1', 7, 2, 0.15, 0.70),
    (gen_random_uuid(), 'heritage-v1', 8, 2, 0.50, 0.70),
    (gen_random_uuid(), 'heritage-v1', 9, 3, 0.85, 0.70),
    (gen_random_uuid(), 'heritage-v1', 10, 3, 0.15, 0.90),
    (gen_random_uuid(), 'heritage-v1', 11, 3, 0.50, 0.90),
    (gen_random_uuid(), 'heritage-v1', 12, 3, 0.85, 0.90);

-- DECOR catalog: 4 SKU trong task. DECOR_CAU_KIEU seed nhưng KHÔNG có row
-- trong island_shop_items (hoặc có nhưng price NULL → ITEM_NOT_FOR_SALE —
-- chọn price NULL để catalog vẫn hiển thị "sắp mở bán").
-- placeable=true chỉ cho 3 SKU bán; CAU_KIEU vẫn placeable về sau nên true.
INSERT INTO item_catalog
    (id, code, name, description, category, item_type, rarity,
     placeable, render_key, source_metadata, active)
VALUES
    ('d7d00000-0000-4000-8000-000000000001', 'DECOR_CAY_DA',
     'Cây đa cổ thụ',
     'Cây đa trang trí Đảo Di Sản — biểu tượng đầu làng quen thuộc trong '
     'không gian quê Việt. Mua bằng Điểm Sử Ký, đặt lên ô đất trống.',
     'DECOR', 'DECOR', 'COMMON',
     true, 'decor.cay_da',
     '{"note":"Vật phẩm trang trí, không phải hiện vật lịch sử"}'::jsonb,
     true),
    ('d7d00000-0000-4000-8000-000000000002', 'DECOR_NHA_TRANH',
     'Nhà tranh vách đất',
     'Nhà tranh ba gian trang trí Đảo Di Sản — kiểu nhà ở truyền thống '
     'nông thôn Bắc Bộ. Mua bằng Điểm Sử Ký.',
     'DECOR', 'DECOR', 'UNCOMMON',
     true, 'decor.nha_tranh',
     '{"note":"Vật phẩm trang trí, không phải hiện vật lịch sử"}'::jsonb,
     true),
    ('d7d00000-0000-4000-8000-000000000003', 'DECOR_HO_SEN',
     'Hồ sen',
     'Hồ sen trang trí Đảo Di Sản — biểu tượng thanh cao trong văn hoá '
     'Việt. Mua bằng Điểm Sử Ký.',
     'DECOR', 'DECOR', 'RARE',
     true, 'decor.ho_sen',
     '{"note":"Vật phẩm trang trí, không phải hiện vật lịch sử"}'::jsonb,
     true),
    ('d7d00000-0000-4000-8000-000000000004', 'DECOR_CAU_KIEU',
     'Cầu kiều mái cong',
     'Cầu gạch mái cong trang trí Đảo Di Sản — sẽ mở bán trong đợt shop '
     'kế tiếp. Hiện chỉ trưng bày trong catalog.',
     'DECOR', 'DECOR', 'RARE',
     true, 'decor.cau_kieu',
     '{"note":"Vật phẩm trang trí, chưa mở bán"}'::jsonb,
     true)
ON CONFLICT (code) DO NOTHING;

-- Shop pricing (BUSINESS §5.3): Cây đa 100, Nhà tranh 200, Hồ sen 300.
-- CAU_KIEU price NULL = catalog-only → POST /me/shop/purchases trả
-- ITEM_NOT_FOR_SALE. ON CONFLICT để migration re-run an toàn.
INSERT INTO island_shop_items (item_id, price_points, active, sort_order)
SELECT c.id, v.price, true, v.sort_order
FROM item_catalog c
JOIN (VALUES
    ('DECOR_CAY_DA',    100, 1),
    ('DECOR_NHA_TRANH', 200, 2),
    ('DECOR_HO_SEN',    300, 3),
    ('DECOR_CAU_KIEU',  NULL, 4)
) AS v(code, price, sort_order) ON v.code = c.code
ON CONFLICT (item_id) DO NOTHING;
