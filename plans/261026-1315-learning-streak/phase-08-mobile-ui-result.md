# Phase 08 â€” Mobile UI: Lesson Result Streak Animation

## Context Links
- `dau-viet-mobile/lib/features/learning/presentation/lesson_result_screen.dart` â€” `_ResultView` has `_popupShown` anti-replay pattern for `UnlockCelebrationDialog`; reuse pattern for streak animation.
- `dau-viet-mobile/lib/features/learning/data/attempt_dtos.dart` â€” `CompleteResultDto` extended in phase-05 with `streakIncreased`/`newStreak`/`previousStreak`.
- `dau-viet-mobile/lib/features/streak/data/streak_providers.dart` â€” `streakProvider.applySnapshot` for instant badge refresh.

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 1h

When `CompleteResultDto.streakIncreased == true`, animate the flame badge on the result screen from `previousStreak` â†’ `newStreak` (Nâ†’N+1 pop/count-up), AND push a `StreakStateDto` snapshot into `streakProvider` so the dashboard pill updates without refetch.

## Key Insights
- **Anti-replay**: same `_popupShown` pattern as `UnlockCelebrationDialog` â€” animate once on `_ResultView.initState`/`addPostFrameCallback`, never on rebuild.
- **Snapshot push**: backend's `CompleteAttemptResponse` gives us `newStreak`, `previousStreak`, `completedToday`, `studyDate`. We don't get `longestStreak`/`lastQualifiedDate`/`today`/`streakAlive` on the wire â€” synthesize a minimal `StreakStateDto` for `applySnapshot` OR just call `refresh()` post-complete. **Decision**: call `streakProvider.refresh()` after result screen mounts â€” simpler than fabricating fields, single source of truth stays server-side. (Alternative rejected: constructing `StreakStateDto` locally requires `today`/`timezone` we don't have on the wire â†’ risk of inconsistency.)
- **Animation scope**: Nâ†’N+1 count-up on flame â€” NOT confetti fireworks; subtle 400-600ms scale+count, in line with app's animation budget.
- **No animation on `alreadyCompleted=true` or `streakIncreased=false`** â€” replay path silent.

## Requirements
- Trigger ONLY when `widget.completeResult.streakIncreased == true`.
- Show flame icon + number transitioning from `previousStreak` to `newStreak` over ~500ms with a slight scale pulse.
- After result screen mounts (post-frame), call `ref.read(streakProvider.notifier).refresh()` so subsequent visits see fresh state.
- Anti-replay: `_streakAnimShown` flag â€” do not re-animate on rebuild or rotation.
- Skip animation entirely if `newStreak == previousStreak` (defensive) or `streakIncreased == false`.

## Architecture

```
ResultScreen
  â””â”€ _ResultView (StatefulWidget)
       â”œâ”€ initState:
       â”‚    if (widget.result.streakIncreased) {
       â”‚      addPostFrameCallback:
       â”‚        if (!_streakAnimShown) { _playStreakAnim(); _streakAnimShown = true; }
       â”‚      ref.read(streakProvider.notifier).refresh();
       â”‚    }
       â””â”€ _ResultBody: badges row adds _StreakFlameBadge(previousStreakâ†’newStreak, animate: streakIncreased)
```

## Related Code Files

**Create**:
- `dau-viet-mobile/lib/features/streak/presentation/streak_flame_increase_badge.dart` â€” `StatefulWidget` with `AnimationController` doing count-up `prev â†’ new` + scale pulse.

**Modify**:
- `dau-viet-mobile/lib/features/learning/presentation/lesson_result_screen.dart` â€” inject `_StreakFlameBadge` in result badges row; add `_streakAnimShown` flag; add post-frame `refresh()` call.

**Delete**: none.

## Implementation Steps

### Step 1 â€” `streak_flame_increase_badge.dart`

```dart
/// Flame badge trĂªn mĂ n káº¿t quáº£ â€” count-up prev â†’ new khi streakIncreased.
/// Má»™t láº§n duy nháº¥t trong lifecycle widget; KHĂ”NG re-animate khi rebuild.
class StreakFlameIncreaseBadge extends StatefulWidget {
  final int previousStreak;
  final int newStreak;
  const StreakFlameIncreaseBadge({super.key,
      required this.previousStreak, required this.newStreak});

  @override State<StreakFlameIncreaseBadge> createState() => _State();
}

class _State extends State<StreakFlameIncreaseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  late final Animation<int> _count = IntTween(
      begin: widget.previousStreak, end: widget.newStreak)
    .animate(CurvedAnimation(parent: _c,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Transform.scale(
      scale: _scale.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 4),
          Text('${_count.value}',
              style: DauVietTypography.titleLarge.copyWith(
                  color: const Color(0xFFE65100), fontWeight: FontWeight.w900)),
        ]),
      ),
    ),
  );
}
```

### Step 2 â€” Wire into `lesson_result_screen.dart`

In `_ResultView.initState` (or the place `_popupShown` flag is used for `UnlockCelebrationDialog`):

```dart
// LEARNING-STREAK: Ä‘áº©y streak má»›i vĂ o provider + chuáº©n bá»‹ anim 1 láº§n.
if (widget.completeResult.streakIncreased) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_streakAnimShown && mounted) {
      setState(() => _streakAnimShown = true);
      // refresh dashboard badge â€” khĂ´ng cáº§n chá» animation.
      ref.read(streakProvider.notifier).refresh();
    }
  });
}
```

In `_ResultBody` badges row (next to `+50 XP` / `+1 NÄƒng lÆ°á»£ng` badges â€” or replace them if user request asks for streak badge as the prominent one):

```dart
if (widget.completeResult.streakIncreased)
  StreakFlameIncreaseBadge(
      previousStreak: widget.completeResult.previousStreak,
      newStreak: widget.completeResult.newStreak),
```

Wrap in a conditional that only mounts the animated badge when `streakIncreased`; otherwise show static `DailyStreakBadgeWidget` reading current provider state.

### Step 3 â€” Hardcoded badges cleanup (opportunistic)
- The '+50 XP' / '+1 NÄƒng lÆ°á»£ng' badges in `_ResultBody` are hardcoded (per summary). If trivial, swap to read from `rewards`/`itemsUnlocked` already on `LessonResultDto` â€” but this may be out-of-scope; flag in cleanup phase (phase-10) rather than expand scope here.

## Todo List
- [ ] Create `streak_flame_increase_badge.dart` (count-up + scale, 600ms).
- [ ] Add `_streakAnimShown` flag to `_ResultView`.
- [ ] Wire `initState` post-frame: set flag + `streakProvider.refresh()`.
- [ ] Add conditional `StreakFlameIncreaseBadge` to `_ResultBody` badges row.
- [ ] Manual smoke: complete a lesson â†’ flame animates 0â†’1, dashboard pill = 1.
- [ ] Manual smoke: same lesson complete-replay (idempotent) â†’ no re-anim.
- [ ] `flutter analyze` clean.

## Success Criteria
- First completion of the day â†’ animates `prevâ†’new`.
- Second+ completion same day â†’ `streakIncreased=false` â†’ NO anim, NO toast.
- Replay (alreadyCompleted) â†’ NO anim.
- Dashboard pill = `newStreak` after result screen mounts.

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| `refresh()` races with anim (pill shows stale until refresh lands) | Acceptable â€” anim is local; refresh updates provider in background |
| Screen rotated mid-anim â†’ restart | `AnimationController..forward()` re-runs on rebuild â€” acceptable; alternative: persist `_streakAnimShown` via `AutomaticKeepAliveClientMixin` if flaky |
| Backend ships `streakIncreased=true` but new==prev (defensive) | Guard `if (newStreak <= previousStreak)` â†’ skip anim, log |
| Result screen deep-linked (no complete result) | `LessonResultDto` fields default false â†’ no anim (correct) |

## Security Considerations
- None â€” pure UI.

## Next Steps
- Phase 09: profile stats + lesson_player fix.
