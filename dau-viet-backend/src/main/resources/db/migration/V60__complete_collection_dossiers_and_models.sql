-- =============================================================================
-- Migration V60: Complete Dấu Việt Collection (Dossiers, Replicas/Models, Badges & Evidence Assets)
-- Purpose:
--   1. Backfill `asset_id` on all existing `historical_dossiers` and
--      `historical_dossier_versions` (V22/V28 seeded them with `asset_id = NULL`).
--   2. Seed additional canonical `historical_dossiers` (PERSON, LOCATION, ARTIFACT)
--      aligned with https://Historydauviet.id.vn and link them to `event_dossiers`.
--   3. Seed additional historical models (`MO_HINH`, `PHIEN_BAN_SO`, `HUY_HIEU`)
--      in `item_catalog` and backfill `asset_id` + `render_key` on all `item_catalog` rows.
--   4. Backfill missing `assetId` in `user_evidence.snapshot_json` from `evidences.asset_id`.
-- =============================================================================

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    asset_den_hung       UUID := 'd7a70000-0000-4000-8000-000000000001';
    asset_me_linh        UUID := 'd7a70000-0000-4000-8000-000000000002';
    asset_bach_dang_coc  UUID := 'd7a70000-0000-4000-8000-000000000003';
    asset_thang_long     UUID := 'd7a70000-0000-4000-8000-000000000004';
    asset_nhu_nguyet     UUID := 'd7a70000-0000-4000-8000-000000000005';
    asset_dien_bien      UUID := 'd7a70000-0000-4000-8000-000000000006';
    asset_dong_son_life  UUID := 'd7a70000-0000-4000-8000-000000000007';
    asset_tran_dia_coc   UUID := 'd7a70000-0000-4000-8000-000000000008';
    asset_doanh_trai     UUID := 'd7a70000-0000-4000-8000-000000000009';
    asset_thu_phong      UUID := 'd7a70000-0000-4000-8000-000000000010';
    asset_ngoquyen_hero  UUID := 'd7a70000-0000-4000-8000-000000000011';

    dos_hung_vuong       UUID := 'd7c10000-0000-4000-8000-000000000009';
    dos_an_duong_vuong   UUID := 'd7c10000-0000-4000-8000-000000000010';
    dos_ly_nam_de        UUID := 'd7c10000-0000-4000-8000-000000000011';
    dos_ly_thuong_kiet   UUID := 'd7c10000-0000-4000-8000-000000000012';
    dos_vo_nguyen_giap   UUID := 'd7c10000-0000-4000-8000-000000000013';
    dos_den_hung         UUID := 'd7c10000-0000-4000-8000-000000000014';
    dos_thanh_co_loa     UUID := 'd7c10000-0000-4000-8000-000000000015';
    dos_song_nhu_nguyet  UUID := 'd7c10000-0000-4000-8000-000000000016';
    dos_doi_a1           UUID := 'd7c10000-0000-4000-8000-000000000017';
    dos_trong_dong       UUID := 'd7c10000-0000-4000-8000-000000000018';
    dos_no_lien_chau     UUID := 'd7c10000-0000-4000-8000-000000000019';
    dos_chieu_doi_do     UUID := 'd7c10000-0000-4000-8000-000000000020';
    dos_nam_quoc_son_ha  UUID := 'd7c10000-0000-4000-8000-000000000021';
    dos_thuyen_bach_dang UUID := 'd7c10000-0000-4000-8000-000000000022';

    r RECORD;
BEGIN
    -- 1. Backfill asset_id on the 8 existing canonical historical_dossiers
    UPDATE historical_dossiers
    SET asset_id = CASE canonical_code
        WHEN 'ngo-quyen'        THEN asset_ngoquyen_hero
        WHEN 'trung-trac'       THEN asset_me_linh
        WHEN 'trung-nhi'        THEN asset_me_linh
        WHEN 'ly-thai-to'       THEN asset_thang_long
        WHEN 'song-bach-dang'   THEN asset_bach_dang_coc
        WHEN 'me-linh'          THEN asset_me_linh
        WHEN 'hoa-lu-dai-la'    THEN asset_thang_long
        WHEN 'coc-go-bach-dang' THEN asset_tran_dia_coc
        ELSE COALESCE(asset_id, asset_thu_phong)
    END,
    updated_at = now()
    WHERE asset_id IS NULL;

    -- 2. Seed additional canonical historical_dossiers (PERSON, LOCATION, ARTIFACT)
    INSERT INTO historical_dossiers
        (id, canonical_code, dossier_type, title, summary, description,
         source_json, asset_id, status, dossier_version, created_by)
    VALUES
        (dos_hung_vuong, 'hung-vuong', 'PERSON', 'Hùng Vương',
         'Danh hiệu các vị vua dựng nước Văn Lang — quốc gia đầu tiên của người Việt cổ trên lưu vực sông Hồng.',
         'Thời đại Hùng Vương mở đầu lịch sử dựng nước của dân tộc Việt Nam với nhà nước Văn Lang đóng đô ở Phong Châu (Phú Thọ), gắn liền với nền văn minh lúa nước và văn hóa Đông Sơn rực rỡ.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên","citation":"Ngoại kỷ, quyển 1, kỷ Hồng Bàng thị","reliability":"HIGH"}}'::jsonb,
         asset_den_hung, 'PUBLISHED', 1, sys_user),

        (dos_an_duong_vuong, 'an-duong-vuong', 'PERSON', 'An Dương Vương',
         'Vị vua lập nên nhà nước Âu Lạc (thế kỷ III TCN) và xây dựng tòa thành quân sự Cổ Loa độc đáo.',
         'An Dương Vương (Thục Phán) hợp nhất người Âu Việt và Lạc Việt lập ra nước Âu Lạc, dời đô về vùng đồng bằng Cổ Loa, xây thành ốc chín vòng và chế tạo nỏ Liên Châu bảo vệ bờ cõi.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên","citation":"Ngoại kỷ, quyển 1, kỷ Thục","reliability":"HIGH"}}'::jsonb,
         asset_dong_son_life, 'PUBLISHED', 1, sys_user),

        (dos_ly_nam_de, 'ly-nam-de', 'PERSON', 'Lý Nam Đế (Lý Bí)',
         'Lãnh tụ cuộc khởi nghĩa năm 542, xưng đế và lập nên nhà nước Vạn Xuân độc lập năm 544.',
         'Lý Bí khởi binh đánh đuổi thứ sử Tiêu Tư nhà Lương, giải phóng Giao Châu và tuyên bố thành lập nước Vạn Xuân vào mùa xuân năm 544, dựng điện Vạn Thọ và đúc tiền Thiên Đức khẳng định quyền tự chủ.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên","citation":"Ngoại kỷ, quyển 4, kỷ Tiền Lý","reliability":"HIGH"}}'::jsonb,
         asset_doanh_trai, 'PUBLISHED', 1, sys_user),

        (dos_ly_thuong_kiet, 'ly-thuong-kiet', 'PERSON', 'Thái úy Lý Thường Kiệt',
         'Danh tướng kiệt xuất thời nhà Lý, người chỉ huy phòng tuyến sông Như Nguyệt đánh bại đại quân Tống năm 1077.',
         'Thái úy Lý Thường Kiệt (1019–1105) nổi tiếng với tư tưởng quân sự "Tiên phát chế nhân" và nghệ thuật lập phòng tuyến sông Như Nguyệt kết hợp đòn phản công quyết định bảo vệ kinh thành Thăng Long.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên","citation":"Bản kỷ, quyển 3, kỷ Lý Nhân Tông","reliability":"HIGH"}}'::jsonb,
         asset_nhu_nguyet, 'PUBLISHED', 1, sys_user),

        (dos_vo_nguyen_giap, 'vo-nguyen-giap', 'PERSON', 'Đại tướng Võ Nguyên Giáp',
         'Tổng Tư lệnh Quân đội Nhân dân Việt Nam, Chỉ huy trưởng kiêm Bí thư Đảng ủy Chiến dịch Điện Biên Phủ (1954).',
         'Tại chiến dịch Điện Biên Phủ, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử chuyển phương châm từ "Đánh nhanh, thắng nhanh" sang "Đánh chắc, tiến chắc", đưa chiến dịch đến toàn thắng ngày 7/5/1954.',
         '{"source":{"title":"Viện Lịch sử Quân sự Việt Nam","citation":"Lịch sử Chiến dịch Điện Biên Phủ 1954","reliability":"HIGH"}}'::jsonb,
         asset_dien_bien, 'PUBLISHED', 1, sys_user),

        (dos_den_hung, 'den-hung-phong-chau', 'LOCATION', 'Kinh đô Phong Châu — Đền Hùng',
         'Trung tâm kinh đô nước Văn Lang cổ đại tại vùng núi Nghĩa Lĩnh, nơi hội tụ ba dòng sông lớn.',
         'Khu di tích lịch sử Đền Hùng trên núi Nghĩa Lĩnh (Phú Thọ) là vùng đất tổ cội nguồn của dân tộc Việt Nam, nơi các Vua Hùng dựng đô và mở mang nền văn minh sông Hồng.',
         '{"source":{"title":"Khu Di tích Lịch sử Đền Hùng","citation":"Hồ sơ di sản quốc gia đặc biệt Đền Hùng","reliability":"HIGH"}}'::jsonb,
         asset_den_hung, 'PUBLISHED', 1, sys_user),

        (dos_thanh_co_loa, 'thanh-co-loa', 'LOCATION', 'Thành Cổ Loa — Kinh đô Âu Lạc',
         'Tòa thành cổ hình xoắn ốc ba vòng khép kín gắn với hào nước tự nhiên thời An Dương Vương (thế kỷ III TCN).',
         'Thành Cổ Loa (Đông Anh, Hà Nội) là công trình phòng thủ quân sự quy mô lớn nhất thời cổ đại ở Việt Nam, kết hợp lũy đất cao, hào nước nối sông Hoàng Giang và hệ thống ụ tác chiến.',
         '{"source":{"title":"Trung tâm Bảo tồn Di sản Thăng Long — Hà Nội","citation":"Khu di tích Quốc gia đặc biệt Cổ Loa","reliability":"HIGH"}}'::jsonb,
         asset_dong_son_life, 'PUBLISHED', 1, sys_user),

        (dos_song_nhu_nguyet, 'song-nhu-nguyet', 'LOCATION', 'Phòng tuyến sông Như Nguyệt',
         'Chiến tuyến lũy đất và cọc tre dọc bờ nam sông Cầu chặn đứng 10 vạn quân Tống năm 1077.',
         'Đoạn sông Như Nguyệt (sông Cầu) có địa thế hiểm yếu che chắn phía bắc kinh thành Thăng Long. Quân dân nhà Lý đã dựng lũy đất cao kết hợp rào tre nhiều tầng và thủy quân cơ động.',
         '{"source":{"title":"Viện Sử học Việt Nam","citation":"Khảo cứu phòng tuyến sông Như Nguyệt thời Lý","reliability":"HIGH"}}'::jsonb,
         asset_nhu_nguyet, 'PUBLISHED', 1, sys_user),

        (dos_doi_a1, 'doi-a1-dien-bien', 'LOCATION', 'Đồi A1 & Lòng chảo Mường Thanh',
         'Cứ điểm then chốt phía đông bảo vệ sở chỉ huy tập đoàn cứ điểm Điện Biên Phủ năm 1954.',
         'Đồi A1 là điểm cao chiến lược bậc nhất tại phân khu Trung tâm Mường Thanh, nơi diễn ra cuộc chiến đấu giằng co ác liệt suốt 39 ngày đêm trước giờ tổng công kích.',
         '{"source":{"title":"Bảo tàng Chiến thắng Lịch sử Điện Biên Phủ","citation":"Hồ sơ di tích Đồi A1 — Điện Biên Phủ","reliability":"HIGH"}}'::jsonb,
         asset_dien_bien, 'PUBLISHED', 1, sys_user),

        (dos_trong_dong, 'trong-dong-dong-son', 'ARTIFACT', 'Trống đồng Đông Sơn',
         'Hiện vật tiêu biểu đỉnh cao của kỹ thuật đúc đồng và đời sống tinh thần cư dân Lạc Việt.',
         'Mặt trống đồng Đông Sơn chạm khắc ngôi sao nhiều cánh ở tâm, bao quanh là hình chim Lạc bay ngược chiều kim đồng hồ, cảnh giã gạo, đua thuyền và nhà sàn mái cong.',
         '{"source":{"title":"Bảo tàng Lịch sử Quốc gia","citation":"Bộ sưu tập Trống đồng Đông Sơn (Ngọc Lũ, Hoàng Hạ)","reliability":"HIGH"}}'::jsonb,
         asset_dong_son_life, 'PUBLISHED', 1, sys_user),

        (dos_no_lien_chau, 'no-lien-chau', 'ARTIFACT', 'Nỏ Liên Châu & Mũi tên đồng Cổ Loa',
         'Vũ khí bắn nhiều mũi tên đồng cùng lúc của quân đội Âu Lạc, khai quật tại kho mũi tên Cầu Vực (Cổ Loa).',
         'Hàng vạn mũi tên đồng ba cạnh sắc bén cùng khuôn đúc bằng đá tìm thấy tại di chỉ Cầu Vực — Cổ Loa là minh chứng khảo cổ học xác thực cho kỹ thuật quân sự vượt trội thời An Dương Vương.',
         '{"source":{"title":"Bảo tàng Lịch sử Quốc gia","citation":"Di chỉ kho mũi tên đồng Cầu Vực — Cổ Loa (1959)","reliability":"HIGH"}}'::jsonb,
         asset_dong_son_life, 'PUBLISHED', 1, sys_user),

        (dos_chieu_doi_do, 'chieu-doi-do', 'ARTIFACT', 'Thiên Đô Chiếu (Chiếu dời đô 1010)',
         'Văn kiện lịch sử trọng đại của vua Lý Thái Tổ tuyên bố dời đô từ Hoa Lư ra thành Đại La (Thăng Long).',
         'Được viết mùa xuân năm Thuận Thiên thứ nhất (1010), Chiếu dời đô thể hiện tầm nhìn chiến lược về thế đất "rồng cuộn hổ ngồi", mở đầu kỷ nguyên phát triển rực rỡ của quốc gia Đại Việt.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên","citation":"Bản kỷ, quyển 2, kỷ Lý Thái Tổ","reliability":"HIGH"}}'::jsonb,
         asset_thu_phong, 'PUBLISHED', 1, sys_user),

        (dos_nam_quoc_son_ha, 'nam-quoc-son-ha', 'ARTIFACT', 'Bài thơ thần Nam Quốc Sơn Hà',
         'Bản tuyên ngôn độc lập đầu tiên của dân tộc vang lên bên bờ sông Như Nguyệt mùa xuân năm 1077.',
         'Bốn câu thơ thất ngôn tứ tuyệt khẳng định chủ quyền lãnh thổ thiêng liêng "Sông núi nước Nam vua Nam ở / Rành rành định phận ở sách trời", cổ vũ tinh thần tướng sĩ Đại Việt.',
         '{"source":{"title":"Việt Điện U Linh Tập & Đại Việt sử ký toàn thư","citation":"Kỷ Lý Nhân Tông, năm 1077","reliability":"HIGH"}}'::jsonb,
         asset_thu_phong, 'PUBLISHED', 1, sys_user),

        (dos_thuyen_bach_dang, 'chien-thuyen-bach-dang', 'ARTIFACT', 'Chiến thuyền Ngô Quyền trên sông Bạch Đằng',
         'Đội thuyền chiến nhẹ cơ động dùng nhử thủy quân Nam Hán vào trận địa cọc ngầm năm 938.',
         'Quân Ngô Quyền sử dụng thuyền nhẹ thuận lợi luồn lách trên các nhánh sông và rừng sú vẹt ven sông Bạch Đằng, phối hợp nhịp nhàng với con nước thủy triều để bao vây hạm đội lớn của Lưu Hoằng Thao.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên","citation":"Ngoại kỷ, quyển 5, kỷ Ngô Quyền","reliability":"HIGH"}}'::jsonb,
         asset_ngoquyen_hero, 'PUBLISHED', 1, sys_user)
    ON CONFLICT (canonical_code) DO UPDATE SET
        asset_id    = COALESCE(historical_dossiers.asset_id, EXCLUDED.asset_id),
        summary     = EXCLUDED.summary,
        description = EXCLUDED.description,
        updated_at  = now();

    -- Sync historical_dossier_versions so every published dossier has an up-to-date snapshot with asset_id
    UPDATE historical_dossier_versions v
    SET asset_id = d.asset_id
    FROM historical_dossiers d
    WHERE v.dossier_id = d.id
      AND v.asset_id IS NULL
      AND d.asset_id IS NOT NULL;

    INSERT INTO historical_dossier_versions
        (id, dossier_id, dossier_version, dossier_type, title, summary,
         description, source_json, asset_id, status, published_at, published_by)
    SELECT gen_random_uuid(), d.id, d.dossier_version, d.dossier_type, d.title, d.summary,
           d.description, d.source_json, d.asset_id, d.status, d.updated_at, d.created_by
      FROM historical_dossiers d
     WHERE d.status = 'PUBLISHED'
       AND NOT EXISTS (
           SELECT 1 FROM historical_dossier_versions v
            WHERE v.dossier_id = d.id
              AND v.dossier_version = d.dossier_version);

    -- Link dossiers to canonical historical_events in event_dossiers
    FOR r IN (
        SELECT e.id AS event_id, d.id AS dossier_id,
               ROW_NUMBER() OVER (PARTITION BY e.id ORDER BY d.canonical_code) AS ord
          FROM historical_events e
          JOIN historical_dossiers d ON (
              (e.slug IN ('hung-vuong-van-lang', 'history-dong-son')
                  AND d.canonical_code IN ('hung-vuong', 'den-hung-phong-chau', 'trong-dong-dong-son', 'an-duong-vuong', 'thanh-co-loa', 'no-lien-chau'))
              OR (e.slug IN ('hai-ba-trung-40', 'khoi-nghia-hai-ba-trung-40')
                  AND d.canonical_code IN ('trung-trac', 'trung-nhi', 'me-linh'))
              OR (e.slug = 'history-ly-bi'
                  AND d.canonical_code IN ('ly-nam-de'))
              OR (e.slug = 'bach-dang-938'
                  AND d.canonical_code IN ('ngo-quyen', 'song-bach-dang', 'coc-go-bach-dang', 'chien-thuyen-bach-dang'))
              OR (e.slug IN ('ly-thai-to-1010', 'history-thang-long-1010')
                  AND d.canonical_code IN ('ly-thai-to', 'hoa-lu-dai-la', 'chieu-doi-do'))
              OR (e.slug = 'chien-thang-nhu-nguyet-1077'
                  AND d.canonical_code IN ('ly-thuong-kiet', 'song-nhu-nguyet', 'nam-quoc-son-ha'))
              OR (e.slug = 'chien-dich-dien-bien-phu-1954'
                  AND d.canonical_code IN ('vo-nguyen-giap', 'doi-a1-dien-bien'))
          )
    ) LOOP
        INSERT INTO event_dossiers (event_id, dossier_id, unlock_on, sort_order)
        VALUES (r.event_id, r.dossier_id, 'EVENT_COMPLETED', r.ord)
        ON CONFLICT (event_id, dossier_id) DO NOTHING;
    END LOOP;

    -- 3. Seed additional Models, Digital Editions & Badges in item_catalog (inspired by Historydauviet.id.vn)
    INSERT INTO item_catalog
        (id, code, name, description, category, item_type, rarity,
         asset_id, placeable, render_key, source_metadata, active)
    VALUES
        (gen_random_uuid(), 'MO_HINH_NO_LIEN_CHAU',
         'Mô hình Nỏ thần Liên Châu',
         'Mô hình thu nhỏ lẫy nỏ đồng và chùm mũi tên ba cạnh Cổ Loa thời An Dương Vương — biểu tượng sáng tạo kỹ thuật quân sự nước Âu Lạc.',
         'MO_HINH', 'HISTORICAL_REPLICA', 'RARE',
         asset_dong_son_life, true, 'replica.no_lien_chau',
         '{"referenceArtifact":"Lẫy nỏ và mũi tên đồng Cổ Loa","heldBy":"Bảo tàng Lịch sử Quốc gia","note":"Mô hình phục vụ học tập, không phải hiện vật thật"}'::jsonb,
         true),

        (gen_random_uuid(), 'MO_HINH_THUYEN_CHIEN_NGO_QUYEN',
         'Mô hình Chiến thuyền Ngô Quyền',
         'Mô hình chiến thuyền rồng Đại Việt với trống trận và cờ lệnh đỏ thắm chỉ huy trận thủy chiến sông Bạch Đằng năm 938.',
         'MO_HINH', 'HISTORICAL_REPLICA', 'EPIC',
         asset_ngoquyen_hero, true, 'replica.thuyen_chien_ngo_quyen',
         '{"referenceSite":"Khu di tích Bạch Đằng Giang, Hải Phòng — Quảng Ninh","note":"Mô hình phục vụ học tập"}'::jsonb,
         true),

        (gen_random_uuid(), 'MO_HINH_CHIEU_DOI_DO',
         'Phiên bản số Thiên Đô Chiếu',
         'Phiên bản số cuộn trục lụa золоt Thiên Đô Chiếu (Chiếu dời đô năm 1010) của vua Lý Thái Tổ kèm ấn triện Hoàng thành Thăng Long.',
         'PHIEN_BAN_SO', 'DIGITAL_EDITION', 'RARE',
         asset_thang_long, true, 'replica.chieu_doi_do',
         '{"referenceSite":"Hoàng thành Thăng Long, Hà Nội","recognizedBy":"UNESCO World Heritage","note":"Tái hiện số cho mục đích giáo dục"}'::jsonb,
         true),

        (gen_random_uuid(), 'MO_HINH_CHOI_CANH_BACH_DANG',
         'Mô hình Chòi canh Bạch Đằng',
         'Mô hình chòi canh gỗ trên cửa biển quan sát con nước thủy triều và hiệu lệnh mai phục trong chiến thắng Bạch Đằng 938.',
         'MO_HINH', 'HISTORICAL_REPLICA', 'UNCOMMON',
         asset_tran_dia_coc, true, 'replica.choi_canh_bach_dang',
         '{"referenceSite":"Cửa sông Bạch Đằng","note":"Mô hình phục vụ học tập và trang trí Đảo Di Sản"}'::jsonb,
         true),

        (gen_random_uuid(), 'HUY_HIEU_BACH_DANG_938',
         'Huy hiệu Đại thắng Bạch Đằng 938',
         'Huy hiệu kỷ niệm chiến thắng Bạch Đằng năm 938 của Đức Vương Ngô Quyền — mốc son chấm dứt hơn một thiên niên kỷ Bắc thuộc.',
         'HUY_HIEU', 'COMMEMORATIVE_BADGE', 'RARE',
         asset_bach_dang_coc, false, 'badge.bach_dang_938',
         '{"commemorates":"Chiến thắng Bạch Đằng, 938 SCN","note":"Huy hiệu kỷ niệm học tập"}'::jsonb,
         true),

        (gen_random_uuid(), 'HUY_HIEU_THANG_LONG_1010',
         'Huy hiệu Kinh đô Thăng Long 1010',
         'Huy hiệu kỷ niệm sự kiện vua Lý Thái Tổ dời đô về Đại La, khai mở kỷ nguyên văn hiến Thăng Long — Đông Đô — Hà Nội.',
         'HUY_HIEU', 'COMMEMORATIVE_BADGE', 'RARE',
         asset_thang_long, false, 'badge.thang_long_1010',
         '{"commemorates":"Chiếu dời đô & Kinh đô Thăng Long, 1010 SCN","note":"Huy hiệu kỷ niệm học tập"}'::jsonb,
         true)
    ON CONFLICT (code) DO UPDATE SET
        asset_id    = COALESCE(item_catalog.asset_id, EXCLUDED.asset_id),
        render_key  = COALESCE(item_catalog.render_key, EXCLUDED.render_key),
        description = EXCLUDED.description,
        updated_at  = now();

    -- Backfill asset_id and render_key on all existing item_catalog rows
    UPDATE item_catalog
    SET asset_id = CASE code
            WHEN 'MO_HINH_TRONG_DONG_DONG_SON'    THEN asset_dong_son_life
            WHEN 'PHIEN_BAN_SO_COC_BACH_DANG'     THEN asset_tran_dia_coc
            WHEN 'MO_HINH_THANH_NHA_HO'           THEN asset_thang_long
            WHEN 'PHIEN_BAN_SO_CO_LOA'            THEN asset_den_hung
            WHEN 'HUY_HIEU_HAI_BA_TRUNG'          THEN asset_me_linh
            WHEN 'MO_HINH_CHUA_MY_SON'            THEN asset_thu_phong
            WHEN 'PHIEN_BAN_SO_PHO_HOI_AN'        THEN asset_thu_phong
            WHEN 'HUY_HIEU_DIEN_BIEN_PHU'         THEN asset_dien_bien
            WHEN 'MO_HINH_NO_LIEN_CHAU'           THEN asset_dong_son_life
            WHEN 'MO_HINH_THUYEN_CHIEN_NGO_QUYEN' THEN asset_ngoquyen_hero
            WHEN 'MO_HINH_CHIEU_DOI_DO'           THEN asset_thang_long
            WHEN 'MO_HINH_CHOI_CANH_BACH_DANG'    THEN asset_tran_dia_coc
            WHEN 'HUY_HIEU_BACH_DANG_938'         THEN asset_bach_dang_coc
            WHEN 'HUY_HIEU_THANG_LONG_1010'       THEN asset_thang_long
            WHEN 'DECOR_CAY_DA'                   THEN asset_den_hung
            WHEN 'DECOR_NHA_TRANH'                THEN asset_dong_son_life
            WHEN 'DECOR_HO_SEN'                   THEN asset_thang_long
            WHEN 'DECOR_CAU_KIEU'                 THEN asset_thu_phong
            WHEN 'DECOR_BUI_TRE'                  THEN asset_den_hung
            WHEN 'DECOR_GIENG_CO'                 THEN asset_dong_son_life
            WHEN 'DECOR_CONG_LANG'                THEN asset_den_hung
            WHEN 'DECOR_DEN_LONG_HOI_AN'          THEN asset_thu_phong
            WHEN 'DECOR_DINH_LANG'                THEN asset_den_hung
            WHEN 'DECOR_THUYEN_RONG'              THEN asset_ngoquyen_hero
            WHEN 'DECOR_THAP_BUT'                 THEN asset_thang_long
            WHEN 'DECOR_KHUE_VAN_CAC'             THEN asset_thang_long
            WHEN 'DECOR_COT_CO'                   THEN asset_thang_long
            WHEN 'DECOR_TUONG_LY_THAI_TO'         THEN asset_thang_long
            WHEN 'DECOR_CAY_DAO'                  THEN asset_me_linh
            ELSE COALESCE(asset_id, asset_den_hung)
        END,
        render_key = CASE code
            WHEN 'HUY_HIEU_HAI_BA_TRUNG'  THEN 'badge.hai_ba_trung'
            WHEN 'HUY_HIEU_DIEN_BIEN_PHU' THEN 'badge.dien_bien_phu'
            ELSE render_key
        END,
        updated_at = now()
    WHERE asset_id IS NULL OR render_key IS NULL;

    -- Seed unlock rules for the new collection items if not yet present
    INSERT INTO item_unlock_rule (id, item_id, rule_type, threshold, rule_version, revision, condition_json, rule_metadata, active)
    SELECT gen_random_uuid(), ic.id, 'RULE_V2', NULL, 2, 1,
           '{"type":"COLLECTION_COUNT","threshold":2}'::jsonb,
           '{"audit":"valid-global"}'::jsonb,
           true
      FROM item_catalog ic
     WHERE ic.code IN (
         'MO_HINH_NO_LIEN_CHAU',
         'MO_HINH_THUYEN_CHIEN_NGO_QUYEN',
         'MO_HINH_CHIEU_DOI_DO',
         'MO_HINH_CHOI_CANH_BACH_DANG',
         'HUY_HIEU_BACH_DANG_938',
         'HUY_HIEU_THANG_LONG_1010'
     )
       AND NOT EXISTS (
           SELECT 1 FROM item_unlock_rule iur WHERE iur.item_id = ic.id AND iur.active = true
       );

    -- 4. Backfill missing assetId in user_evidence.snapshot_json from evidences.asset_id
    UPDATE user_evidence ue
    SET snapshot_json = jsonb_set(ue.snapshot_json, '{evidence,assetId}', to_jsonb(ev.asset_id::text), true)
    FROM evidences ev
    WHERE ue.evidence_id = ev.id
      AND ev.asset_id IS NOT NULL
      AND ue.snapshot_json IS NOT NULL
      AND ue.snapshot_json ? 'evidence'
      AND (ue.snapshot_json->'evidence'->>'assetId' IS NULL OR ue.snapshot_json->'evidence'->>'assetId' = '');
END $$;
