# Phase 09 â€” Mobile UI: Profile Stats + Player Header Fix

## Context Links
- `dau-viet-mobile/lib/features/profile/presentation/profile_screen.dart` â€” `_StatsCard` has 4 `_StatCell`s (EXP, Äiá»ƒm Sá»­ KĂ½, BĂ i há»c, Váº­t pháº©m). Add streak cells.
- `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart:811-838` â€” flame '12' hardcode (partially handled in phase-06 with `DailyStreakBadgeWidget(compact:true)`; verify here it's fully wired).
- `dau-viet-mobile/lib/features/streak/data/streak_providers.dart` â€” `streakProvider`.

## Overview
- **Priority**: P2
- **Status**: complete
- **Est**: 1h

Surface `currentStreak` + `longestStreak` in profile `_StatsCard`. Verify the lesson_player flame badge is fully driven by `streakProvider` (no fallback to hardcode).

## Key Insights
- Profile `_StatsCard` currently renders 4 cells â€” add 2 streak cells â†’ 6 total. Decide layout: 2 rows of 3 vs 3 rows of 2 (matches existing 2Ă—2 â€” going 2Ă—3 keeps symmetry).
- Alternative: replace one of the existing cells (e.g., "Váº­t pháº©m") if 6 is too crowded â€” defer decision to UI review; default = add both.
- Player header was partially fixed in phase-06 â€” this phase is verification + polish, not new work.

## Requirements
- `_StatCell` rows show: `Chuá»—i ngĂ y` (currentStreak, flame icon), `Ká»· lá»¥c` (longestStreak, trophy icon).
- Read `streakProvider` â€” already loaded by dashboard, no extra call.
- Loading state â†’ 'â€”'; error â†’ 'â€”' (don't break profile on streak fetch fail).

## Architecture

```
ProfileScreen._StatsCard
  â”œâ”€â”€ _StatCell(EXP)
  â”œâ”€â”€ _StatCell(Äiá»ƒm Sá»­ KĂ½)
  â”œâ”€â”€ _StatCell(BĂ i há»c)
  â”œâ”€â”€ _StatCell(Váº­t pháº©m)
  â”œâ”€â”€ _StatCell(Chuá»—i ngĂ y đŸ”¥)   (NEW â€” streak.currentStreak)
  â””â”€â”€ _StatCell(Ká»· lá»¥c đŸ†)      (NEW â€” streak.longestStreak)
```

## Related Code Files

**Modify**:
- `dau-viet-mobile/lib/features/profile/presentation/profile_screen.dart` â€” `_StatsCard` build method.
- `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart` â€” verify hardcode '12' fully removed; if still present (phase-06 missed it), wire `DailyStreakBadgeWidget(compact:true)`.

## Implementation Steps

### Step 1 â€” Add streak cells to `_StatsCard`

In `profile_screen.dart` `_StatsCard` widget:

```dart
class _StatsCard extends ConsumerWidget {  // was StatelessWidget if needed
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(rewardSummaryProvider);
    final streak = ref.watch(streakProvider);
    // ... existing 4 cells ...
    // NEW:
    _StatCell(
      icon: Icons.local_fire_department_rounded,
      label: 'Chuá»—i ngĂ y',
      value: streak.valueOrNull?.currentStreak.toString() ?? 'â€”',
      color: const Color(0xFFE65100),
    ),
    _StatCell(
      icon: Icons.emoji_events_rounded,
      label: 'Ká»· lá»¥c',
      value: streak.valueOrNull?.longestStreak.toString() ?? 'â€”',
      color: const Color(0xFFFFB74D),
    ),
  }
}
```

If `_StatsCard` is `StatelessWidget`, convert to `ConsumerWidget` (or wrap the 2 new cells in a `Consumer` builder â€” smaller diff).

### Step 2 â€” Verify player header

Re-Read `lesson_player_screen.dart` around line 811-838 â†’ confirm `DailyStreakBadgeWidget(compact:true)` is wired. If not (phase-06 deferred), wire it now â€” same pattern as dashboard.

### Step 3 â€” Visual check
- Profile renders 6 stat cells (or 5 if we dropped one for space).
- Numbers match backend `GET /me/streak`.
- Player header flame shows real `currentStreak` (lit when >0, grey when 0).

## Todo List
- [ ] Add `_StatCell` for `currentStreak` + `longestStreak` in profile.
- [ ] Verify `_StatsCard` widget type supports `ref.watch` (convert to ConsumerWidget if needed).
- [ ] Confirm lesson_player header is fully wired (residual from phase-06).
- [ ] `flutter analyze` clean.
- [ ] Manual smoke on profile + player header.

## Success Criteria
- Profile shows real streak numbers (0 for new user is fine).
- No hardcoded '12' anywhere in the app related to streak (search `'12'` + `streak` keywords).

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| `_StatsCard` layout overflows with 6 cells | Wrap in `Wrap` or reduce icon size; if 6 doesn't fit, show only `currentStreak` |
| Player header alignment breaks | `compact:true` already sizes for header; visual check |

## Security Considerations
- None â€” read-only UI.

## Next Steps
- Phase 10: docs + cleanup.
