# DẤU VIỆT — ART DIRECTION v2.0

**Trạng thái:** Proposed / Chờ duyệt Art Lead & History Reviewer  
**Phạm vi:** Flutter Mobile, Next.js Admin, bài học lịch sử, bản đồ, phần thưởng, đảo cá nhân  
**Nguồn định hướng:** 8 concept boards Hình 1–8, BA/MVP Learning Framework và quyết định thay đổi phong cách từ pixel art sang minh họa 2D.  
**Lưu ý:** Mockup là ý tưởng, không phải file Figma hay bộ asset gốc. Token và kích thước bên dưới là **đề xuất**, cần xác nhận qua prototype và kiểm tra trên thiết bị.

## 1. Creative vision

**Tên:** Vietnamese Historical Illustrated Adventure (Vietnamese Heritage Adventure).  
**Tinh thần:** Khám phá, điều tra và suy luận lịch sử qua tư liệu; hấp dẫn như game phiêu lưu nhưng tin cậy như sản phẩm giáo dục.  
**Nguyên tắc:** (1) Tôn trọng bối cảnh Việt Nam theo thời kỳ; (2) trải nghiệm học dễ đọc, dễ thao tác; (3) minh họa hỗ trợ kiến thức, không thay thế chứng cứ; (4) gamification không lấn át lesson.

### 1.1 Thay đổi từ v1.0

| Thành phần | Trước: Pixel Adventure | Sau: Illustrated Adventure |
|---|---|---|
| Environment | pixel grid nhìn thấy rõ | hand-painted 2D, nét mềm, chiều sâu bằng lớp foreground/midground/background |
| Character | sprite pixel | stylized 2D, tỷ lệ hợp lý, diễn cảm nhưng không caricature quá mức |
| Map | pixel map | bản đồ minh họa lịch sử, marker/vector tách lớp |
| Island | isometric pixel tiles | illustrated isometric 2.5D; vị trí đặt đồ quản lý riêng |
| Icon/UI | pixel-inspired icons và ornate frame | vector sắc nét, hiện đại; hoa văn truyền thống làm điểm nhấn |
| Typography | retro decorative | Be Vietnam Pro cho nội dung; Noto Serif cho tiêu đề |
| Admin | có thể vay mượn game skin | modern CMS, chỉ nhận diện thương hiệu tinh tế |

**Không sử dụng pixel-art làm phong cách chủ đạo.** Chỉ giữ một ít hiệu ứng retro nếu có lý do nội dung cụ thể và được duyệt riêng.

## 2. Ngôn ngữ hình ảnh

### 2.1 Mobile — Illustrated Learning Adventure
- Ảnh chủ đạo ở màn thời kỳ, event, story, historical map; UI dữ liệu là lớp overlay độc lập.
- Có nhịp thị giác: 1 hero illustration + khối kiến thức rõ ràng + 1 CTA chính. Không quá 1–2 chi tiết trang trí mạnh trong cùng viewport.
- Trang học tương tác (quiz, evidence, CER) dùng nền sáng, sạch và độ tương phản tốt; hạn chế texture phía sau chữ.
- Trạng thái Locked/Available/Completed phân biệt bằng icon + text + màu, không chỉ thay đổi màu.

### 2.2 Admin — Modern Historical CMS
- Sidebar, breadcrumbs, tables, inspector panel, preview của learner dùng design system hiện đại.
- Đỏ son là brand accent, không phải màu nền cho mọi card/form.
- Drag-and-drop phải có phương án điều khiển bàn phím / nút lên-xuống.
- Preview dùng cùng schema và renderer behavior với mobile gần nhất có thể; không dùng ảnh mockup tĩnh để giả lập.

## 3. Đề xuất visual tokens

| Token | HEX | Vai trò |
|---|---|---|
| `brand.red.700` | `#A51F18` | CTA, tiêu đề nhấn |
| `brand.red.900` | `#751B19` | CTA pressed, title sâu |
| `heritage.gold.500` | `#E7B451` | Reward và chi tiết quý |
| `surface.parchment` | `#FFF1D5` | Background/card nội dung chọn lọc |
| `surface.cream` | `#FFFBF4` | Trang học / màn hình chính |
| `ink.primary` | `#30251F` | Nội dung văn bản |
| `ink.secondary` | `#685F56` | Supporting text |
| `wood.brown` | `#613B28` | Viền trang trí ít dùng |
| `sea.blue` | `#388EB4` | Minh họa sông biển/map |
| `nature.green` | `#64824C` | Thiên nhiên, trạng thái thành công có icon bổ trợ |
| `state.error` | `#B3261E` | Lỗi validation |

Chốt token sau khi đo contrast thực tế. Nút vàng phải chọn màu chữ đủ tương phản; không dùng vàng nhạt cho chữ body.

### 3.1 Typography
- **Be Vietnam Pro:** body, button, input, label, đáp án, admin tables; đề xuất body mobile ≥ 16sp cho đoạn dài.
- **Noto Serif:** title/event era, quote lịch sử ngắn. Hạn chế font serif đậm cho paragraph dài.
- Full Vietnamese glyph + dấu kết hợp phải được kiểm tra trước release.

### 3.2 Layout/UI
- Hệ spacing 4/8pt; góc bo component gợi ý 10–16dp tùy cấp bậc.
- Target chạm tối thiểu 44×44 logical px; ưu tiên 48×48dp cho CTA.
- Các tranh illustration/texture không chứa câu hỏi, đáp án, điểm EXP, giá tiền, nút hoặc vị trí marker baked-in.
- Motion UI 150–300ms cho feedback; transition scene có thể dài hơn nhưng cho phép skip/reduced motion.

## 4. Art direction theo nhóm

### 4.1 Historical character
- Character sheet: front / 3⁄4 / biểu cảm / hành động chủ đạo; silhouette rõ, màu trang phục nhận diện nhưng tránh biểu tượng sai thời kỳ.
- Không mặc định trang phục, giáp, vũ khí 'cổ trang Á Đông' chung chung; có concept note nguồn kiểm chứng.
- Không biến hình AI thành 'ảnh tư liệu lịch sử'. Minh họa cần nhãn rõ khi phù hợp.

### 4.2 Historical map
- Map nền chứa địa hình/cảnh quan; marker, đường nối, trạng thái khóa và labels là data-driven overlay.
- Có cơ chế pan/zoom phù hợp. Địa danh và sự kiện phải đúng ngữ cảnh thời kỳ; ranh giới/tuyến quân là minh họa khi độ chính xác không chắc chắn.
- Mỗi điểm tương tác mang `id`, `position`, `state`, `label`, `targetRoute`.

### 4.3 Four Dấu Vết
- Bối cảnh, Nhân vật, Diễn biến, Ý nghĩa là **4 nhóm nội dung trong event** (theo mockup), không cứng hóa toàn bộ lesson stage.
- Card cùng aspect ratio, rõ title, action và status; ảnh khác nhau theo chủ đề.
- Nếu xuất hiện Evidence/Reasoning/CER thì có icon/treatment phân biệt chức năng học.

### 4.4 Islands & rewards
- Isometric 2.5D với trục và bóng nhất quán; vật phẩm xuất PNG/WebP nền trong suốt, anchor/pivot chuẩn; không vẽ toàn đảo thành một ảnh duy nhất nếu cần xây dựng.
- Kích thước đảo và unlock là trạng thái từ backend, không suy từ artwork.
- Currency/energy có thể nằm sau MVP. Không thiết kế luồng trả phí như điểm hoàn thành bài học bắt buộc.

## 5. Mức sử dụng họa tiết truyền thống

- **High:** event title banner, special achievement, milestone/unlock.
- **Medium:** card khám phá, panel story, bộ sưu tập vật phẩm.
- **Low/None:** trắc nghiệm, form, evidence comparison, kết luận CER, accessibility surfaces, admin data table.
- Tránh gradient vàng bóng/viền kép dày ở mọi thành phần. Hoa văn phải hỗ trợ thứ bậc thị giác.

## 6. Lịch sử & đạo đức nội dung

1. Mỗi asset có `sourceNotes`, `era`, `reviewStatus`, `reviewer`, `license`.
2. Phân biệt **sự kiện xác thực**, **suy luận có cơ sở** và **tái dựng mang tính minh họa** trong metadata/caption.
3. Có review lịch sử cho trang phục, công trình, địa danh, quân kỳ, tàu thuyền, bản đồ và bối cảnh.
4. Không dùng minh họa AI giả dạng tài liệu gốc hoặc đưa ra biểu tượng chưa xác minh.
5. Sử dụng nguồn asset có quyền khai thác thương mại rõ ràng.

## 7. Acceptance checklist cho Art Lead

- [ ] Style không còn phụ thuộc pixel art.
- [ ] Character/environment/island có 1–2 style sheets thống nhất.
- [ ] UI học tập đọc rõ trên màn nhỏ, hỗ trợ dynamic text.
- [ ] Ảnh nền và UI tương tác đã tách lớp.
- [ ] Bạch Đằng 938 được kiểm tra sử liệu trước publish.
- [ ] Admin giữ được tốc độ thao tác thay vì lạm dụng skin game.
- [ ] Ảnh có alt/caption và quyền sử dụng.
- [ ] Palette/motion/typography được duyệt bằng prototype thật.

## 8. Tài liệu liên quan

`UI_COMPONENT_SPEC.md`, `ASSET_GENERATION_GUIDELINES.md`, `ASSET_CATALOG.md`, `DESIGN_SYSTEM.md`, `MOBILE_SCREEN_DESIGN.md`, `ADMIN_SCREEN_DESIGN.md`.
