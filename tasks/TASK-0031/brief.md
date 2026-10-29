# TASK-0031 — Issue #40 UI/UX Overhaul Brief

> Đọc `plans/261029-issue-40-ui-overhaul/plan.md` trước khi sửa bất kỳ file nào.

## Bối cảnh

Issue #40 yêu cầu **đại tu toàn diện UI/UX** cho `dau-viet-mobile` (Flutter) + `dau-viet-admin` (Next.js), khắc phục:

1. Ngôn ngữ thiết kế phân mảnh — một số màn dùng tông xanh rêu `#1E4D3B`, số khác dùng list phẳng viền cứng.
2. Lạm dụng Icon Material default, thiếu minh họa di sản & linh vật.
3. `LessonPlayerScreen` + renderer giống form trắc nghiệm khô khan, không phải "Sổ tay & Bàn điều tra Thám tử Lịch sử".
4. Admin CMS còn thô, thiếu hierarchy, empty-state, badge, card layout.

## Nguồn chân lý thiết kế

**Landing Page:** https://dau-viet-landing.vercel.app/ — đã trích tokens thật từ bundle CSS:

```
--background: #F8F0E0
--foreground: #49382F
--lacquer-red: #B93430  /  dark: #85211F
--heritage-gold: #E0AE45
--jade: #247D78
--font-noto-serif, --font-be-vietnam, --font-pixel (Press Start 2P)
chapter heading: #283F36, border-heading: #3C3026 4px
shadow-pixel: 4px 4px 0 #402C29  /  shadow-pixel-sm: 2px 2px
```

## Phạm vi 6 Phase

- **A.** Design tokens v3 + 12 atoms (`SectionEyebrow`, `ChapterNumberBadge`, `PaperGrainOverlay`, `TactileCard`, `StampSealBadge`, `ClueTag`, `MascotSlot`, `SectionDivider`, `HeroPaperBanner`, `EmptyStateCard`, `StepProgressBar`, `RareFrameBadge`).
- **B.** Dashboard + Map + LearningPath + Campaign chrome.
- **C.** LessonPlayer header 6-bước + 12 renderer (`READ`, `VIEW_IMAGE`, `EVIDENCE_SELECT`, `HYPOTHESIS`, `VERIFICATION`, `DRAG_ORDER`, `CER`, `MATCHING`, `REASONING_CONNECT`, `MC`, `EXPLORE_MAP`, `REFLECTION`).
- **D.** Collection + Streak + Profile + Island + Result.
- **E.** Admin CMS polish (tokens + atoms React + pages).
- **F.** Docs + golden tests + handoff.

## Invariants

- Không đụng API contract, provider, repo, DTO, schema, auth, reward, learning-engine.
- Không `Colors.blue|grey|black` inline trong `features/`; mọi màu qua `DauVietColors`.
- Không `TextStyle(...)` inline trừ khi extend từ `DauVietTypography.*`.
- Widget tests + golden tests bắt buộc cho atoms và renderer mới.
- `flutter analyze` sạch sau mỗi phase.

## Workflow

6 PR tuần tự theo `plan.md` §5 — mỗi PR mergeable độc lập, không cross-touch logic.

**Bắt đầu:** `Phase A` — cập nhật `dau_viet_colors.dart` theo bảng plan §2 → atoms → theme_showcase.
