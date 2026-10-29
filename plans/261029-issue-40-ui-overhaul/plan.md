# Plan — Issue #40: Đại tu & Nâng cấp toàn diện UI/UX Dấu Việt

> **Nguồn chân lý:** [`issue #40`](https://github.com/longv0208/Dau_Viet/issues/40) · Landing Page tham chiếu: https://dau-viet-landing.vercel.app/  
> **Risk:** high (chạm ~50 file UI trên mobile + admin, không đụng API/schema/auth/version/reward).  
> **Nhánh:** `feat/issue-40-ui-ux-overhaul` · **Task:** `TASK-0031`

## 1. Mục tiêu & AC

| AC | Nội dung |
|---|---|
| AC-1 | **Design System đồng nhất:** 100% màn mobile dùng chung palette giấy-dó / mực-nho / đỏ-chu-sa / vàng-ngự-xưởng / xanh-cổ-vật, font `Noto Serif` + `Be Vietnam Pro`, hệ thẻ/nút có chiều sâu đồng bộ với Landing Page. |
| AC-2 | **Game-hóa Lesson Player:** Các renderer `READ`, `VIEW_IMAGE`, `EVIDENCE_SELECT`, `HYPOTHESIS_CHOICE`, `VERIFICATION`, `DRAG_ORDER`, `CER_CHOICE` được thiết kế lại theo phong cách *Sổ tay Thám tử Lịch sử & Sa bàn Chiến thuật*, loại bỏ cảm giác form trắc nghiệm. |
| AC-3 | **Minh họa & Linh vật:** Bổ sung minh họa ngữ cảnh + linh vật (Bé Sử / Rùa Kabi) ở các điểm chạm chính: chọn thời kỳ, dẫn dắt bài học, phản hồi đúng/sai, mở khóa bảo vật. |
| AC-4 | **Responsive & Regression:** Sắc nét ở 360dp → tablet/web; `flutter analyze` sạch; `flutter test` + `admin vitest` pass. |

## 2. Design Tokens — trích thật từ Landing Page

Đã crawl bundle CSS của `dau-viet-landing.vercel.app`, đối chiếu với `lib/core/theme` hiện tại. Phát hiện **drift** giữa hai hệ thống — cần hợp nhất:

| Token | Landing Page (đo thật) | Mobile hiện tại | Quyết định |
|---|---|---|---|
| Paper/Background | `#F8F0E0` (`--background`) | `#FFFBF4` parchmentSurface | **Đổi mobile → `#F8F0E0`** (đậm ấm hơn, giống landing) |
| Paper Card | `#FFFDF9` → `#FBF8F1` | `#FFF1D5` parchmentContainer | Dùng `#FBF8F1` cho card, `#F3E5CE` cho card-elevated |
| Ink/Foreground | `#49382F` (`--foreground`) | `#30251F` inkText | Thêm `#49382F` làm `inkSecondary`, giữ `#30251F` cho body |
| Primary/CTA | `#B93430` lacquer-red / `#85211F` dark | `#A51F18` cinnabarRed | Align → `#B93430` / `#85211F` |
| Accent | `#247D78` jade | — (chưa có) | **Thêm `jade`** cho tag/badge/state secondary |
| Heritage gold | `#E0AE45` | `#E7B451` | Align → `#E0AE45` |
| Heading/Chapter | `#283F36` deep-green (`#3c3026` ink heading) | `#1E4D3B` heritageGreen | Giữ `#1E4D3B` (đã gần), thêm `#283F36` cho chapter-heading |
| Font display | `Noto Serif` (var `--font-noto-serif`) | ✓ đã dùng | giữ |
| Font body | `Be Vietnam Pro` | ✓ đã dùng | giữ |
| Pixel accent | `Press Start 2P` (`--font-pixel`) | — | **Thêm** làm display-chip cho số chương/dấu vết (optional) |
| Shadow pixel | `4px 4px 0 #402C29` (shadow-pixel) | `heritageShadow` mềm | **Thêm `pixelShadow`** cho badge/chip, giữ `heritageShadow` cho card lớn |
| Border heading | `border-heading` `#3C3026`, 4px bottom | — | Đưa vào section-divider pattern |
| Eyebrow chip | `bg-primary/10 border-primary uppercase font-mono` | — | Mới: `SectionEyebrow` widget |

### Bảng màu sau khi hợp nhất (`dau_viet_colors.dart` v3.0)

```dart
// Giấy dó đa tầng (align Landing)
static const paperBackground  = Color(0xFFF8F0E0); // --background
static const paperCard        = Color(0xFFFBF8F1);
static const paperCardHi      = Color(0xFFF3E5CE);
static const paperDim         = Color(0xFFEFE3CC);

// Mực nho + heading
static const inkText          = Color(0xFF30251F);
static const inkHeading       = Color(0xFF3C3026); // heading-charcoal
static const inkSecondary     = Color(0xFF49382F); // --foreground
static const inkMuted         = Color(0xFF685F56);
static const inkLight         = Color(0xFF8C8077);

// Điểm nhấn chính
static const cinnabarRed      = Color(0xFFB93430); // lacquer-red
static const cinnabarRedDark  = Color(0xFF85211F);
static const imperialGold     = Color(0xFFE0AE45);
static const imperialGoldDark = Color(0xFFA97932); // --dv-gold
static const jade             = Color(0xFF247D78); // mới — accent phụ

// Xanh di sản / chapter
static const heritageGreen    = Color(0xFF1E4D3B);
static const chapterGreen     = Color(0xFF283F36); // số CHƯƠNG 01…
static const heritageGreenDark= Color(0xFF123427);

// Ngữ cảnh
static const natureGreen      = Color(0xFF64824C);
static const riverBlue        = Color(0xFF388EB4);
static const errorRed         = Color(0xFFB3261E);
static const woodBrown        = Color(0xFF613B28);
static const outline          = Color(0xFF8C6747);
static const outlineVariant   = Color(0xFFD4C1A5);

// Pixel shadow (Landing dùng cho chip/badge/button)
static const pixelShadow      = [BoxShadow(color: Color(0xFF402C29), offset: Offset(4,4), blurRadius: 0)];
static const pixelShadowSm    = [BoxShadow(color: Color(0xFF402C29), offset: Offset(2,2), blurRadius: 0)];
static const heritageShadow   = [BoxShadow(color: Color(0x1A613B28), offset: Offset(0,4), blurRadius: 12)];
```

### Typography (giữ skeleton, bổ sung)

```dart
static TextStyle get chapterNumber => GoogleFonts.pressStart2P( // hoặc Noto Serif 700
  fontSize: 32, color: DauVietColors.chapterGreen, letterSpacing: 2,
);
static TextStyle get sectionEyebrow => GoogleFonts.beVietnamPro(
  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4,
  color: DauVietColors.cinnabarRed, // uppercase
);
static TextStyle get clueTag => labelSmall.copyWith(color: DauVietColors.jade);
```

## 3. Phân tích hiện trạng (đã rà soát source)

| Khu | Trạng thái |
|---|---|
| `dau_viet_colors.dart` / `typography` / `theme` | Tồn tại v2.0 — tốt nhưng drift so với Landing (đỏ, vàng, nền) + thiếu jade, pixel-shadow, eyebrow style |
| `core/widgets/` | Đã có ~20 widget tái sử dụng (`ParchmentCard`, `Tactile3DButton`, `KabiMascotWidget`, `ShimmerProgressBar`, `HeritageScaffold`, `DongSonButton`, `MascotSpeechBubble`, …) — **nền tốt** |
| `features/learning/presentation/renderers/` | 16 renderer — nhiều renderer vẫn là `Container + Text` cơ bản (`drag_order` 2 dòng DV reference, `multiple_choice` 8, `matching` 4, `view_image` 11, `read` 20, `unsupported` 5) |
| `features/learning/presentation/` | `lesson_player_screen` (54 refs), `lesson_result` (70), `context_reader` (53), `hypothesis_verification` (53) đã tương đối ổn; cần thống nhất header 6-bước + mascot slot |
| `features/dashboard`, `learning_path`, `map`, `campaign`, `collection`, `streak`, `profile`, `island` | Số tham chiếu theme dao động 15–90 → phân mảnh. `learner_dashboard` chỉ 32 refs (thấp), `collection` 47, `profile` 42, `learning_streak` 32 |
| `dau-viet-admin` | Tokens có sẵn (`brand`, `surface`, `ink`, `border`, `success`, `warning`) + `tailwind.config.ts` đúng — **thiếu**: paper-card shadow, eyebrow chip, empty-state illustration, badge system, chapter-heading component, mascot accents |

## 4. Kiến trúc thay đổi — 6 lớp thực thi

> Quy tắc xuyên suốt: **không sửa API / provider / repo / DTO / contract**; chỉ thay `build()` + theme + widget composition. Tất cả màu/font/shape qua `DauViet*` hoặc semantic token — cấm hard-code `Colors.*` / `TextStyle()` inline / `Icons.*` cho điểm nhấn chính.

### Phase A — Design System v3 (foundation, 1 PR đầu)

**`dau-viet-mobile/lib/core/theme/`**
- `dau_viet_colors.dart` → cập nhật theo bảng trên; thêm `jade`, `chapterGreen`, `inkHeading`, `inkSecondary`, `pixelShadow`, `pixelShadowSm`.
- `dau_viet_typography.dart` → thêm `chapterNumber`, `sectionEyebrow`, `clueTag`, `quoteAncient` (đã có `ancientCitation`).
- `dau_viet_theme.dart` → `scaffoldBackgroundColor = paperBackground` (đổi từ `parchmentSurface`); update `ColorScheme` (primary `#B93430`, secondary `#E0AE45`, tertiary `jade`); `cardTheme.color = paperCard`, viền `outlineVariant`, `elevation 0` + `heritageShadow` wrapper.

**`lib/core/widgets/` — bổ sung widget mới (design-system atoms)**

| Widget | Vai trò | Dùng ở |
|---|---|---|
| `SectionEyebrow` | chip `CHƯƠNG 01 · …` border-2 + pixel-shadow-sm | Journey, campaign, lesson header |
| `ChapterNumberBadge` | số `01`–`06` cỡ 28–36, pixel-accent, `chapterNumber` style | Period map, lesson steps |
| `PaperGrainOverlay` | texture `CustomPainter` noise mỏng `opacity 0.04` | Scaffold wrapper, hero card |
| `TactileCard` | `ParchmentCard` + `pixelShadowSm` + `press-scale` animation | Thay `Container`/`Card` thô |
| `StampSealBadge` | huy hiệu đỏ chu sa tròn, viền kép, ký tự "DẤU" | Unlock/reward/clue-complete |
| `ClueTag` | chip `Hiện vật · Địa hình · Nhân vật · Cổ thư` với `jade`/icon | Evidence select, collection |
| `MascotSlot` | slot nhất quán `Kabi`/`BeSu` + `MascotSpeechBubble` đã có | Mọi màn (empty/loading/success/error) |
| `SectionDivider` | `border-b-4 border-heading` + `SectionEyebrow` | Thay `Divider()` default |
| `HeroPaperBanner` | hero 16:9 gradient paper + `pixelShadow` | Campaign, lesson entry |
| `EmptyStateCard` | illustration placeholder + eyebrow + body + CTA | Collection rỗng, list rỗng |
| `StepProgressBar` | 6-bước `Bối cảnh → Dấu vết → Giả thuyết → Kiểm chứng → Dựng lại → Kết luận`, icon + số + trạng thái | LessonPlayer header |
| `RareFrameBadge` | khung COMMON/UNCOMMON/RARE/EPIC với màu + ánh-kim gradient | Collection, reward |

**Acceptance Phase A:** `flutter analyze` sạch; widget-tests cho 12 atom; `theme_showcase_screen.dart` cập nhật demo đủ atoms; không đổi behavior.

### Phase B — Discovery / Map / Dashboard / Campaign (learner-facing chrome)

Mục tiêu: biến "danh sách chữ phẳng" → "Bản đồ Hành trình & Sổ tay Thời kỳ".

| File | Thay đổi chính |
|---|---|
| `features/dashboard/presentation/learner_dashboard_screen.dart` | Hero `HeroPaperBanner` + streak `ChapterNumberBadge` + `MascotSlot` chào; "Bài học hôm nay" = `TactileCard` có `SectionEyebrow "TIẾP TỤC HÀNH TRÌNH"` |
| `features/learning_path/presentation/*` + `map/presentation/historical_map_screen.dart` | Chặng = `SectionDivider("CHƯƠNG 0X — <TÊN>")` + `ChapterNumberBadge`; node = `TactileCard` bo tròn 20 + `pixelShadowSm`; ghim di tích vệ tinh = `StampSealBadge` khi `unlocked` |
| `map/presentation/path_event_node.dart` | Thêm scale-tap anim, border 2.5px `chapterGreen`, background `paperCard`, `yearLabel` eyebrow |
| `map/presentation/event_action_sheet.dart` | Bottom-sheet → `PaperGrainOverlay` + `HeroPaperBanner` cover + `StampSealBadge` cho status |
| `features/campaign/presentation/campaign_detail_screen.dart` | Hồ sơ Chiến dịch: hero 16:9 `HeroPaperBanner`, cụm `4 Dấu Vết` = 4 `ClueTag` + progress ring, CTA `DongSonButton` (đã có) kích lớn |
| `features/onboarding/presentation/onboarding_screen.dart` + auth | Đồng bộ `paperBackground` + `MascotSlot` + `SectionEyebrow` |

### Phase C — Lesson Player & Renderer (game-hóa, AC-2) — **lớp lớn nhất**

**Header chung (`lesson_player_screen.dart`)**
- Thay AppBar mặc định → `HeritageScaffold` + `StepProgressBar` 6-bước + `_StreakBadge`/`_EnergyBadge` hiện có (giữ nguyên logic).
- `MascotSlot` góc trên-phải, bubble thay đổi theo `_FeedbackTone` (success/warning/error).
- `_FeedbackTone.success` → `StampSealBadge` overlay "ĐÚC KẾT" + `goldConfettiOverlay` (đã có).
- `_FeedbackTone.warning/error` → `MascotSpeechBubble` gợi ý.

**Renderers — tái thiết kế theo "Bàn điều tra"**

| Renderer | File | Kiểu mới |
|---|---|---|
| `READ` | `read_renderer.dart` | Trang **Cổ thư**: khung `PaperGrainOverlay` + trích dẫn `ancientCitation` + drop-cap + `StampSealBadge` nguồn |
| `VIEW_IMAGE` | `view_image_renderer.dart` | **Sa bàn**: khung ảnh `pixelShadow`, caption `sectionEyebrow`, nút "Soi chi tiết" mở fullscreen pinch-zoom |
| `EVIDENCE_SELECT` | `evidence_select_renderer.dart` | **Thẻ Dấu Vết**: `TactileCard` + `ClueTag` loại + `StampSealBadge` khi chọn (flip animation 200ms) |
| `HYPOTHESIS_CHOICE` | `hypothesis_renderer.dart` + `hypothesis_verification_screen.dart` | **Bàn Suy Luận**: paper-card lớn + đường nối `CustomPainter` giữa clue → giả thuyết, radio = `StampSealBadge` |
| `VERIFICATION` | `verification_renderer.dart` | 3 mức feedback = `ClueTag` màu (success `natureGreen` / partial `imperialGold` / contradiction `cinnabarRed`) + `MascotSlot` reaction |
| `DRAG_ORDER` | `drag_order_renderer.dart` + `chronological_order_screen.dart` | **Timeline Chiến trận**: `ChapterNumberBadge` 01–04 + mốc `Sáng sớm/Trưa/Chiều tà` dạng `sectionEyebrow`, drag-handle `⋮⋮` tô rõ, feedback từng vị trí |
| `CER_CHOICE` / `CER` | `cer_choice_renderer.dart`, `cer_renderer.dart`, `cer_conclusion_screen.dart` | **Đúc kết**: 3 slot `Claim/Evidence/Reasoning` xếp dọc với connector; chọn mảnh → `StampSealBadge` đóng dấu |
| `MATCHING` | `matching_renderer.dart`, `matching_board_screen.dart` | Card lật `TactileCard`, đường nối animated `CustomPainter` |
| `REASONING_CONNECT` | `reasoning_connect_renderer.dart` | Node-link giống `Bàn Suy Luận` |
| `MULTIPLE_CHOICE` | `multiple_choice_renderer.dart`, `multiple_choice_quiz_screen.dart` | Option = `TactileCard` + `ChapterNumberBadge` A/B/C/D, feedback stamp |
| `EXPLORE_MAP` / `HOTSPOT` | `explore_map_renderer.dart` | Marker = `StampSealBadge` pulsing nhẹ |
| `REFLECTION` | `reflection_renderer.dart` | Paper-card quote + `ancientCitation` |
| `UNSUPPORTED` | `unsupported_renderer.dart` | `EmptyStateCard` thay `Text` thô |
| `renderer_base.dart` | — | Thêm `SectionEyebrow`, `ClueTag`, `StampSealBadge` builders để các renderer tái dùng |
| `learning_asset_image.dart` | — | Thêm `pixelShadow` + `PaperGrainOverlay` overlay tùy chọn |

**Acceptance Phase C:** mỗi renderer có golden-test 360×800 + 768×1024; pixel-diff không crash; tab-order keyboard đúng (focus ring `outline`).

### Phase D — Collection / Streak / Profile / Island / Result

| File | Thay đổi |
|---|---|
| `collection_screen.dart`, `collection_detail_screen.dart`, `dossier_*` | **Bảo tàng**: grid `TactileCard` + `RareFrameBadge` theo độ hiếm; locked = grayscale + `StampSealBadge` khóa; unlocked = `goldConfetti` khi vào |
| `unlock_celebration_dialog.dart` | Giữ logic; thay card → `HeroPaperBanner` + `StampSealBadge` lớn |
| `learning_streak_screen.dart` | Ngọn lửa `StampSealBadge` + `ChapterNumberBadge` chuỗi ngày, `SectionDivider` tuần |
| `profile_screen.dart` | Header `paperBackground` + avatar `StampSealBadge` + stat `ChapterNumberBadge` |
| `island_screen.dart`, `island_shop_screen.dart`, `heritage_island_screen.dart`, `inventory_screen.dart`, `energy_management_screen.dart` | Đồng bộ `paperBackground`, `TactileCard`, `pixelShadowSm`, `EmptyStateCard` |
| `lesson_result_screen.dart`, `lesson_entry_screen.dart` | `StepProgressBar` done-state + `MascotSlot` ăn mừng + `StampSealBadge` EXP/coin |

### Phase E — Admin (`dau-viet-admin`) — Phase 5 của issue

| Khu | Thay đổi |
|---|---|
| `globals.css` + `tailwind.config.ts` | Thêm `--color-jade #247D78`, `--color-chapter-green #283F36`, `--color-gold-dark #A97932`, `--shadow-pixel`, `--shadow-pixel-sm`, `--shadow-heritage`, `fontFamily.pixel` |
| `components/` mới `SectionEyebrow`, `ChapterBadge`, `StampSeal`, `PaperCard`, `EmptyState`, `ClueTag`, `RareFrame` | mirror API của mobile atoms (React) |
| Sidebar/Header | `bg-paper-card` + `border-b-4 border-heading` + `SectionEyebrow` trên section-title |
| Dashboard stat cards | `PaperCard` + icon jade/cinnabar + `chapterGreen` cho số lớn |
| `DataTable` | Header `bg-paper-card` + `eyebrow` uppercase, thumbnail ảnh bìa, badge trạng thái (`StampSeal` mini) |
| Form builder (events/lessons/evidence/map-locations) | Section = `SectionDivider` + `SectionEyebrow`, `EmptyState` cho list rỗng, `PaperCard` thay `div.border` |
| Preview pane | Mirror mobile renderer (đọc-only) để admin xem style thật |

### Phase F — Docs / Tests / Handoff

- `docs/ART_DIRECTION.md` → cập nhật tokens v3 (nếu chưa có, tạo `docs/UI_DESIGN_SYSTEM_V3.md`).
- `docs/PROJECT_OVERVIEW.md` → bảng "đã code" bổ sung dòng UI/UX overhaul.
- `docs/project-changelog.md` → entry `2026-10-29 Issue #40`.
- `tasks/TASK-0031/task.json` + `brief.md` + `handoff.md` cập nhật từng phase.
- Tests:
  - `test/theme/design_tokens_test.dart` — assert hex đúng bảng trên.
  - `test/widgets/atoms_test.dart` — 12 widget mới render + a11y.
  - `test/renderers/*_golden_test.dart` — golden 360/768 cho 12 renderer chính.
  - Cập nhật test hiện có vi phạm style (không assert text/copy/behavior đổi).
  - Admin: `src/components/atoms/*.test.tsx` cho các atom React.

## 5. Thứ tự PR đề xuất (incremental, mergeable)

1. **PR-1 (Phase A):** Design tokens v3 + atoms + `theme_showcase`. CI xanh. → Cho phép merge sớm.
2. **PR-2 (Phase B):** Dashboard + Map + LearningPath + Campaign.
3. **PR-3 (Phase C):** Lesson Player header + 12 renderers — **lớn nhất**, review kỹ.
4. **PR-4 (Phase D):** Collection + Streak + Profile + Island + Result.
5. **PR-5 (Phase E):** Admin CMS polish.
6. **PR-6 (Phase F):** Docs + golden-test cleanup + handoff.

Mỗi PR ≤ ~600 LOC net diff; không cross-touch logic; mỗi PR pass `flutter analyze` + `flutter test`.

## 6. AC → check mapping

| AC | Check |
|---|---|
| AC-1 | `design_tokens_test.dart` assert palette; grep `Colors\.(blue\|grey\|black)` trong `lib/features` = 0; `theme_showcase` chụp đủ atoms. |
| AC-2 | Golden tests `*_golden_test.dart` cho 12 renderer ở 2 size; reviewer checklist "không còn `Container+Text` thô". |
| AC-3 | `MascotSlot` xuất hiện trên: dashboard, map empty, lesson entry, submit-success/error, unlock, collection-empty, profile, onboarding — checklist bằng widget-test `findsOneWidget`. |
| AC-4 | `flutter analyze` 0 issue; `flutter test` pass; admin `npx vitest run` pass; screenshot 360×800 + 390×844 + 768×1024 đính kèm handoff. |

## 7. Rủi ro & giảm thiểu

| Rủi ro | Xử lý |
|---|---|
| Phá vỡ test hiện có (assert màu/text/copy cũ) | PR-1 giới hạn tokens/atoms; PR-3 tách renderer theo từng commit, cập nhật test theo từng renderer |
| `GoogleFonts.pressStart2P` tải chậm/offline | Đã dùng `google_fonts` — bundle sẵn qua `GoogleFonts.config.allowRuntimeFetching=false` + assets/fonts fallback; fallback = `Noto Serif` 700 |
| `CustomPainter` cho connector (Bàn Suy Luận) phức tạp | Giới hạn đường nối thẳng/curly brace; không animation phức tạp |
| Admin font chưa load `Noto Serif`/`Be Vietnam Pro` | Thêm `<link>` Google Fonts hoặc `next/font` — kiểm `layout.tsx` |
| Tính năng động (streak/energy/collection) phụ thuộc provider | Không đổi provider; chỉ đổi presentation |
| Regression "basic" do dev quên dùng atoms | `docs/UI_DESIGN_SYSTEM_V3.md` + `analysis_options.yaml` lint `avoid_hardcoded_colors` (custom rule nếu có, else convention) |

## 8. Out-of-scope (ghi rõ)

- Không sửa backend Java/Flyway — API giữ nguyên.
- Không thay đổi logic submit/complete/reward/streak/energy.
- Không thay đổi route (`go_router`) trừ khi cần cho `theme_showcase`.
- Không redesign Landing Page (đó là nguồn tham chiếu).
- Không làm dark mode (issue không yêu cầu; Phase sau).

## 9. Definition of Done

- [ ] `dau_viet_colors.dart` v3 deploy + `theme_showcase` demo đủ.
- [ ] 12 atoms `core/widgets` mới + widget tests.
- [ ] 12 renderer thiết kế lại + golden tests 2 size.
- [ ] Dashboard/Map/Campaign/Collection/Streak/Profile/Island/Result polish.
- [ ] Admin: tokens + atoms + pages polish.
- [ ] `flutter analyze` sạch; `flutter test` + `admin vitest` pass; e2e smoke chạy được.
- [ ] `docs/UI_DESIGN_SYSTEM_V3.md` + changelog + `PROJECT_OVERVIEW` update.
- [ ] Screenshots handoff: 360×800, 390×844, 768×1024 cho mỗi màn chính.
- [ ] `tasks/TASK-0031/handoff.md` ghi rõ next action + blockers.
