-- Dấu Việt MVP | V13 | TASK-0023 P2 — căn chỉnh mô tả item_catalog với
-- unlock rule thực tế. COLLECTION_COUNT đếm DISTINCT evidence trong TOÀN
-- BỘ Bộ Sưu Tập của learner (không giới hạn theo một sự kiện), nên mô tả
-- phải nói rõ "bằng chứng trong Bộ Sưu Tập" thay vì ám chỉ chỉ cần bằng
-- chứng của một sự kiện/khảo cổ cụ thể. Không sửa V12 (đã apply): chỉ
-- UPDATE description — dữ liệu inventory/rule không đổi.
UPDATE item_catalog SET description =
    'Mô hình thu nhỏ của trống đồng Đông Sơn — biểu tượng nền văn hóa Đông Sơn (khoảng thế kỷ VII TCN đến thế kỷ I SCN). Mở khóa khi sưu tầm đủ 12 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'MO_HINH_TRONG_DONG_DONG_SON';

UPDATE item_catalog SET description =
    'Phiên bản số tái hiện cọc ngầm trận Bạch Đằng 938 — di chỉ cọc gỗ được nghiên cứu niên đại C-14. Mở khóa khi sưu tầm đủ 5 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'PHIEN_BAN_SO_COC_BACH_DANG';

UPDATE item_catalog SET description =
    'Mô hình thu nhỏ Thành nhà Hồ (Vĩnh Lộc, Thanh Hóa) — di sản thế giới UNESCO công nhận 2011. Mở khóa khi sưu tầm đủ 10 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'MO_HINH_THANH_NHA_HO';

UPDATE item_catalog SET description =
    'Phiên bản số sơ đồ ba vòng thành xoắn ốc Cổ Loa — kinh đô Âu Lạc thế kỷ III TCN. Mở khóa khi sưu tầm đủ 6 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'PHIEN_BAN_SO_CO_LOA';

UPDATE item_catalog SET description =
    'Huy hiệu kỷ niệm khởi nghĩa Hai Bà Trưng năm 40 — tinh thần độc lập đầu tiên sau thời kỳ Bắc thuộc. Mở khóa khi sưu tầm đủ 3 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'HUY_HIEU_HAI_BA_TRUNG';

UPDATE item_catalog SET description =
    'Mô hình thu nhỏ tháp Chăm tại thánh địa Mỹ Sơn — di sản thế giới UNESCO 1999. Mở khóa khi sưu tầm đủ 15 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'MO_HINH_CHUA_MY_SON';

UPDATE item_catalog SET description =
    'Phiên bản số một góc phố cổ Hội An — thương cảng quốc tế thế kỷ XVI-XVII, di sản UNESCO 1999. Mở khóa khi sưu tầm đủ 8 bằng chứng bất kỳ trong Bộ Sưu Tập.'
WHERE code = 'PHIEN_BAN_SO_PHO_HOI_AN';

-- HUY_HIEU_DIEN_BIEN_PHU đã mô tả đúng rule LESSON_COUNT ("hoàn thành đủ
-- số bài học") — không đổi.
