# Phase 06 â€” Mobile UI: Dashboard Streak Badge

## Context Links
- `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart:325-380` â€” existing hardcoded pill row (â¡'12' + â¤ï¸'3').
- `dau-viet-mobile/lib/core/widgets/combo_streak_badge_widget.dart` â€” existing "Ngá»n Lá»­a HĂ o KhĂ­" badge used for **answer combo** (in-attempt multiplier). Naming conflict â€” see Key Insights.
- `dau-viet-mobile/lib/features/energy/presentation/energy_pill_widget.dart` (or wherever the energy pill lives â€” find via Glob `*energy*pill*.dart` / `*energy*badge*.dart`).

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 2h

Replace the hardcoded â¤ï¸'3' streak pill in the dashboard header with a real `StreakBadge` driven by `streakProvider`. Tapping it navigates to the streak detail screen (phase-07). Also create `streak_badge_widget.dart` as the reusable component (differentiated from `ComboStreakBadgeWidget`).

## Key Insights
- **Naming conflict**: `ComboStreakBadgeWidget` already claims "Ngá»n Lá»­a HĂ o KhĂ­" for the in-attempt answer combo (3-correct-in-a-row â†’ multiplier). That's IN-SESSION and unrelated to the daily streak. **Decision**: keep `ComboStreakBadgeWidget` name/scope; create NEW `DailyStreakBadgeWidget` for the DB-backed daily streak. Title in UI = "Chuá»—i NgĂ y Há»c" (matches user task wording); the existing "Ngá»n Lá»­a HĂ o KhĂ­" stays scoped to combo.
- **Real energy pill exists?** Dashboard 'â¡12' is also hardcoded â€” check if `EnergyPillWidget` is already integrated or if this row is fully hardcoded. If hardcoded, fix BOTH pills in this phase (energy is already shipped â€” GAME-03 â€” so wiring is trivial); if wired, only fix the streak pill.
- **Two display states**: streak â‰¥1 (lit flame + number) vs streak = 0 (greyed flame + 0). Server provides `completedToday` â€” use for "already studied today" visual tick.

## Requirements
- Tap pill â†’ push `StreakDetailScreen` (phase-07).
- Loading state â†’ pill shows `â€¦` (skeleton or placeholder).
- Error state â†’ pill shows `!` + tap â†’ `streakProvider.refresh()`.
- Display `currentStreak` count, NOT `longestStreak`.
- Visual: same row layout as existing (icon + number) â€” keep alignment with energy pill.

## Architecture

```
DashboardScreen._buildGreetingAndStatsRow()
  â”œâ”€â”€ EnergyPill (existing or rewire)
  â””â”€â”€ DailyStreakBadgeWidget  (NEW â€” reads ref.watch(streakProvider))
        â”œâ”€â”€ AsyncData â†’ flame icon + currentStreak
        â”œâ”€â”€ AsyncLoading â†’ skeleton pill
        â”œâ”€â”€ AsyncError â†’ ! + retry onTap
        â””â”€â”€ onTap â†’ Navigator.push(StreakDetailScreen)
```

## Related Code Files

**Create**:
- `dau-viet-mobile/lib/features/streak/presentation/daily_streak_badge_widget.dart`

**Modify**:
- `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart` â€” replace lines ~354-377 hardcoded â¤ï¸'3' block with `<DailyStreakBadgeWidget />`; also rewire â¡'12' to energy provider if not already wired.
- `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart:811-838` â€” replace hardcoded flame '12' with `<DailyStreakBadgeWidget compact />` (same provider, smaller size for header row).

**Delete**: none.

## Implementation Steps

### Step 1 â€” `daily_streak_badge_widget.dart`

```dart
/// Ngá»n Lá»­a HĂ o KhĂ­ â€” DAILY streak (DB-backed, server-authoritative).
/// KHĂ”NG nháº§m vá»›i ComboStreakBadgeWidget (in-attempt answer streak).
/// Äá»c streakProvider â€” auto rebuild khi complete attempt má»›i Ä‘áº©y snapshot.
class DailyStreakBadgeWidget extends ConsumerWidget {
  final bool compact;
  final VoidCallback? onTap;
  const DailyStreakBadgeWidget({super.key, this.compact = false, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(streakProvider);
    return async.when(
      data: (s) => _pill(
        icon: Icons.local_fire_department_rounded,
        value: s.currentStreak,
        lit: s.currentStreak > 0,
        completedToday: s.completedToday,
        onTap: onTap,
      ),
      loading: () => _skeleton(),
      error: (_, __) => _pill(
        icon: Icons.error_outline, value: null, lit: false,
        completedToday: false,
        onTap: () => ref.read(streakProvider.notifier).refresh(),
      ),
    );
  }

  Widget _pill({...}) => InkWell(
    onTap: onTap ?? () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StreakDetailScreen())),
    child: Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: lit ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(compact ? 10 : 16),
        border: Border.all(
            color: lit ? const Color(0xFFFFB74D) : const Color(0xFFE0E0E0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: compact ? 13 : 14,
            color: lit ? const Color(0xFFE65100) : Colors.grey),
        const SizedBox(width: 3),
        Text('${value ?? '!'}',
            style: TextStyle(fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w900,
                color: lit ? const Color(0xFFE65100) : Colors.grey)),
        if (completedToday) ...[
          const SizedBox(width: 2),
          const Icon(Icons.check_circle, size: 10, color: Color(0xFF2E7D32)),
        ],
      ]),
    ),
  );
}
```

### Step 2 â€” Wire into dashboard

In `learner_dashboard_screen.dart` `_buildGreetingAndStatsRow`, replace the â¤ï¸'3' hardcoded `Container` block (lines ~355-377) with:

```dart
const DailyStreakBadgeWidget(),
```

And replace the â¡'12' block (lines ~329-351) with the existing `EnergyPillWidget` if available â€” search the codebase first:

```bash
grep -rn "EnergyPill\|energy.*pill\|EnergyBadge" dau-viet-mobile/lib/
```

If no such widget exists, this phase ALSO creates a minimal `EnergyPill` reading `energyProvider` â€” but since GAME-03 is shipped, the widget likely already exists somewhere; just wire it.

### Step 3 â€” Wire into lesson_player_screen

Replace the hardcoded flame '12' `Container` (lines ~811-838) inside the header row:

```dart
const DailyStreakBadgeWidget(compact: true),
```

Use `compact: true` to preserve the smaller visual inside the player header.

### Step 4 â€” Visual check
- Run app, sign in, see real streak number (or 0 for fresh user).
- Tap pill â†’ routes to detail screen (phase-07 placeholder OK).
- Verify energy pill still shows real energy.

## Todo List
- [ ] Create `daily_streak_badge_widget.dart` (lit/grey/error/loading states).
- [ ] Search for existing energy pill widget; if missing, create.
- [ ] Replace â¤ï¸'3' hardcode in `learner_dashboard_screen.dart` with `DailyStreakBadgeWidget`.
- [ ] Replace â¡'12' hardcode with real energy pill (if missing).
- [ ] Replace flame '12' hardcode in `lesson_player_screen.dart` with `DailyStreakBadgeWidget(compact:true)`.
- [ ] `flutter analyze` clean.
- [ ] Manual smoke: dashboard â†’ tap streak â†’ opens detail; lesson player header shows same number.

## Success Criteria
- Zero hardcoded '12'/'3' remaining in dashboard or player.
- Streak number matches backend `GET /me/streak` for the test user.
- `completedToday=true` shows the green check tick.

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| ComboStreakBadge name confusion in code reviews | Document in file header â€” `DailyStreakBadgeWidget` â‰  `ComboStreakBadgeWidget`. |
| Provider not yet loaded â†’ flash of grey skeleton | Acceptable; skeleton is graceful. `applySnapshot` after complete avoids flash. |
| Tap navigation before phase-07 exists | Phase-07 stub screen is fine â€” push route + show "Coming soon" placeholder. |
| Dashboard `_buildGreetingAndStatsRow` is const somewhere upstream | The widget itself is `const` â€” no rebuild issue. |

## Security Considerations
- None â€” read-only UI.

## Next Steps
- Phase 07: full streak detail screen with calendar.
