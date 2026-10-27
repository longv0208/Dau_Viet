-- ============================================================
-- V45: Expand Heritage Island Decor Catalog & Shop Offers
-- Ensures at least 12 distinct placeable items exist in item_catalog
-- so Tier 3 Large Island (12 slots) can be completely decorated
-- without stacking duplicate items. Does NOT auto-grant free items.
-- ============================================================

INSERT INTO item_catalog (
    id, code, name, description, category, item_type, rarity,
    placeable, render_key, source_metadata, active
)
VALUES
    ('d7d00000-0000-4000-8000-000000000005', 'DECOR_BUI_TRE',
     'Bụi Tre Làng Cổ',
     'Khóm tre xanh rì rào đầu làng trang trí Đảo Di Sản, biểu tượng sức sống kiên cường của làng quê Việt.',
     'DECOR', 'DECOR', 'COMMON',
     TRUE, 'decor.bui_tre',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000006', 'DECOR_GIENG_CO',
     'Giếng Cổ Đá Xanh',
     'Giếng làng xây bằng đá xanh rêu phong trang trí Đảo Di Sản, nơi lưu giữ mạch nguồn văn hóa.',
     'DECOR', 'DECOR', 'COMMON',
     TRUE, 'decor.gieng_co',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000007', 'DECOR_CONG_LANG',
     'Cổng Làng Đá Ong',
     'Cổng làng cổ kính xây bằng đá ong Xứ Đoài với mái vòm truyền thống trang trí Đảo Di Sản.',
     'DECOR', 'DECOR', 'UNCOMMON',
     TRUE, 'decor.cong_lang',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000008', 'DECOR_DEN_LONG_HOI_AN',
     'Đèn Lồng Phố Cổ',
     'Cụm đèn lồng lụa rực rỡ thắp sáng góc Đảo Di Sản.',
     'DECOR', 'DECOR', 'UNCOMMON',
     TRUE, 'decor.den_long_hoi_an',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000009', 'DECOR_DINH_LANG',
     'Đình Làng Mái Đao',
     'Ngôi đình cổ với mái đao cong vút trang trí Đảo Di Sản, không gian sinh hoạt văn hóa cộng đồng.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.dinh_lang',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000010', 'DECOR_THUYEN_RONG',
     'Thuyền Rồng Bến Nước',
     'Chiếc thuyền rồng chạm khắc tinh xảo neo đậu bên bến nước Đảo Di Sản.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.thuyen_rong',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000011', 'DECOR_THAP_BUT',
     'Tháp Bút Truyền Thống',
     'Mô hình Tháp Bút đá vươn cao trang trí Đảo Di Sản, tượng trưng cho tinh thần hiếu học ngàn đời.',
     'DECOR', 'DECOR', 'EPIC',
     TRUE, 'decor.thap_but',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000012', 'DECOR_KHUE_VAN_CAC',
     'Khuê Văn Các Thu Nhỏ',
     'Mô hình lầu Khuê Văn trang trí Đảo Di Sản, biểu tượng văn hiến Thăng Long - Hà Nội.',
     'DECOR', 'DECOR', 'EPIC',
     TRUE, 'decor.khue_van_cac',
     '{"note":"Vật phẩm trang trí Đảo Di Sản, không phải hiện vật lịch sử"}'::jsonb,
     TRUE)
ON CONFLICT (code) DO UPDATE
SET placeable = TRUE,
    render_key = COALESCE(item_catalog.render_key, EXCLUDED.render_key),
    updated_at = now();

INSERT INTO island_shop_items (item_id, price_points, active, sort_order)
SELECT c.id, v.price, TRUE, v.sort_order
FROM item_catalog c
JOIN (VALUES
    ('DECOR_BUI_TRE',         120, 5),
    ('DECOR_GIENG_CO',        150, 6),
    ('DECOR_CONG_LANG',       180, 7),
    ('DECOR_DEN_LONG_HOI_AN', 200, 8),
    ('DECOR_DINH_LANG',       250, 9),
    ('DECOR_THUYEN_RONG',     280, 10),
    ('DECOR_THAP_BUT',        320, 11),
    ('DECOR_KHUE_VAN_CAC',    350, 12)
) AS v(code, price, sort_order) ON v.code = c.code
ON CONFLICT (item_id) DO NOTHING;
