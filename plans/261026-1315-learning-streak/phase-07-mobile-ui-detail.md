# Phase 07 â€” Mobile UI: Streak Detail Screen

## Context Links
- `dau-viet-mobile/lib/features/streak/data/streak_providers.dart` (phase-05) â€” `streakProvider` + `streakCalendarProvider((from, to))`.
- `dau-viet-mobile/lib/features/profile/presentation/profile_screen.dart` â€” `_StatsCard`/`_StatCell` pattern for stat tiles.
- `dau-viet-mobile/lib/core/theme/` â€” `DauVietTypography`, color palette.
- `docs/GAMIFICATION_BUSINESS_RULES.md` â€” POINT-03 confirms no reward copy.

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 3h

Create `streak_detail_screen.dart`: header (current streak big number + flame), stats row (longest / days in month / last qualified), month calendar view showing study dates, friendly copy for "alive today" vs "at risk".

## Key Insights
- Calendar needs `streakCalendarProvider((firstOfMonth, lastOfMonth))` â€” autoDispose family.
- All "today" decisions use server-provided `today` field â€” NEVER `DateTime.now()` for date compare (clock skew).
- No reward copy (POINT-03): do NOT show "+50 XP tomorrow" or similar â€” streak is its own reward.
- Vietnamese copy: title "Chuá»—i NgĂ y Há»c"; subtitle variants:
  - `completedToday=true` â†’ "Tuyá»‡t vá»i! Báº¡n Ä‘Ă£ giá»¯ lá»­a hĂ´m nay."
  - `streakAlive=true && !completedToday` â†’ "HĂ£y hoĂ n thĂ nh 1 bĂ i há»c hĂ´m nay Ä‘á»ƒ giá»¯ chuá»—i!"
  - `streakAlive=false && currentStreak==0` â†’ "Báº¯t Ä‘áº§u chuá»—i má»›i â€” hoĂ n thĂ nh 1 bĂ i há»c báº¥t ká»³."
- Calendar cell states: `studied` (filled orange), `today-studied` (filled + check), `today-not-yet` (outlined), `past-missed` (grey dot), `future` (disabled).

## Requirements
- Header: large flame icon + `currentStreak` number + "ngĂ y liĂªn tiáº¿p" label.
- Stats row: `Longest streak` | `Days this month` | `Last studied` (formatted date or "â€”").
- Calendar: current month grid, day cells colored by state.
- Month nav: chevron prev/next (cap at current month forward).
- Pull-to-refresh: invalidate `streakProvider` + `streakCalendarProvider`.
- AppBar back â†’ dashboard.

## Architecture

```
StreakDetailScreen (ConsumerStatefulWidget)
  â”œâ”€â”€ monthOffset state (0 = current)
  â”œâ”€â”€ ref.watch(streakProvider) â†’ header + stats
  â”œâ”€â”€ ref.watch(streakCalendarProvider((first, last))) â†’ calendar Set<LocalDate>
  â””â”€â”€ body:
        â”œâ”€â”€ _Header (flame + number + subtitle)
        â”œâ”€â”€ _StatsRow (3 stat cells)
        â”œâ”€â”€ _MonthNav (< Oct 2026 >)
        â””â”€â”€ _CalendarGrid (7 cols Ă— N rows)
```

## Related Code Files

**Create**:
- `dau-viet-mobile/lib/features/streak/presentation/streak_detail_screen.dart` â€” main screen.
- `dau-viet-mobile/lib/features/streak/presentation/streak_calendar_widget.dart` â€” calendar grid sub-component (keep main file <200 lines per dev-rules).

**Modify**: none (dashboard tap already pushes here in phase-06).

## Implementation Steps

### Step 1 â€” Screen skeleton

```dart
class StreakDetailScreen extends ConsumerStatefulWidget {
  const StreakDetailScreen({super.key});
  @override ConsumerState<StreakDetailScreen> createState() => _State();
}

class _State extends ConsumerState<StreakDetailScreen> {
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakProvider);
    final (first, last) = _monthRange(_monthOffset);
    final calendar = ref.watch(streakCalendarProvider((first, last)));

    return Scaffold(
      appBar: AppBar(title: const Text('Chuá»—i NgĂ y Há»c')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(streakProvider);
          ref.invalidate(streakCalendarProvider((first, last)));
        },
        child: ListView(children: [
          streak.when(
            data: _header,
            loading: () => const _HeaderSkeleton(),
            error: (e, _) => _ErrorView(onRetry: () =>
                ref.read(streakProvider.notifier).refresh()),
          ),
          _StatsRow(streak: streak.valueOrNull),
          _MonthNav(offset: _monthOffset,
                    onPrev: () => setState(() => _monthOffset--),
                    onNext: _monthOffset < 0
                        ? () => setState(() => _monthOffset++) : null),
          calendar.when(
            data: (d) => StreakCalendarWidget(
                dates: d.dates.map(DateUtils.dateOnly).toSet(),
                month: first,
                today: streak.valueOrNull?.today ?? DateTime.now(),
                completedToday: streak.valueOrNull?.completedToday ?? false),
            loading: () => const _CalendarSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  (DateTime, DateTime) _monthRange(int offset) {
    final now = DateTime.now();
    final m = DateTime(now.year, now.month + offset, 1);
    final next = DateTime(m.year, m.month + 1, 1);
    return (m, next.subtract(const Duration(days: 1)));
  }
}
```

### Step 2 â€” Header + Stats sub-widgets

```dart
Widget _header(StreakStateDto s) => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(children: [
    Icon(Icons.local_fire_department_rounded,
        size: 72,
        color: s.currentStreak > 0 ? const Color(0xFFE65100) : Colors.grey),
    Text('${s.currentStreak}',
        style: DauVietTypography.displayLarge.copyWith(fontSize: 56)),
    Text('ngĂ y liĂªn tiáº¿p', style: DauVietTypography.titleMedium),
    const SizedBox(height: 8),
    Text(_subtitle(s), style: DauVietTypography.bodyMedium,
        textAlign: TextAlign.center),
  ]),
);

String _subtitle(StreakStateDto s) {
  if (s.completedToday) return 'Tuyá»‡t vá»i! Báº¡n Ä‘Ă£ giá»¯ lá»­a hĂ´m nay.';
  if (s.streakAlive) return 'HĂ£y hoĂ n thĂ nh 1 bĂ i há»c hĂ´m nay Ä‘á»ƒ giá»¯ chuá»—i!';
  return 'Báº¯t Ä‘áº§u chuá»—i má»›i â€” hoĂ n thĂ nh 1 bĂ i há»c báº¥t ká»³.';
}
```

`_StatsRow` shows `longestStreak`, `daysThisMonth` (compute from `calendar.valueOrNull?.dates.length` for current month only, hide otherwise), `lastQualifiedDate` formatted `dd/MM/yyyy`.

### Step 3 â€” `streak_calendar_widget.dart`

```dart
class StreakCalendarWidget extends StatelessWidget {
  final Set<DateTime> dates;
  final DateTime month;
  final DateTime today;
  final bool completedToday;

  // Grid: weekday header (T2..CN) + day cells.
  // For each day d in month:
  //   if dates.contains(d) â†’ filled orange (studied)
  //   if d == today && !completedToday â†’ outlined orange (today, not yet)
  //   if d.isBefore(today) â†’ grey dot (missed)
  //   else â†’ disabled future
}
```

Use `TableCalendar`-less implementation â€” simple `GridView.count(crossAxisCount: 7)` + manual day-cell mapping (offset for first-weekday of month). Avoid pulling a new dependency.

### Step 4 â€” Route registration

If using named routes (`go_router` or `MaterialApp.routes`), register `/streak`. If navigating via `Navigator.push` (phase-06 pattern), no registration needed â€” verify existing app pattern via `MaterialApp` setup.

## Todo List
- [ ] Create `streak_detail_screen.dart` (header + stats + month nav).
- [ ] Create `streak_calendar_widget.dart` (reusable calendar grid).
- [ ] Implement `_monthRange` + month offset state.
- [ ] Wire `streakCalendarProvider` family with (first, last).
- [ ] Subtitle copy branches (3 states).
- [ ] Pull-to-refresh invalidates both providers.
- [ ] `flutter analyze` clean; manual smoke shows real data.

## Success Criteria
- Detail screen renders with real streak number + calendar showing actual study dates.
- Month nav prev works, next disabled at current month.
- Pull-to-refresh updates both providers.
- Loading/error states render gracefully.

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Calendar provider refetches per offset change â€” wasteful | `autoDispose.family` keyed by range â€” caches per month, drops on pop |
| `today` from server differs from device `DateTime.now()` | Use `s.today` from `StreakStateDto` for calendar "today" marker, not device clock |
| Empty month (new user) looks broken | Show "ChÆ°a cĂ³ ngĂ y há»c nĂ o trong thĂ¡ng nĂ y" empty state |
| Long list of past months â€” perf | Cap back-nav at 12 months (`_monthOffset >= -12`) |

## Security Considerations
- Read-only; no user input beyond month nav.

## Next Steps
- Phase 08: result screen flame animation consuming `streakIncreased`.
