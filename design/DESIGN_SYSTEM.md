# DẤU VIỆT — DESIGN SYSTEM / UI FOUNDATION

**Status:** Visual design proposal, derived from 8 concept boards. Chưa có source file Figma hay style token gốc.

## 1. Art direction

**Từ concept [UI-1…8]:** phong cách game giáo dục lịch sử Việt Nam, tranh 2D/pixel-inspired, bản đồ isometric/illustrated, màu đỏ cờ, vàng đồng, giấy ngà, gỗ và biển xanh. Các viền trang trí đậm, khung sắc phong/cuộn giấy. Không dùng các hình concept như ảnh màn hình cuối cùng (chúng chứa cả mockup điện thoại, chữ, nền chung).

**[Proposal]** UI gameplay nổi bật nhưng text dài phải dễ đọc; chia 3 cấp hình ảnh: background không tương tác, content illustration có mô tả nguồn, interactive layer có hit targets riêng.

## 2. Tokens (GIÁ TRỊ ĐỀ XUẤT — phải xác nhận)

| Token | HEX đề xuất | Vai trò |
|---|---|---|
| `brand.red.700` | `#941E18` | CTA chính, banner tiêu đề |
| `brand.red.900` | `#5B1716` | chữ/viền nhấn đỏ |
| `brand.gold.500` | `#C9943B` | vàng đồng, tiến độ, viền |
| `paper.50` | `#FFF6E5` | card nền sáng |
| `paper.100` | `#F3E1BC` | khung giấy |
| `ink.900` | `#34251C` | chữ chính |
| `ink.600` | `#725F4B` | chữ phụ |
| `sea.500` | `#388EA8` | biển và map |
| `success.600` | `#2E7D42` | đúng/hoàn thành |
| `warning.600` | `#A36612` | thông báo cảnh báo |
| `error.600` | `#BA3028` | lỗi |
| `neutral.500` | `#80786D` | disabled/locked |

**Flutter:** `ThemeData` + `ColorScheme` + theme extensions cho `ParchmentTheme`; **Admin:** CSS variables/tokens. Không hardcode token ở từng page. Kiểm tra contrast WCAG; nền hình nhiều chi tiết phải dùng panel mờ/đục phía sau chữ.

## 3. Typography (proposal)

- Display: serif/heading có gợi ý truyền thống; **chọn font có đầy đủ dấu tiếng Việt và license hợp lệ**.
- Body: sans-serif rõ ràng; font 14–16sp mobile, tăng theo accessibility scaling.
- Headings: 20–28sp tùy hierarchy; body tối thiểu 14sp cho nội dung chính; UI caption 12sp chỉ khi bảo đảm khả năng đọc.
- Không rasterize text vào art nếu là nội dung động/dịch/localized.

## 4. Layout, spacing và devices

| Mục | Quy tắc đề xuất |
|---|---|
| Spacing | 4pt base: 4 / 8 / 12 / 16 / 24 / 32 |
| Mobile safe area | Bắt buộc hỗ trợ status bar, notch, bottom nav, bàn phím |
| Mobile target | Thiết kế logical width 360–430dp, kiểm tra 320dp, tablet |
| Tap target | Phấn đấu ≥44×44 logical px; drag có tap alternative |
| Sticky CTA | Đặt trên safe-area/footer, không che nội dung |
| Card | Border/ornament là layer trang trí; nội dung auto-layout riêng |
| Desktop Admin | Sidebar + main editor + preview; responsive 1280+ và 1024 |

## 5. Component library

| ID | Component | Variants / states | Dùng ở |
|---|---|---|---|
| CMP-001 | AppTopBar | regular, with energy, loading | Mobile |
| CMP-002 | BottomNav | active/inactive, badge | Mobile |
| CMP-003 | ScrollTitle | small/medium, truncated | Mobile/Admin preview |
| CMP-004 | ParchmentCard | image/summary/action | All |
| CMP-005 | PrimaryCTA | default/disabled/loading/success | All |
| CMP-006 | JourneyProgress | step/completed/locked/current | Mobile |
| CMP-007 | HistoricEventCard | available/locked/completed | Explore |
| CMP-008 | EvidenceCard | collected/relevant/selected/locked | Lesson |
| CMP-009 | InteractiveOption | default/selected/correct/incorrect/disabled | Quiz |
| CMP-010 | DraggableTimelineItem | idle/dragging/placed/error | Order |
| CMP-011 | Badge/RewardTile | locked/unlocked/claimed | Reward |
| CMP-012 | InventoryItemCard | owned/equipped/usable | Economy |
| CMP-013 | AssetPicker | search/upload/error/loading | Admin |
| CMP-014 | StageNavigator | required/optional/valid/invalid | Admin |
| CMP-015 | ValidationPanel | error/warning/success | Admin |
| CMP-016 | LearnerPreview | mobile width, test fixtures | Admin |

## 6. States bắt buộc

**Tất cả màn dữ liệu:** initial, skeleton/loading, success, empty, recoverable error/retry, offline/timeout, unauthorized (nếu cần).  
**Tất cả activity:** not_started, in_progress, submitting, feedback, completed; input invalid; retry; resume saved response.  
**Locked elements:** nêu nguyên nhân khóa và điều kiện mở khóa, không chỉ xám màu.  
**Admin editor:** pristine, dirty/unsaved, saving, saved, validation_failed, publish_pending, published.

## 7. Motion/sound (proposal)

- Transition stage 180–300ms; celebratory reward có hiệu ứng optional; respects reduce-motion.
- Âm thanh UI/ambient mặc định **có thể tắt**; asset audio chưa có nguồn trong mockup.
- Animation đảo nên layer riêng, không ảnh hưởng trạng thái nghiệp vụ.

## 8. Accessibility/localization

- Alt text cho ảnh nội dung; mô tả văn bản cho map hotspot và quân cờ; screen-reader labels; keyboard focus trên Admin.
- Drag/drop phải có phương án nhấn-chọn/chuyển vị trí.
- Trạng thái đúng/sai dùng icon + chữ, không chỉ màu sắc.
- Ngôn ngữ mặc định tiếng Việt; chuỗi UI ở localization keys; không nhúng chữ động vào PNG.

## 9. Breakpoints/export (proposal)

- Art tĩnh: SVG nếu vector; WebP/PNG (transparency) nếu raster; tối ưu theo mật độ màn hình và cache.
- Bản đồ có tương tác: background riêng + marker overlay/coordinate metadata; không flatten marker, label, path vào ảnh.
- Admin dùng responsive layout, ưu tiên canvas preview mô phỏng mobile đúng kích thước tương đối.
