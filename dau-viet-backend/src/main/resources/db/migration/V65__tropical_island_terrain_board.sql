-- Dấu Việt | V65 | Thiết kế lại địa hình Đảo Di Sản thành đảo nhiệt đới giống ảnh mẫu
-- (thảm cỏ trung tâm, vành cát bờ biển Nam/Đông/Tây, vách đá & đồi cỏ cao phía Bắc,
--  hồ + thác sườn Tây Bắc, cầu tàu gỗ + thuyền ở bờ Tây Nam & Đông Nam,
--  cọc đá phụ trên vành nước ngoài cùng).
-- Phạm vi:
--   1. Ghi đè terrain_type / visual_key / elevation / buildable của island_tiles
--      thuộc layout version 4 (10x10) thành bản đồ đảo nhiệt đới.
--   2. Các ô diễn vật ảnh mẫu (hồ, thác, cầu tàu, thuyền, đá phụ, tảng đá) đặt
--      buildable = FALSE — là cảnh quan cố định của đảo, không host slot.
--      Gỡ liên kết tile_id khỏi island_slots tương ứng để slot đó biến mất khỏi
--      danh sách ô đặt (người học không đặt vật phẩm chồng lên cảnh).
--   3. Mọi ô còn lại (cỏ/cát/đường/quảng trường) đều buildable → người học đặt
--      vật phẩm vào BẤT KỲ ô đất nào đã mở khóa, đúng yêu cầu "chia đảo thành
--      nhiều ô và đặt vào ô nào cũng được".
--   4. Giữ nguyên island_tier_policies (36/64/100 ô) & cơ chế nâng cấp Level/EXP.
--
-- Quy ước visual_key:
--   'waterfall' — vách đá + thác đổ xuống (không buildable)
--   'pool'      — mặt hồ nước ngọc nhận thác (không buildable)
--   'dock'      — cầu tàu gỗ thò ra nước (không buildable)
--   'boat'      — thuyền gỗ neo cạnh cầu tàu (không buildable)
--   'islet'     — cọc đá/hòn phụ rải quanh vành nước (không buildable)
--   'rock'      — tảng đá rêu phong trên đảo (không buildable)
--   'palm'      — cụm cọ/dừa nhiệt đới (không buildable — cảnh quan cố định)
--   'flowers'   — thảm hoa dại ven đường (buildable — chỉ là lớp nền nhỏ)
--   null        — ô cỏ/cát/đường bình thường (buildable)

DO $$
DECLARE
    v4_id     UUID := '22200000-2222-4000-8000-000000000004';
    r         INT;
    c         INT;
    tier_req  INT;
    reg_code  VARCHAR(48);
    terrain   VARCHAR(24);
    visual    VARCHAR(64);
    elev      INT;
    v_buildable BOOLEAN;
BEGIN
    FOR r IN 0..9 LOOP
        FOR c IN 0..9 LOOP
            -- Tier & region giữ nguyên logic đồng tâm của V61
            IF (r BETWEEN 2 AND 7) AND (c BETWEEN 2 AND 7) THEN
                tier_req := 1;
                reg_code := 'TIER_1';
            ELSIF (r BETWEEN 1 AND 8) AND (c BETWEEN 1 AND 8) THEN
                tier_req := 2;
                reg_code := 'TIER_2';
            ELSE
                tier_req := 3;
                reg_code := 'TIER_3';
            END IF;

            -- Mặc định: thảm cỏ phẳng, đặt vật phẩm được
            terrain   := 'GRASS';
            visual    := NULL;
            elev      := 0;
            v_buildable := TRUE;

            -- === VÀNH CÁT BỜ BIỂN (hàng ngoài cùng Nam + hai mép Đông/Tây) ===
            IF r = 9 OR c = 9 OR c = 0 OR (r = 8 AND c BETWEEN 2 AND 8) THEN
                terrain := 'SAND';
            END IF;

            -- === VÁCH ĐÁ & ĐỒI CỎ PHÍA BẮC (r=0 vành đá, r=1 đồi cỏ cao) ===
            IF r = 0 THEN
                terrain   := 'STONE';
                visual    := 'rock';
                elev      := 1;
                v_buildable := FALSE;
            ELSIF r = 1 AND c BETWEEN 1 AND 8 THEN
                terrain := 'GRASS';
                elev    := 1;
            END IF;

            -- Cọ nhiệt đới rải trên đồi cỏ Bắc & hai góc Tây/Đông bắc — cảnh quan cố định
            IF (r = 1 AND c IN (2, 5, 7)) OR (r = 2 AND c = 8) THEN
                terrain   := 'GRASS';
                visual    := 'palm';
                elev      := 1;
                v_buildable := FALSE;
            END IF;

            -- === THÁC + HỒ Ở SƯỜN TÂY BẮC (như ảnh small/big island) ===
            -- Khối thác 2 ô (1,1)-(2,1) đổ vào hồ (3,1)
            IF (r = 1 AND c = 1) OR (r = 2 AND c = 1) THEN
                terrain   := 'STONE';
                visual    := 'waterfall';
                elev      := 1;
                v_buildable := FALSE;
            END IF;
            IF r = 3 AND c = 1 THEN
                terrain   := 'WATER';
                visual    := 'pool';
                v_buildable := FALSE;
            END IF;

            -- === CẦU TÀU GỖ + THUYỀN Ở BỜ TÂY NAM (như ảnh) ===
            -- Cầu tàu thò từ bờ cát (8,1) ra nước; thuyền neo ở (9,1)
            IF r = 8 AND c = 1 THEN
                terrain   := 'SAND';
                visual    := 'dock';
                v_buildable := FALSE;
            END IF;
            IF r = 9 AND c = 1 THEN
                terrain   := 'WATER';
                visual    := 'boat';
                v_buildable := FALSE;
            END IF;
            -- Cầu tàu + thuyền thứ hai ở mép Đông Nam (8,8)-(9,7) như ảnh medium island
            IF r = 8 AND c = 8 THEN
                terrain   := 'SAND';
                visual    := 'dock';
                v_buildable := FALSE;
            END IF;
            IF r = 9 AND c = 7 THEN
                terrain   := 'WATER';
                visual    := 'boat';
                v_buildable := FALSE;
            END IF;

            -- === ĐÁ PHỤ / HÒN NHỎ trên vành nước ngoài cùng (sea-stacks trong ảnh) ===
            -- Vành c=0/r=9/c=9 vốn đã là cát/nước; biến một số ô thành đá phụ
            IF (c = 0 AND r IN (2, 5, 7)) OR (r = 9 AND c IN (3, 6)) OR (c = 9 AND r IN (3, 6)) THEN
                terrain   := 'WATER';
                visual    := 'islet';
                v_buildable := FALSE;
            END IF;

            -- === ĐƯỜNG GẠCH & QUẢNG TRƯỜNG TRUNG TÂM (giữ như V61) ===
            IF (r BETWEEN 3 AND 4) AND (c BETWEEN 3 AND 4) THEN
                terrain := 'DIRT';
                elev    := 1;
            ELSIF (r = 5 AND c BETWEEN 2 AND 7) OR (c = 5 AND r BETWEEN 2 AND 7) THEN
                terrain := 'PATH';
            END IF;

            -- === THẢM HOA DẠI ven đường trong vùng TIER_1 (nền nhỏ, vẫn đặt được) ===
            IF terrain = 'GRASS' AND tier_req = 1
               AND ((r = 3 AND c IN (2, 6)) OR (r = 6 AND c = 6) OR (r = 4 AND c = 7)) THEN
                visual := 'flowers';
            END IF;

            UPDATE island_tiles
            SET terrain_type = terrain,
                visual_key   = visual,
                elevation    = elev,
                buildable    = v_buildable
            WHERE layout_version_id = v4_id
              AND row_index = r
              AND col_index = c;
        END LOOP;
    END LOOP;

    -- Gỡ liên kết slot khỏi các ô cảnh quan cố định (thác/hồ/cầu tàu/thuyền/đá phụ/đá/cọ)
    -- để chúng không xuất hiện như ô đặt vật phẩm — cảnh quan do renderer vẽ.
    UPDATE island_slots s
    SET tile_id = NULL
    FROM island_tiles t
    WHERE s.tile_id = t.id
      AND t.layout_version_id = v4_id
      AND t.buildable = FALSE;
END $$;
