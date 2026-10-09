---
name: Dau Viet v2.0 Illustrated Heritage Design System
colors:
  surface: '#FFFBF4'
  surface-dim: '#F5ECE0'
  surface-bright: '#FFFFFF'
  surface-container-lowest: '#FFFFFF'
  surface-container-low: '#FBF5EC'
  surface-container: '#FFF1D5'
  surface-container-high: '#F3E5CE'
  surface-container-highest: '#E7D5BA'
  on-surface: '#30251F'
  on-surface-variant: '#685F56'
  inverse-surface: '#2A1F1A'
  inverse-on-surface: '#FDF7F0'
  outline: '#8C6747'
  outline-variant: '#D4C1A5'
  primary: '#A51F18'
  on-primary: '#FFFFFF'
  primary-container: '#751B19'
  on-primary-container: '#FFF0F0'
  secondary: '#E7B451'
  on-secondary: '#30251F'
  secondary-container: '#F6CD7B'
  on-secondary-container: '#3B2404'
  tertiary: '#64824C'
  on-tertiary: '#FFFFFF'
  tertiary-container: '#388EB4'
  on-tertiary-container: '#EAF4F8'
  error: '#B3261E'
  on-error: '#FFFFFF'
  background: '#FFFBF4'
  on-background: '#30251F'
  canvas: '#FFFBF4'
  parchment: '#FFF1D5'
  cream: '#FFFBF4'
  brand-red-primary: '#A51F18'
  brand-red-dark: '#751B19'
  heritage-gold: '#E7B451'
  ink-primary: '#30251F'
  ink-secondary: '#685F56'
  wood-brown: '#613B28'
  sea-blue: '#388EB4'
  nature-green: '#64824C'
  state-error: '#B3261E'
typography:
  headline-lg:
    fontFamily: Noto Serif
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Noto Serif
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  headline-sm:
    fontFamily: Noto Serif
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 24px
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Be Vietnam Pro
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.02em
rounded:
  sm: 0.5rem
  DEFAULT: 0.75rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 16px
  margin: 16px
  space-xs: 4px
  space-sm: 8px
  space-md: 16px
  space-lg: 24px
  space-xl: 32px
---

# DẤU VIỆT — HỆ THỐNG THIẾT KẾ MASTER v2.0 (ILLUSTRATED ADVENTURE)

> **Cập nhật theo:** [ART_DIRECTION.md](file:///c:/Users/Admin/Desktop/4user/DauViet/design/ART_DIRECTION.md), [UI_COMPONENT_SPEC.md](file:///c:/Users/Admin/Desktop/4user/DauViet/design/UI_COMPONENT_SPEC.md), và [ASSET_GENERATION_GUIDELINES.md](file:///c:/Users/Admin/Desktop/4user/DauViet/design/ASSET_GENERATION_GUIDELINES.md).  
> **Nguyên tắc chuyển đổi v2.0:** Thay đổi triệt để từ Pixel Art sang **Stylized 2D Historical Illustrated Adventure** (Minh họa 2D vẽ tay, chiều sâu đa tầng, isometric 2.5D cho đảo, typography Be Vietnam Pro & Noto Serif).

---

## 1. Bản sắc thị giác v2.0 (Art Direction v2.0)

- **Phong cách:** Stylized 2D Hand-painted Vietnamese Historical Illustration.
  - Tinh thần phiêu lưu, điều tra lịch sử hấp dẫn nhưng chuẩn mực, tôn trọng sử liệu.
  - Chiều sâu tạo bởi 3 lớp: Tiền cảnh (Foreground) $\rightarrow$ Trung cảnh (Midground) $\rightarrow$ Hậu cảnh (Background).
  - Đảo cá nhân & công trình: Isometric 2.5D minh họa vẽ tay với trục chiếu và bóng đổ nhất quán.
- **Quy tắc bất biến:**
  - **Không dùng pixel-art làm phong cách chủ đạo.**
  - **Tuyệt đối không bake text, điểm số, giá tiền, nhãn hoặc nút vào trong ảnh.** Text và UI luôn là widget/DOM tương tác native.
  - **Tách rời lớp bản đồ và điểm tương tác:** Map nền chỉ chứa cảnh quan địa hình; marker, lộ trình, trạng thái khóa là data-driven overlay.
  - Mọi asset lịch sử phải gắn metadata kiểm duyệt (`historicalSources`, `historicalConfidence`, `reviewer`, `license`).

---

## 2. Bảng Tokens chuẩn hóa v2.0

| Token | HEX | Vai trò | Tương thích WCAG |
|---|---|---|---|
| `brand.red.700` | `#A51F18` | CTA chính, tiêu đề thời kỳ | Tương phản tốt trên nền kem/trắng |
| `brand.red.900` | `#751B19` | Nút khi nhấn (pressed), tiêu đề sâu | Tương phản cao |
| `heritage.gold.500` | `#E7B451` | Huy hiệu, phần thưởng, chi tiết vinh danh | Dùng cho viền và điểm nhấn |
| `surface.parchment` | `#FFF1D5` | Nền thẻ bài nội dung, khung sa bàn chọn lọc | Tông giấy dó êm mắt |
| `surface.cream` | `#FFFBF4` | Nền trang học tập, màn hình chính | Nền sáng, sạch, dễ đọc |
| `ink.primary` | `#30251F` | Văn bản nội dung chính, câu hỏi | Đọc rõ trên nền sáng |
| `ink.secondary` | `#685F56` | Văn bản phụ, chú thích trích dẫn | Độ tương phản đạt chuẩn |
| `wood.brown` | `#613B28` | Viền mộc tinh tế (dùng có kiểm soát) | Đường nét trang trí |
| `sea.blue` | `#388EB4` | Thủy chiến Bạch Đằng, hải đồ sa bàn | Phân biệt địa hình sông nước |
| `nature.green` | `#64824C` | Trạng thái đúng/xác thực (kèm icon) | Thiên nhiên, hoàn thành |
| `state.error` | `#B3261E` | Lỗi validation, thiếu chứng cứ | Báo hiệu lỗi |

---

## 3. Typography Quy chuẩn

- **Tiêu đề & Mốc lịch sử (Headings / Eras):** `Noto Serif` (có đầy đủ dấu tiếng Việt, trang trọng, hào hùng).
- **Văn bản nội dung & Tương tác (Body / UI / Admin):** `Be Vietnam Pro` (phông chữ chuẩn thiết kế hiện đại Việt Nam, tối ưu đọc trên thiết bị di động, cỡ body mobile $\ge 16\text{sp}$).

---

## 4. Danh mục Component Chuẩn (`UI_COMPONENT_SPEC.md`)

### Flutter Mobile (`M-C01` đến `M-C28`)
- Bố cục & Vỏ: `M-C01 AppScaffold`, `M-C02 BrandTopBar`, `M-C03 MainBottomNav`, `M-C28 StatusView`.
- Thao tác: `M-C04 PrimaryActionButton`, `M-C05 SecondaryActionButton`.
- Thẻ bài & Khám phá: `M-C06 EventHeroCard`, `M-C07 EraTimelineItem`, `M-C08 HistoricalMapCanvas`, `M-C09 MapEventMarker`, `M-C10 FourTraceCard`, `M-C11 EvidenceCard`.
- Learning Engine: `M-C12 ActivityShell`, `M-C13 ChoiceOption`, `M-C14 MatchingBoard`, `M-C15 DragOrderList`, `M-C16 EvidenceSelector`, `M-C17 ReasoningConnector`, `M-C18 HypothesisChoice`, `M-C19 VerificationFeedback`, `M-C20 CERComposer`, `M-C21 ReflectionPrompt`.
- Kết quả & Vinh danh: `M-C22 StoryScene`, `M-C23 RewardSummary`.
- Meta-game: `M-C24 IslandScene`, `M-C25 InventoryItemCard`, `M-C26 ShopItemCard`, `M-C27 EnergyIndicator`.

### Next.js Admin (`A-C01` đến `A-C20`)
- Khung CMS: `A-C01 AdminShell`, `A-C02 PageHeader`, `A-C03 DataTable`, `A-C04 StatusChip`, `A-C17 UnsavedChangesGuard`.
- Soạn thảo: `A-C05 EventEditorForm`, `A-C06 LessonMetadataForm`, `A-C07 TemplatePicker`, `A-C08 StageOutline`, `A-C09 ActivityTypePicker`, `A-C10 ActivityConfigEditor`, `A-C11 EvidenceSourceEditor`, `A-C12 AssetLibraryPicker`, `A-C13 RuleEditor`.
- Xuất bản & Thẩm định: `A-C14 PublishChecklist`, `A-C15 LearnerPreviewFrame`, `A-C16 VersionHistory`, `A-C18 UploadDropzone`, `A-C20 InlineErrorSummary`.
