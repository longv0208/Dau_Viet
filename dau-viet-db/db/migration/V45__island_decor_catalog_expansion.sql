-- ============================================================
-- V45: Expand Heritage Island Decor Catalog & Shop Offers
-- Ensures at least 12 distinct placeable items exist in item_catalog
-- so Tier 3 Large Island (12 slots) can be completely decorated
-- without stacking duplicate items. Does NOT auto-grant free items.
-- ============================================================

INSERT INTO item_catalog (code, name, description, category, rarity, item_type, stackable, active, placeable, render_key)
VALUES
    ('decor_bui_tre', 'Bụi Tre Làng Cổ', 'Khóm tre xanh rì rào đầu làng, biểu tượng sức sống kiên cường của làng quê Việt.', 'DECOR', 'COMMON', 'DECOR', FALSE, TRUE, TRUE, 'decor.bui_tre'),
    ('decor_gieng_co', 'Giếng Cổ Đá Xanh', 'Giếng làng xây bằng đá xanh rêu phong, nơi lưu giữ mạch nguồn văn hóa.', 'DECOR', 'COMMON', 'DECOR', FALSE, TRUE, TRUE, 'decor.gieng_co'),
    ('decor_cong_lang', 'Cổng Làng Đá Ong', 'Cổng làng cổ kính xây bằng đá ong Xứ Đoài với mái vòm truyền thống.', 'DECOR', 'UNCOMMON', 'DECOR', FALSE, TRUE, TRUE, 'decor.cong_lang'),
    ('decor_den_long_hoi_an', 'Đèn Lồng Phố Cổ', 'Cụm đèn lồng lụa rực rỡ thắp sáng góc đảo di sản về đêm.', 'DECOR', 'UNCOMMON', 'DECOR', FALSE, TRUE, TRUE, 'decor.den_long_hoi_an'),
    ('decor_dinh_lang', 'Đình Làng Mái Đao', 'Ngôi đình cổ với mái đao cong vút, không gian sinh hoạt văn hóa cộng đồng.', 'DECOR', 'RARE', 'DECOR', FALSE, TRUE, TRUE, 'decor.dinh_lang'),
    ('decor_thuyen_rong', 'Thuyền Rồng Bến Nước', 'Chiếc thuyền rồng chạm khắc tinh xảo neo đậu bên bến nước di sản.', 'DECOR', 'RARE', 'DECOR', FALSE, TRUE, TRUE, 'decor.thuyen_rong'),
    ('decor_thap_but', 'Tháp Bút Truyền Thống', 'Ngọn tháp đá vươn cao tượng trưng cho tinh thần hiếu học ngàn đời.', 'DECOR', 'EPIC', 'DECOR', FALSE, TRUE, TRUE, 'decor.thap_but'),
    ('decor_khue_van_cac', 'Khuê Văn Các Thu Nhỏ', 'Mô phỏng lầu Khuê Văn biểu tượng văn hiến Thăng Long - Hà Nội.', 'DECOR', 'EPIC', 'DECOR', FALSE, TRUE, TRUE, 'decor.khue_van_cac')
ON CONFLICT (code) DO UPDATE
SET placeable = TRUE,
    render_key = COALESCE(item_catalog.render_key, EXCLUDED.render_key);

INSERT INTO island_shop_items (item_id, price_points, active, sort_order)
SELECT id,
       CASE code
           WHEN 'decor_bui_tre' THEN 120
           WHEN 'decor_gieng_co' THEN 150
           WHEN 'decor_cong_lang' THEN 180
           WHEN 'decor_den_long_hoi_an' THEN 200
           WHEN 'decor_dinh_lang' THEN 250
           WHEN 'decor_thuyen_rong' THEN 280
           WHEN 'decor_thap_but' THEN 320
           WHEN 'decor_khue_van_cac' THEN 350
           ELSE 150
       END,
       TRUE,
       CASE code
           WHEN 'decor_bui_tre' THEN 5
           WHEN 'decor_gieng_co' THEN 6
           WHEN 'decor_cong_lang' THEN 7
           WHEN 'decor_den_long_hoi_an' THEN 8
           WHEN 'decor_dinh_lang' THEN 9
           WHEN 'decor_thuyen_rong' THEN 10
           WHEN 'decor_thap_but' THEN 11
           WHEN 'decor_khue_van_cac' THEN 12
           ELSE 99
       END
FROM item_catalog
WHERE code IN (
    'decor_bui_tre',
    'decor_gieng_co',
    'decor_cong_lang',
    'decor_den_long_hoi_an',
    'decor_dinh_lang',
    'decor_thuyen_rong',
    'decor_thap_but',
    'decor_khue_van_cac'
)
ON CONFLICT (item_id) DO NOTHING;
