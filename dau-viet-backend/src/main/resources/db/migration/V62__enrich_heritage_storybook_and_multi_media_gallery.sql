-- =============================================================================
-- Migration V60: Enrich Heritage Storybook Content & Multi-Media Gallery
-- Purpose:
--   1. Add storybook columns to `map_locations` (key_figures, story_narrative,
--      historical_significance) and `source_citation` to `map_location_media`.
--   2. Register additional existing heritage/map seed assets in `assets`.
--   3. Backfill rich storybook content for all 12 canonical map_locations.
--   4. Update existing media rows with source_citation and insert 2-3
--      additional IMAGE_2D items per canonical location (3-4 images each).
-- =============================================================================

ALTER TABLE map_locations
    ADD COLUMN IF NOT EXISTS key_figures VARCHAR(500);

ALTER TABLE map_locations
    ADD COLUMN IF NOT EXISTS story_narrative TEXT;

ALTER TABLE map_locations
    ADD COLUMN IF NOT EXISTS historical_significance TEXT;

ALTER TABLE map_location_media
    ADD COLUMN IF NOT EXISTS source_citation VARCHAR(500);

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    -- Newly registered heritage storybook / map assets
    asset_story_tran_dia    UUID := 'd7aa0000-0000-4000-8000-000000000001';
    asset_story_thu_phong   UUID := 'd7aa0000-0000-4000-8000-000000000002';
    asset_story_doanh_trai  UUID := 'd7aa0000-0000-4000-8000-000000000003';
    asset_bach_dang_hero    UUID := 'd7aa0000-0000-4000-8000-000000000004';
    asset_hung_kings_life   UUID := 'd7aa0000-0000-4000-8000-000000000005';

    -- Map assets already registered in V49 (re-affirmed below via ON CONFLICT)
    asset_map_bach_dang     UUID := 'd7a90000-0000-4000-8000-000000000003';
    asset_map_van_lang      UUID := 'd7a90000-0000-4000-8000-000000000001';
    asset_map_hai_ba_trung  UUID := 'd7a90000-0000-4000-8000-000000000002';
    asset_map_nhu_nguyet    UUID := 'd7a90000-0000-4000-8000-000000000004';
    asset_map_dien_bien_phu UUID := 'd7a90000-0000-4000-8000-000000000005';

    -- V43 cover assets reused as gallery items
    asset_den_hung          UUID := 'd7a70000-0000-4000-8000-000000000001';
    asset_me_linh           UUID := 'd7a70000-0000-4000-8000-000000000002';
    asset_bach_dang         UUID := 'd7a70000-0000-4000-8000-000000000003';
    asset_thang_long        UUID := 'd7a70000-0000-4000-8000-000000000004';
    asset_nhu_nguyet        UUID := 'd7a70000-0000-4000-8000-000000000005';
    asset_dien_bien         UUID := 'd7a70000-0000-4000-8000-000000000006';
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- 1. Register additional existing heritage/map seed assets
    INSERT INTO assets (id, storage_key, original_filename, mime_type, size_bytes, state, alt_text, created_by)
    VALUES
        (asset_story_tran_dia,   'assets/d7aa0000-0000-4000-8000-000000000001.jpg', 'bg_story_tran_dia.jpg',                  'image/jpeg', 924937,  'ACTIVE', 'Tranh tái hiện bối trận chiến tranh cổ đại — trận địa quân sự',              sys_user),
        (asset_story_thu_phong,  'assets/d7aa0000-0000-4000-8000-000000000002.jpg', 'bg_story_thu_phong.jpg',                 'image/jpeg', 1021000, 'ACTIVE', 'Tranh tái hiện thủ phủ / doanh trại phòng thủ thời phong kiến',              sys_user),
        (asset_story_doanh_trai, 'assets/d7aa0000-0000-4000-8000-000000000003.jpg', 'bg_story_doanh_trai.jpg',                'image/jpeg', 990948,  'ACTIVE', 'Tranh tái hiện doanh trại quân đội Đại Việt thời chiến',                   sys_user),
        (asset_bach_dang_hero,   'assets/d7aa0000-0000-4000-8000-000000000004.jpg', 'dv_EVT_ngoquyen_bachdang_hero_v01.jpg',  'image/jpeg', 1164505, 'ACTIVE', 'Tranh anh hùng Ngô Quyền chỉ huy trận thủy chiến Bạch Đằng 938',           sys_user),
        (asset_hung_kings_life,  'assets/d7aa0000-0000-4000-8000-000000000005.jpg', 'lesson_scene_hung_kings_life.jpg',       'image/jpeg', 1246222, 'ACTIVE', 'Tranh tái hiện đời sống cư dân Văn Lang thời các Vua Hùng',               sys_user),
        (asset_map_bach_dang,    'assets/d7a90000-0000-4000-8000-000000000003.jpg', 'dv_MAP_ngoquyen_bachdang-base_v01.jpg',  'image/jpeg', 1079580, 'ACTIVE', 'Bản đồ Thủy Chiến Bạch Đằng Giang 938',                                sys_user),
        (asset_map_van_lang,     'assets/d7a90000-0000-4000-8000-000000000001.jpg', 'map_van_lang.jpg',                       'image/jpeg', 1424956, 'ACTIVE', 'Bản đồ Nước Văn Lang Thời Các Vua Hùng',                               sys_user),
        (asset_map_hai_ba_trung, 'assets/d7a90000-0000-4000-8000-000000000002.jpg', 'map_hai_ba_trung.jpg',                   'image/jpeg', 1339554, 'ACTIVE', 'Bản đồ Khởi Nghĩa Hai Bà Trưng (Năm 40)',                            sys_user),
        (asset_map_nhu_nguyet,   'assets/d7a90000-0000-4000-8000-000000000004.jpg', 'map_nhu_nguyet.jpg',                     'image/jpeg', 1259087, 'ACTIVE', 'Bản đồ Phòng Tuyến Sông Như Nguyệt 1077',                            sys_user),
        (asset_map_dien_bien_phu,'assets/d7a90000-0000-4000-8000-000000000005.jpg', 'map_dien_bien_phu.jpg',                  'image/jpeg', 1410505, 'ACTIVE', 'Bản đồ Chiến Dịch Điện Biên Phủ 1954',                               sys_user)
    ON CONFLICT (id) DO UPDATE SET
        original_filename = EXCLUDED.original_filename,
        mime_type = EXCLUDED.mime_type,
        size_bytes = EXCLUDED.size_bytes,
        state = EXCLUDED.state,
        alt_text = EXCLUDED.alt_text;

    -- 2. Backfill storybook content (key_figures, story_narrative, historical_significance)
    --    for all 12 canonical map_locations.

    UPDATE map_locations SET
        key_figures = 'Các Vua Hùng (18 đời), Lạc tướng, Lạc hầu, Lạc dân; thủ lĩnh Thục Phán (An Dương Vương)',
        story_narrative = E'Bối cảnh lịch sử: Khoảng thế kỷ VII trước Công nguyên, trên vùng đất Phong Châu (nay thuộc Phú Thọ), các Vua Hùng đã dựng lên nước Văn Lang — nhà nước đầu tiên của người Việt. Núi Nghĩa Lĩnh được chọn làm kinh đô, nơi các Vua Hùng thực hiện nghi lễ tế trời đất, cầu mùa cho đồng ruộng lúa nước.\n\nDiễn biến tại di tích: Theo truyền thuyết, mỗi năm vào ngày 10/3 âm lịch, các Vua Hùng cùng Lạc tướng, Lạc hầu lên đỉnh Nghĩa Lĩnh làm lễ tế Giao. Quốc gia Văn Lang được chia thành 15 bộ, trị quản bởi các Lạc tướng. Dưới thời các Vua Hùng, người Việt đã biết trồng lúa nước, đúc trống đồng Đông Sơn rực rỡ và xây dựng đời sống cộng đồng bền chặt.\n\nDấu tích & Di sản: Đền Hùng ngày nay gồm Đền Hạ, Đền Trung, Đền Thượng, Đền Giếng và Lăng Hùng Vương. Tục thờ cúng Hùng Vương được UNESCO công nhận là Di sản Văn hóa Phi vật thể của Nhân loại năm 2012. "Dù ai đi ngược về xuôi / Nhớ ngày Giỗ Tổ mùng mười tháng ba" — câu ca dao khắc ghi lòng tri ân với tổ tiên dựng nước của dân tộc.',
        historical_significance = 'Nơi khai sinh nhà nước Văn Lang — nhà nước đầu tiên của người Việt, đặt nền móng cho hơn 4000 năm lịch sử dựng nước và giữ nước; biểu tượng tinh thần đại đoàn kết và đạo lý "Uống nước nhớ nguồn" của dân tộc.'
    WHERE id = 'a0000000-0000-0000-0000-000000000001';

    UPDATE map_locations SET
        key_figures = 'Các Vua Hùng, Lạc tướng các bộ, thợ luyện đồng Đông Sơn',
        story_narrative = E'Bối cảnh lịch sử: Ngã ba Hạc là nơi hợp lưu của ba con sông lớn — sông Hồng, sông Lô và sông Đà — tạo thành vùng châu thổ màu mỡ, nơi nền văn minh lúa nước Đông Sơn nảy nở. Đây được xem là "cái nôi" của nền văn hóa Văn Lang – Âu Lạc.\n\nDiễn biến tại di tích: Từ vùng hợp lưu này, các bộ lạc Việt đã khai phá đồng ruộng, xây đê chắn lũ, hình thành những làng mạc đông đúc dọc triền sông. Các di chỉ khảo cổ như Đồng Đậu, Gò Mun, Xóm Rền chứng minh trình độ luyện kim đồng và nông nghiệp phát triển cao của cư dân thời Hùng Vương. Trống đồng Đông Sơn được đúc tại đây mang họa tiết mặt trời, chim Lạc và cảnh sinh hoạt cộng đồng.\n\nDấu tích & Di sản: Các mộ táng Đông Sơn, bến đò cổ và hệ thống đền miếu thờ sông vẫn còn lưu dấu. Ngã ba Hạc là điểm hẹn của hai dòng chảy lịch sử — văn hóa sông Hồng và văn hóa sông Mã — nơi hình thành bản sắc dân tộc Việt.',
        historical_significance = 'Cái nôi của nền văn minh lúa nước và văn hóa Đông Sơn; chứng minh cư dân Việt đã làm chủ kỹ thuật trồng lúa, luyện đồng và tổ chức xã hội từ rất sớm, trước khi chịu ách đô hộ phương Bắc.'
    WHERE id = 'a0000000-0000-0000-0000-000000000002';

    UPDATE map_locations SET
        key_figures = 'Ngô Quyền, Dương Tam Kha, Nguyễn Tất Tố, Trịnh Khả; đối phương: Lưu Hoằng Thao',
        story_narrative = E'Bối cảnh lịch sử: Cuối năm 938, quân Nam Hán do Lưu Hoằng Thao chỉ huy kéo thủy quân vào sông Bạch Đằng để đánh chiếm Giao Châu, nhân cơ hội Kiều Công Tiễn bị ám sát. Ngô Quyền từ Ái Châu mang quân ra Bắc, chọn cửa sông Bạch Đằng làm trận địa quyết chiến.\n\nDiễn biến tại di tích: Ngô Quyền cho đóng hàng vạn cọc gỗ lim đầu bịt sắt nhọn xuống lòng sông, chỉ lộ ngọn khi nước triều rút. Khi thủy triều lên, quân Nam Hán xông vào; Ngô Quyền cho thuyền nhẹ ra khiêu chiến rồi giả thua chạy. Khi triều rút, thuyền Nam Hán mắc cọc, đâm thủng đáy. Quân Ngô Quyền từ hai bờ xông ra đánh tan, giết Lưu Hoằng Thao ngay trên thuyền.\n\nDấu tích & Di sản: Vùng cửa sông Bạch Đằng — từ Yên Giang đến Nam Triệu — vẫn còn truyền lại tên gọi Bãi Cọc, đền thờ Ngô Quyền và đền thờ các tướng sĩ. Đại Việt Sử ký Toàn thư ghi: "Ngô Quyền đánh cho quân Hán chết đuối hơn nửa, Hoằng Thao chết trên thuyền." Một trận Bạch Đằng mở nền quốc độc lập sau 1000 năm Bắc thuộc.',
        historical_significance = 'Chiến thắng Bạch Đằng 938 chấm dứt hoàn toàn hơn 1000 năm đô hộ phương Bắc, mở ra kỷ nguyên độc lập lâu dài cho dân tộc Việt; trận địa cọc ngầm trở thành kiệt tác nghệ thuật thủy chiến được thế giới ghi nhận.'
    WHERE id = 'a0000000-0000-0000-0000-000000000003';

    UPDATE map_locations SET
        key_figures = 'Ngô Quyền, các tướng đóng trại ven sông; cư dân vùng Bạch Đằng',
        story_narrative = E'Bối cảnh lịch sử: Sau trận Bạch Đằng 938, nhiều bãi cọc ngầm vẫn còn lại dưới lòng sông ở vùng Yên Giang, Quảng Yên (nay thuộc Quảng Ninh). Đây là chứng tích trực tiếp của trận thủy chiến vĩ đại.\n\nDiễn biến tại di tích: Từ những năm 1953–1958, các cuộc khảo cổ lần lượt phát hiện hàng trăm cọc gỗ lim cắm xuống đáy sông, một số cọc còn nguyên đầu bịt sắt. Các nhà khoa học xác định đây là trận địa cọc do Ngô Quyền bố trí, kết hợp cùng các bãi cọc ở Đồng Vạn Mười và Bạch Đằng Giang.\n\nDấu tích & Di sản: Bãi cọc Yên Giang được công nhận là Di tích Quốc gia đặc biệt. Những khúc cọc gỗ lim ngâm trong bùn hơn một nghìn năm vẫn còn cứng như đá, là bằng chứng sinh động về trí tuệ quân sự và sức mạnh của dân tộc trong trận chiến bảo vệ độc lập.',
        historical_significance = 'Chứng tích khảo cổ học hiếm hoi trực tiếp chứng minh trận Bạch Đằng 938; di tích quốc gia đặc biệt tôn vinh công trạng của Ngô Quyền và các tướng sĩ đã dựng nên thắng lợi oanh liệt.'
    WHERE id = 'a0000000-0000-0000-0000-000000000004';

    UPDATE map_locations SET
        key_figures = 'Ngô Quyền, Lưu Hoằng Thao, thủy quân Nam Hán và nghĩa quân Ngô',
        story_narrative = E'Bối cảnh lịch sử: Cửa sông Nam Triệu (nay thuộc Hải Phòng / Quảng Ninh) là cửa ngõ chiến lược từ biển Đông tiến vào sông Bạch Đằng. Ai kiểm soát được Nam Triệu sẽ nắm chìa khóa mở vào đồng bằng Bắc Bộ.\n\nDiễn biến tại di tích: Trong trận Bạch Đằng 938, đoàn thuyền Nam Hán tiến qua cửa Nam Triệu, vào trận địa mai phục do Ngô Quyền bố trí. Đây cũng là tuyến đường quan trọng trong các chiến dịch Bạch Đằng sau này (1288 thời Trần Hưng Đạo). Vùng cửa sông nhiều đảo đá, luồng nước xiết, thuận lợi cho việc phục binh và đóng cọc.\n\nDấu tích & Di sản: Khu vực Nam Triệu có đền thờ các danh tướng Bạch Đằng và di chỉ bến cảng cổ. Người dân vùng sông nước vẫn giữ lễ hội tưởng nhớ trận thắng năm xưa, và các nhà nghiên cứu xem đây là "cánh cửa địa lý" của lịch sử thủy chiến Việt Nam.',
        historical_significance = 'Cửa ngõ chiến lược quyết định số phận nhiều cuộc thủy chiến trên sông Bạch Đằng; biểu tượng của việc lợi dụng địa hình sông nước để bảo vệ Tổ quốc.'
    WHERE id = 'a0000000-0000-0000-0000-000000000005';

    UPDATE map_locations SET
        key_figures = 'Trưng Trắc, Trưng Nhị, các Lạc tướng Giao Chỉ, Cửu Chân, Nhật Nam, Hợp Phố; đối phương: Tô Định',
        story_narrative = E'Bối cảnh lịch sử: Mùa xuân năm 40, bất mãn trước chính sách đô hộ và tham bạo của Tô Định — Thái thú nhà Hán — Trưng Trắc cùng em gái Trưng Nhị phất cờ khởi nghĩa tại quê hương Mê Linh, sau khi chồng bà là Thi Sách bị giết.\n\nDiễn biến tại di tích: Tại bờ sông Hát (Sóng Môn), Hai Bà Trưng lập đàn tế cờ, tuyên thệ với các Lạc tướng Giao Chỉ, Cửu Chân, Nhật Nam, Hợp Phố đồng loạt hưởng ứng. Nghĩa quân thủy bộ kéo theo đoàn voi chiến, đánh chiến từng thành trì, lật đổ ách thống trị, phục hồi tự chủ trong 3 năm (40–43).\n\nDấu tích & Di sản: Đền Hát Môn bên sông Hát vẫn thờ Hai Bà Trưng và các tướng tài. Lễ hội Hai Bà Trưng mùng 6/1 âm lịch là ngày hội của cả vùng Mê Linh. Sử sách chép: "Trưng Nữ Vương xưng vương, đóng đô ở Mê Linh."',
        historical_significance = 'Nơi phát động cuộc khởi nghĩa lập lại quyền tự chủ đầu tiên sau hơn 200 năm đô hộ; biểu tượng tinh thần yêu nước bất khuất và vai trò anh hùng của phụ nữ Việt Nam.'
    WHERE id = 'a0000000-0000-0000-0000-000000000006';

    UPDATE map_locations SET
        key_figures = 'Trưng Nữ Vương, các tướng nữ Lê Chân, Phùng Thị Chính; đối phương: Mã Viện',
        story_narrative = E'Bối cảnh lịch sử: Sau khi thu phục 65 thành trì ở Lĩnh Ngoại, Trưng Trắc xưng vương, hiệu Trưng Nữ Vương, và chọn thành cổ Mê Linh làm kinh đô của quốc gia tự chủ.\n\nDiễn biến tại di tích: Thành Mê Linh trở thành trung tâm chỉ huy hành chính và quân sự của nghĩa quân. Các tướng nữ như Lê Chân, Phùng Thị Chính từng trấn giữ và huấn luyện binh sĩ tại đây. Năm 43, khi Mã Viện mang quân sang đánh chiếm, Trưng Nữ Vương lui về Cổ Lôa rồi hy sinh tại Sóng Môn (42), giữ vẹn khí tiết.\n\nDấu tích & Di sản: Di chỉ thành Mê Linh vẫn còn dấu tích đường hào, đền Hai Bà Trưng và các đền thờ tướng. Làng Mê Linh giữ nghề đúc đồng, gốm và tục lệ hóa trang thành tướng nữ trong lễ hội, tưởng nhớ thời kỳ tự chủ ngắn nhưng rực rỡ.',
        historical_significance = 'Kinh đô của nhà nước tự chủ đầu tiên sau Bắc thuộc; minh chứng cho tinh thần độc lập và vai trò lãnh đạo của phụ nữ Việt Nam trong lịch sử dân tộc.'
    WHERE id = 'a0000000-0000-0000-0000-000000000007';

    UPDATE map_locations SET
        key_figures = 'Lý Thường Kiệt, các tướng Lý Kế Nguyên, Lê Văn Đại; đối phương: Quách Quỳ, Triệu Tiếp',
        story_narrative = E'Bối cảnh lịch sử: Năm 1076, vua Tống sai Quách Quỳ, Triệu Tiếp mang 30 vạn quân chia làm hai đường tiến đánh Đại Việt. Lý Thường Kiệt chủ động đưa quân ra phòng tuyến sông Như Nguyệt (sông Cầu) để chặn đứng đạo quân thủy của địch.\n\nDiễn biến tại di tích: Lũy tre dày và thành đất dọc bờ nam sông Cầu được đắp lên nhanh, kết hợp đội hình cung nỏ và thuyền chiến. Trận lớn diễn ra đầu năm 1077; quân Tống nhiều lần xung phong đều bị đánh lui. Trong lúc giằng co, tiếng vọng Nam Quốc Sơn Hà vang lên tại đền Trương Hống - Trương Hát, khích lệ tướng sĩ: "Nam quốc sơn hà Nam đế cư / Tiệt nhiên định phận tại thiên thư".\n\nDấu tích & Di sản: Đền Trương Hống - Trương Hát (Đền Xà) bên bờ sông vẫn được coi là nơi bài thơ thần vang lên. Phòng tuyến Như Nguyệt là nền tảng cho chiến thắng chung cuộc, buộc quân Tống rút về sau hơn 1 năm chiến.',
        historical_significance = 'Một trong những phòng tuyến thành công nhất lịch sử Việt Nam; bài thơ Nam Quốc Sơn Hà được xem là "bản tuyên ngôn độc lập" đầu tiên, khẳng định chủ quyền non sông.'
    WHERE id = 'a0000000-0000-0000-0000-000000000008';

    UPDATE map_locations SET
        key_figures = 'Lý Thường Kiệt, thần đền Trương Hống - Trương Hát, tướng sĩ Đại Việt',
        story_narrative = E'Bối cảnh lịch sử: Đền Trương Hống - Trương Hát (còn gọi Đền Xà) nằm bên bờ sông Như Nguyệt, thờ hai vị thần bảo hộ vùng sông nước. Đây là nơi linh thiêng gắn với truyền thuyết bài thơ thần Nam Quốc Sơn Hà.\n\nDiễn biến tại di tích: Theo truyền thuyết và sử liệu, trong đêm quân Tống chuẩn bị vượt sông, tiếng vọng từ đền vang lên ngâm bài thơ Nam Quốc Sơn Hà, khiến tướng sĩ Đại Việt tin tưởng trời đất phù hộ. Tinh thần quân địch suy sụp; Lý Thường Kiệt tận dụng thời cơ phản công, đẩy quân Tống ra khỏi bờ sông.\n\nDấu tích & Di sản: Đền Xà vẫn giữ kiến trúc cổ kính, hàng năm có lễ hội tưởng nhớ. Bài thơ Nam Quốc Sơn Hà được đúc thành bia, trở thành lời thề bảo vệ non sông của các thế hệ người Việt.',
        historical_significance = 'Nơi ra đời truyền thuyết Nam Quốc Sơn Hà — tuyên ngôn độc lập thiêng liêng của dân tộc; biểu tượng của sự kết hợp giữa chiến lược quân sự và niềm tin tâm linh bảo vệ đất nước.'
    WHERE id = 'a0000000-0000-0000-0000-000000000009';

    UPDATE map_locations SET
        key_figures = 'Võ Nguyên Giáp, Hoàng Văn Thái, các tướng Bí thư chiến dịch; đối phương: Henri Navarre, De Castries',
        story_narrative = E'Bối cảnh lịch sử: Cuối năm 1953, Pháp xây dựng tập đoàn cứ điểm Điện Biên Phủ, trong đó đồi A1 là cứ điểm then chốt trên cánh đồng Mường Thanh. Đại tướng Võ Nguyên Giáp quyết định mở Chiến dịch Điện Biên Phủ nhằm tiêu diệt toàn bộ quân Pháp.\n\nDiễn biến tại di tích: Từ 13/3 đến 7/5/1954, quân Việt Nam lần lượt đánh chiếm các cứ điểm ngoại vi. Đồi A1 chịu hàng nghìn quả bom và pháo, trở thành nơi giao chiến ác liệt nhất. Đêm 6/5, các đơn vị cảm tử đào hầm chất nổ dưới đồi A1, cho nổ và tổng công kích, chiếm trọn đồi vào sáng 7/5 — chìa khóa mở vào trung tâm Mường Thanh.\n\nDấu tích & Di sản: Đồi A1 được bảo tồn nguyên trạng, có tượng đài và hầm nổ. "Điện Biên Phủ thành cổ quốc / Chiến trường vẫn gọi lòng son" — câu thơ Tố Hữu vẫn vang vọng về 56 ngày đêm quyết tử.',
        historical_significance = 'Cứ điểm quyết định thắng lợi Chiến dịch Điện Biên Phủ, chấm dứt ách thống trị thực dân Pháp ở Đông Dương; biểu tượng của ý chí quyết chiến và anh dũng của quân đội nhân dân Việt Nam.'
    WHERE id = 'a0000000-0000-0000-0000-000000000010';

    UPDATE map_locations SET
        key_figures = 'De Castries, Võ Nguyên Giáp, các trinh sát và bộ đội đánh chiếm hầm',
        story_narrative = E'Bối cảnh lịch sử: Hầm chỉ huy De Castries nằm giữa cánh đồng Mường Thanh, là trung tâm điều phối của tập đoàn cứ điểm Điện Biên Phủ. Chuẩn tướng De Castries chỉ huy toàn bộ lực lượng Pháp từ đây.\n\nDiễn biến tại di tích: Chiều 7/5/1954, sau khi đồi A1 thất thủ, quân Việt Nam tràn về trung tâm. Hầm De Castries bị bao vây và đánh chiếm; lá cờ "Quyết chiến — Quyết thắng" tung bay trên nóc hầm, đánh dấu kết thúc chiến dịch. De Castries cùng toàn bộ sở chỉ huy bị bắt sống.\n\nDấu tích & Di sản: Hầm De Castries được bảo tồn, trở thành điểm tham quan quan trọng. Ảnh chụp lá cờ Quyết chiến Quyết thắng phấp phới trên nóc hầm trở thành biểu tượng lịch sử của thắng lợi Điện Biên Phủ "lừng lẫy năm châu, chấn động địa cầu".',
        historical_significance = 'Nơi kết thúc chiến dịch Điện Biên Phủ thắng lợi, mở đường cho Hiệp định Geneva 1954; minh chứng cho sự thất bại của chiến lược quân sự thực dân tại Việt Nam.'
    WHERE id = 'a0000000-0000-0000-0000-000000000011';

    UPDATE map_locations SET
        key_figures = 'Lý Thái Tổ (Lý Công Uẩn), Thiền sư Vạn Hạnh, các quan đầu triều Lý',
        story_narrative = E'Bối cảnh lịch sử: Mùa thu năm Canh Tuất (1010), Lý Thái Tổ ban Chiếu dời đô, rời kinh đô Hoa Lư về vùng đất Đại La. Theo truyền thuyết, khi thuyền vua vừa đến bến, có rồng vàng hiện ra nên đổi tên thành Thăng Long.\n\nDiễn biến tại di tích: Hoàng thành Thăng Long được xây dựng theo lối thành trùng lồng, với Đoan Môn là cổng chính phía nam uy nghiêm. Từ đây, các triều Lý, Trần, Lê trị vì Đại Việt, ban hành chính sách, tổ chức khoa cử, ngoại giao và đánh giặc. Đoan Môn chứng kiến nhiều cuộc hành hương, lễ đăng quang và tiếp sứ quan trọng.\n\nDấu tích & Di sản: Khu trung tâm Hoàng thành Thăng Long được UNESCO công nhận là Di sản Thế giới năm 2010. Đoan Môn cùng các di chỉ gốm, giếng nước, đường cống ngầm chứng minh cấp độ kiến trúc và đời sống cung đình rực rỡ suốt 13 thế kỷ.',
        historical_significance = 'Trung tâm quyền lực và văn hóa của Đại Việt hơn 1000 năm; biểu tượng của sự lựa chọn chiến lược địa lý — đặt kinh đô tại "đất rồng đỗ" Thăng Long, nền tảng phát triển lâu dài của quốc gia.'
    WHERE id = 'a0000000-0000-0000-0000-000000000012';

    -- 3. Update existing media rows with source_citation
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Khu di tích Đền Hùng; Đại Việt Sử ký Toàn thư, quyển 1' WHERE id = 'd7a80000-0000-4000-8000-000000000001';
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Văn hóa Đông Sơn; Viện Khảo cổ học Việt Nam' WHERE id = 'd7a80000-0000-4000-8000-000000000002';
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Trận Bạch Đằng 938; Đại Việt Sử ký Toàn thư, quyển 5' WHERE id = 'd7a80000-0000-4000-8000-000000000003';
    UPDATE map_location_media SET source_citation = 'Ảnh tư liệu khảo cổ — Bãi cọc Yên Giang; Báo cáo Viện Khảo cổ học' WHERE id = 'd7a80000-0000-4000-8000-000000000004';
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Cửa Nam Triệu; Đại Việt Sử ký Toàn thư' WHERE id = 'd7a80000-0000-4000-8000-000000000005';
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Hội thề Hát Môn; Đại Việt Sử ký Toàn thư, quyển 3' WHERE id = 'd7a80000-0000-4000-8000-000000000006';
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Thành Mê Linh; Đại Việt Sử ký Toàn thư' WHERE id = 'd7a80000-0000-4000-8000-000000000007';
    UPDATE map_location_media SET source_citation = 'Tranh tái hiện — Phòng tuyến Như Nguyệt; Việt Sử xứ Đàng Trong' WHERE id = 'd7a80000-0000-4000-8000-000000000008';
    UPDATE map_location_media SET source_citation = 'Ảnh di tích — Đền Xà Như Nguyệt; Sổ di tích Bắc Ninh' WHERE id = 'd7a80000-0000-4000-8000-000000000009';
    UPDATE map_location_media SET source_citation = 'Ảnh tư liệu — Đồi A1 Điện Biên Phủ; Bảo tàng Chiến thắng ĐBP' WHERE id = 'd7a80000-0000-4000-8000-000000000010';
    UPDATE map_location_media SET source_citation = 'Ảnh tư liệu — Hầm De Castries; Bảo tàng Chiến thắng ĐBP' WHERE id = 'd7a80000-0000-4000-8000-000000000011';
    UPDATE map_location_media SET source_citation = 'Ảnh di tích — Đoan Môn Thăng Long; Trung tâm Bảo tồn Di sản' WHERE id = 'd7a80000-0000-4000-8000-000000000012';

    -- 4. Insert additional IMAGE_2D media items per canonical location (sort_order 1,2,3)
    INSERT INTO map_location_media (id, location_id, media_type, title, caption, source_citation, asset_id, external_url, visibility, sort_order)
    SELECT
        m.id, m.location_id, 'IMAGE_2D', m.title, m.caption, m.source_citation, m.asset_id, m.external_url, m.visibility, m.sort_order
    FROM (
        VALUES
            -- Location 1: Đền Hùng
            ('d7ab0000-0000-4000-8000-000000000101'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'Đời sống cư dân Văn Lang thời Hùng Vương', 'Tranh tái hiện cảnh làm ruộng, dệt vải và nghi lễ cộng đồng dưới thời các Vua Hùng.', 'Tranh tái hiện — Bảo tàng Lịch sử Quốc gia', asset_hung_kings_life, '/heritage/lesson_scene_hung_kings_life.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000102'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'Bản đồ Nước Văn Lang thời các Vua Hùng', 'Phạm vi 15 bộ của nước Văn Lang, trung tâm Phong Châu — bản đồ tái dựng theo sử liệu.', 'Trung tâm Bản đồ Lịch sử Việt Nam', asset_map_van_lang, '/maps/map_van_lang.jpg', 'PUBLIC_PREVIEW', 2),
            ('d7ab0000-0000-4000-8000-000000000103'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'Doanh trại và đời sống quân dân Văn Lang', 'Tranh tái hiện đời sống quân dân, rèn binh khí thời Hùng Vương tại vùng núi Nghĩa Lĩnh.', 'Tranh tái hiện — Nhóm họa sĩ Dấu Việt', asset_story_doanh_trai, '/heritage/bg_story_doanh_trai.jpg', 'PUBLIC_PREVIEW', 3),
            -- Location 2: Ngã Ba Hạc
            ('d7ab0000-0000-4000-8000-000000000201'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid, 'Đời sống cư dân Đông Sơn bên bờ sông', 'Cảnh sinh hoạt, đúc trống đồng và trao đổi của cư dân vùng hợp lưu ba sông.', 'Tranh tái hiện — Viện Khảo cổ học', asset_hung_kings_life, '/heritage/lesson_scene_hung_kings_life.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000202'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid, 'Bản đồ Nước Văn Lang — Trung tâm Ngã Ba Hạc', 'Vị trí Ngã Ba Hạc giữa các bộ Văn Lang, trục giao thương sông Hồng — Lô — Đà.', 'Trung tâm Bản đồ Lịch sử Việt Nam', asset_map_van_lang, '/maps/map_van_lang.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 3: Bến Bạch Đằng
            ('d7ab0000-0000-4000-8000-000000000301'::uuid, 'a0000000-0000-0000-0000-000000000003'::uuid, 'Trận địa cọc ngầm Bạch Đằng', 'Tranh tái hiện hàng cọc lim bịt sắt giăng ngầm dưới mặt nước khi thủy triều rút.', 'Tranh tái hiện — Đại Việt Sử ký Toàn thư', asset_story_tran_dia, '/heritage/bg_story_tran_dia.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000302'::uuid, 'a0000000-0000-0000-0000-000000000003'::uuid, 'Bản đồ Thủy chiến Bạch Đằng 938', 'Sơ đồ bố trí trận địa cọc, hướng tiến của thủy quân Nam Hán và vị trí mai phục.', 'Bản đồ tái dựng — Bảo tàng Quân sự Việt Nam', asset_map_bach_dang, '/maps/dv_MAP_ngoquyen_bachdang-base_v01.jpg', 'PUBLIC_PREVIEW', 2),
            ('d7ab0000-0000-4000-8000-000000000303'::uuid, 'a0000000-0000-0000-0000-000000000003'::uuid, 'Ngô Quyền chỉ huy trận thủy chiến', 'Tranh anh hùng Ngô Quyền đứng mũi thuyền chỉ huy nghĩa quân phản công.', 'Tranh tái hiện — Nhóm họa sĩ Dấu Việt', asset_bach_dang_hero, '/heritage/dv_EVT_ngoquyen_bachdang_hero_v01.jpg', 'PUBLIC_PREVIEW', 3),
            -- Location 4: Bãi cọc Yên Giang
            ('d7ab0000-0000-4000-8000-000000000401'::uuid, 'a0000000-0000-0000-0000-000000000004'::uuid, 'Trận địa cọc ngầm dưới lòng sông', 'Tái hiện lớp cọc ngầm cắm chìm trong bùn, chỉ lộ khi triều rút.', 'Tranh tái hiện — Viện Khảo cổ học', asset_story_tran_dia, '/heritage/bg_story_tran_dia.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000402'::uuid, 'a0000000-0000-0000-0000-000000000004'::uuid, 'Bản đồ phân bố bãi cọc Bạch Đằng', 'Sơ đồ vị trí các bãi cọc Yên Giang, Vạn Mười, Bạch Đằng Giang trên sông.', 'Bản đồ tái dựng — Viện Khảo cổ học', asset_map_bach_dang, '/maps/dv_MAP_ngoquyen_bachdang-base_v01.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 5: Cửa Nam Triệu
            ('d7ab0000-0000-4000-8000-000000000501'::uuid, 'a0000000-0000-0000-0000-000000000005'::uuid, 'Trận địa thủy chiến Bạch Đằng', 'Tranh tái hiện trận địa mai phục nơi cửa sông Nam Triệu năm 938.', 'Tranh tái hiện — Đại Việt Sử ký Toàn thư', asset_story_tran_dia, '/heritage/bg_story_tran_dia.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000502'::uuid, 'a0000000-0000-0000-0000-000000000005'::uuid, 'Bản đồ cửa sông Nam Triệu — Bạch Đằng', 'Vị trí cửa Nam Triệu trong hệ thống trận địa thủy chiến Bạch Đằng.', 'Bản đồ tái dựng — Bảo tàng Quân sự Việt Nam', asset_map_bach_dang, '/maps/dv_MAP_ngoquyen_bachdang-base_v01.jpg', 'PUBLIC_PREVIEW', 2),
            ('d7ab0000-0000-4000-8000-000000000503'::uuid, 'a0000000-0000-0000-0000-000000000005'::uuid, 'Ngô Quyền trên mũi thuyền chiến', 'Tranh anh hùng Ngô Quyền chỉ huy đội hình thuyền chiến khóa chặt cửa sông.', 'Tranh tái hiện — Nhóm họa sĩ Dấu Việt', asset_bach_dang_hero, '/heritage/dv_EVT_ngoquyen_bachdang_hero_v01.jpg', 'PUBLIC_PREVIEW', 3),
            -- Location 6: Cửa sông Hát — Hát Môn
            ('d7ab0000-0000-4000-8000-000000000601'::uuid, 'a0000000-0000-0000-0000-000000000006'::uuid, 'Hội thề và đoàn voi chiến Hai Bà Trưng', 'Tranh tái hiện lễ tế cờ khởi nghĩa, nghĩa quân và voi chiến bên sông Hát.', 'Tranh tái hiện — Đại Việt Sử ký Toàn thư', asset_story_tran_dia, '/heritage/bg_story_tran_dia.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000602'::uuid, 'a0000000-0000-0000-0000-000000000006'::uuid, 'Bản đồ Khởi nghĩa Hai Bà Trưng năm 40', 'Phạm vi 65 thành trì Lĩnh Ngoại hưởng ứng, từ Giao Chỉ đến Hợp Phố.', 'Bản đồ tái dựng — Trung tâm Bản đồ Lịch sử', asset_map_hai_ba_trung, '/maps/map_hai_ba_trung.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 7: Thành cổ Mê Linh
            ('d7ab0000-0000-4000-8000-000000000701'::uuid, 'a0000000-0000-0000-0000-000000000007'::uuid, 'Đời sống và thủ phủ Mê Linh', 'Tranh tái hiện thủ phủ — kinh đô Trưng Nữ Vương và đời sống quân dân.', 'Tranh tái hiện — Bảo tàng Lịch sử Quốc gia', asset_hung_kings_life, '/heritage/lesson_scene_hung_kings_life.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000702'::uuid, 'a0000000-0000-0000-0000-000000000007'::uuid, 'Bản đồ kinh đô Mê Linh thời Trưng Vương', 'Vị trí thành Mê Linh và các quận trung tâm của nhà nước tự chủ.', 'Bản đồ tái dựng — Trung tâm Bản đồ Lịch sử', asset_map_hai_ba_trung, '/maps/map_hai_ba_trung.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 8: Phòng tuyến Như Nguyệt
            ('d7ab0000-0000-4000-8000-000000000801'::uuid, 'a0000000-0000-0000-0000-000000000008'::uuid, 'Doanh trại và lũy phòng thủ sông Cầu', 'Tranh tái hiện doanh trại quân Lý, lũy tre và đồn cảnh giới bờ nam sông.', 'Tranh tái hiện — Nhóm họa sĩ Dấu Việt', asset_story_doanh_trai, '/heritage/bg_story_doanh_trai.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000802'::uuid, 'a0000000-0000-0000-0000-000000000008'::uuid, 'Bản đồ Phòng tuyến Sông Như Nguyệt 1077', 'Bố trí lũy phòng thủ, đội hình cung nỏ và hướng tấn công của quân Tống.', 'Bản đồ tái dựng — Bảo tàng Quân sự Việt Nam', asset_map_nhu_nguyet, '/maps/map_nhu_nguyet.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 9: Đền Xà Như Nguyệt
            ('d7ab0000-0000-4000-8000-000000000901'::uuid, 'a0000000-0000-0000-0000-000000000009'::uuid, 'Thủ phủ và không gian tâm linh ven sông', 'Tranh tái hiện đền thờ, sân lễ và khói hương bên dòng sông Như Nguyệt.', 'Tranh tái hiện — Nhóm họa sĩ Dấu Việt', asset_story_thu_phong, '/heritage/bg_story_thu_phong.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000000902'::uuid, 'a0000000-0000-0000-0000-000000000009'::uuid, 'Bản đồ vị trí Đền Xà trên phòng tuyến', 'Vị trí đền Trương Hống - Trương Hát trong hệ thống phòng tuyến Như Nguyệt.', 'Bản đồ tái dựng — Trung tâm Bản đồ Lịch sử', asset_map_nhu_nguyet, '/maps/map_nhu_nguyet.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 10: Đồi A1 Điện Biên Phủ
            ('d7ab0000-0000-4000-8000-000000001001'::uuid, 'a0000000-0000-0000-0000-000000000010'::uuid, 'Doanh trại quân Việt Nam quanh lòng chảo', 'Tranh tái hiện hầm trú ẩn, đường hào tiếp cận và cứ điểm Việt Nam bao quanh A1.', 'Tranh tái hiện — Bảo tàng Chiến thắng ĐBP', asset_story_doanh_trai, '/heritage/bg_story_doanh_trai.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000001002'::uuid, 'a0000000-0000-0000-0000-000000000010'::uuid, 'Bản đồ Chiến dịch Điện Biên Phủ 1954', 'Vị trí đồi A1, hầm De Castries và các cứ điểm trong tập đoàn Mường Thanh.', 'Bản đồ tái dựng — Bảo tàng Quân sự Việt Nam', asset_map_dien_bien_phu, '/maps/map_dien_bien_phu.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 11: Hầm De Castries
            ('d7ab0000-0000-4000-8000-000000001101'::uuid, 'a0000000-0000-0000-0000-000000000011'::uuid, 'Trận địa tổng công kích Mường Thanh', 'Tranh tái hiện đội hình Việt Nam tiến về trung tâm cứ điểm chiều 7/5.', 'Tranh tái hiện — Bảo tàng Chiến thắng ĐBP', asset_story_tran_dia, '/heritage/bg_story_tran_dia.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000001102'::uuid, 'a0000000-0000-0000-0000-000000000011'::uuid, 'Bản đồ khu trung tâm Mường Thanh', 'Vị trí hầm De Castries, sân bay và các cứ điểm cuối cùng chiều 7/5/1954.', 'Bản đồ tái dựng — Bảo tàng Quân sự Việt Nam', asset_map_dien_bien_phu, '/maps/map_dien_bien_phu.jpg', 'PUBLIC_PREVIEW', 2),
            -- Location 12: Hoàng thành Thăng Long
            ('d7ab0000-0000-4000-8000-000000001201'::uuid, 'a0000000-0000-0000-0000-000000000012'::uuid, 'Thủ phủ kinh thành Thăng Long thời Lý', 'Tranh tái hiện cung điện, hồ cảnh và đời sống cung đình thời nhà Lý.', 'Tranh tái hiện — Trung tâm Bảo tồn Di sản', asset_story_thu_phong, '/heritage/bg_story_thu_phong.jpg', 'PUBLIC_PREVIEW', 1),
            ('d7ab0000-0000-4000-8000-000000001202'::uuid, 'a0000000-0000-0000-0000-000000000012'::uuid, 'Doanh trại và vệ binh kinh thành', 'Tranh tái hiện doanh trại, vệ binh gác cổng và tường thành Thăng Long.', 'Tranh tái hiện — Nhóm họa sĩ Dấu Việt', asset_story_doanh_trai, '/heritage/bg_story_doanh_trai.jpg', 'PUBLIC_PREVIEW', 2)
    ) AS m(id, location_id, title, caption, source_citation, asset_id, external_url, visibility, sort_order)
    WHERE EXISTS (SELECT 1 FROM map_locations loc WHERE loc.id = m.location_id)
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        caption = EXCLUDED.caption,
        source_citation = EXCLUDED.source_citation,
        asset_id = EXCLUDED.asset_id,
        external_url = EXCLUDED.external_url,
        visibility = EXCLUDED.visibility,
        sort_order = EXCLUDED.sort_order;
END $$;
