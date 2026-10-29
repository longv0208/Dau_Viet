# TASK-0031 — Handoff: Issue #40 UI/UX Overhaul

## Trạng thái kết thúc

**Status: `implemented`** — tất cả phases đã merge lên branch `feat/issue-40-ui-ux-overhaul`. Chờ user ủy quyền commit/merge sang `main`.

## Kết quả kiểm chứng

| Gate | Lệnh | Kết quả |
|------|------|---------|
| Mobile tests | `cd dau-viet-mobile && flutter test` | **514/514 pass** (51.4s) |
| Mobile analyze | `flutter analyze` | **0 new issues** — 9 pre-existing `island/*` warnings (dart:math unused, unnecessary_underscores, deprecated translate/scale) |
| Admin type-check | `cd dau-viet-admin && npx tsc --noEmit` | **clean** |
| Admin tests | `npx vitest run` | **49/49 files, 294/294 tests** |

## Phases hoàn thành

- **Phase A (Design tokens v3)** — `dau_viet_colors.dart`, `dau_viet_typography.dart`, `dau_viet_theme.dart`; legacy aliases `parchment*` → `paper*` giữ nguyên.
- **Phase B (12 atoms)** — `lib/core/widgets/{section_eyebrow, chapter_number_badge, paper_grain_overlay, tactile_card, stamp_seal_badge, clue_tag, mascot_slot, section_divider, hero_paper_banner, empty_state_card, step_progress_bar, rare_frame_badge}.dart`; `theme_showcase_screen.dart` extended.
- **Phase C (Screens)** — `learner_dashboard_screen`, `historical_map_screen`, `path_event_node`, `event_action_sheet`, `campaign_detail_screen`, `lesson_player_screen` (top-bar rebuild: StepProgressBar 6 chặng + fraction chip).
- **Phase D (11 renderers)** — `read`, `view_image`, `reflection`, `unsupported`, `evidence_select`, `hypothesis`, `verification`, `drag_order`, `cer`, `cer_choice`, `matching`, `reasoning_connect`.
- **Phase E (Collection/Streak/Profile/Island)** — `collection_screen`, `learning_streak_screen`, `profile_screen`, `island_screen`, `island_shop_screen`, `inventory_screen`, `energy_management_screen`, `heritage_island_screen`.
- **Phase F (Admin)** — `globals.css` tokens, `tailwind.config.ts`, `layout.tsx` (Press_Start_2P), 8 atoms trong `src/components/atoms/`, shell/header/empty-state/status-chip polish, 51 page/component files.

## Overflow / regression fixes đã áp

1. `SectionDivider`: `Flexible(fit: FlexFit.loose)` trên `SectionEyebrow` + `Expanded` title.
2. `SectionEyebrow`: `Text` `overflow: ellipsis, maxLines: 1`.
3. `ClueTag`: label `Text` wrap `Flexible` + `ellipsis`.
4. `StepProgressBar`: `LayoutBuilder` — `<200px` dot=24 no-label, `<360px` dot=32 no-label, `>=360px` full label. Connector `Expanded` + `Container(height:2)` giữa các dot.
5. `HeroPaperBanner` caller (dashboard hero): `height: 198 → 202` để tránh 0.8px overflow do font metrics.
6. `_CerRoleHeader`/`_SlotHeader`: `ClueTag` wrap `Flexible(flex:0)`.
7. `lesson_player_screen` top bar: `SectionEyebrow` rút khỏi Row (quá rộng 236px), giữ `Expanded(title)` + `EnergyBadge` + `StreakBadge` + `SoundToggleButton`; thêm `x/y` progress chip bên cạnh `StepProgressBar` — match test `find.text('1/4')`.

## Test updates

- `test/theme/design_tokens_test.dart` — **mới**, 9 tests validate v3 tokens.
- `test/learning/learning_flow_issue_29_test.dart` —
  - `import` `step_progress_bar.dart` (replaces `shimmer_progress_bar.dart`);
  - Phase 01-04 regression: `find.byType(ShimmerProgressBar)` → `find.byType(StepProgressBar)` + `expect(find.text('0/3'))`;
  - TC-ACT-17 submit: `ensureVisible` + `warnIfMissed: false` cho `GỬI CÂU TRẢ LỜI` (button nằm ngoài viewport trong scroll view).
- `test/collection/collection_screen_test.dart` — empty-state text `Chưa có dấu vết` / `bài học`.
- `test/visual_storytelling_test.dart` — `MultipleChoiceQuizScreen` test bọc `ProviderScope` + override `energyRepositoryProvider`/`rewardSummaryProvider` (EnergyPill giờ là `ConsumerWidget`).

## Cleanup đã xong

- Revert generated plugin registrant files (`linux/`, `macos/`, `windows/`) — chỉ `flutter pub get` artifacts.
- Drop `stash@{0}` (snapshot generated plugin files cũ).
- Xóa `_buildCelebrationScreen` (dead code 128 dòng).
- Xóa unused `section_eyebrow`/`dau_viet_colors` imports.

## Gaps / repo-rule deviations

- **GitNexus `impact`/`detect_changes`**: không chạy được trong session (index availability chưa xác nhận). Code đã sweep tay; test suite green là evidence regression.
- **Manual visual verify trên device**: không thực hiện — evidence từ `flutter test` widget tests + analyze.

## Next action cho maintainer

```bash
git add -A
git diff --cached --check                    # trailing whitespace
git status                                   # expect ~108 modified + untracked atoms/tests/plans/tasks
# Optional: run GitNexus detect_changes({scope:"compare", base_ref:"main"}) trước khi commit
git commit -m "feat(ui): issue #40 — Design System v3 overhaul mobile + admin"
```

Không commit/push mà không có ủy quyền user.
