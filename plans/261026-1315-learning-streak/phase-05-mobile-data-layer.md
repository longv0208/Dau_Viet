# Phase 05 â€” Mobile Data Layer (DTO + Repo + Providers)

## Context Links
- `dau-viet-mobile/lib/features/energy/data/energy_dto.dart` â€” `serverTime`/monotonic-clock pattern (less critical for streak â€” no countdown, but `serverTime` still useful for `today` consistency).
- `dau-viet-mobile/lib/features/energy/data/energy_providers.dart` â€” `AsyncNotifierProvider` + session-key + `applySnapshot` template.
- `dau-viet-mobile/lib/features/energy/data/energy_api_client.dart` â€” thin `ApiClient` wrapper.
- `dau-viet-mobile/lib/features/energy/data/{energy_repository,api_energy_repository,mock_energy_repository}.dart` â€” abstraction + Api/Mock split.
- `dau-viet-mobile/lib/features/learning/data/attempt_dtos.dart` â€” `CompleteResultDto` needs additive `streakIncreased`/`newStreak`/etc fields (phase-03 backend ships them).

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 2h

Mirror `energy` feature structure for `streak`: DTO + repo (Api/Mock) + Riverpod provider + api client. Also extend `CompleteResultDto` and `LessonResultDto` to parse the additive streak fields the backend now ships.

## Key Insights
- No countdown â†’ simpler than `EnergyStateDto`. Still keep `serverTime` field so `today`/`completedToday` are server-derived (NOT `DateTime.now()`).
- Provider exposes `applySnapshot` so the result screen can push the post-complete streak state in without an extra round-trip (phase-08 uses it for flame animation).
- Session key mirrors `energy_providers` â€” switch user â†’ rebuild notifier, no leak.
- `CompleteResultDto` additive fields default to safe values (`false`/`0`) so older backends still work.

## Requirements
- `StreakStateDto {currentStreak, longestStreak, completedToday, lastQualifiedDate, today, timezone, serverTime, streakAlive}` â€” `fromJson` null-safe.
- `StreakCalendarDto {dates: List<DateTime>}` â€” for detail screen.
- `StreakRepository` abstract: `getMyStreak()`, `getCalendar(from, to)`.
- `ApiStreakRepository` calls `GET /api/v1/me/streak` + `/calendar`.
- `MockStreakRepository` returns fixed data for `USE_MOCK`.
- `streakProvider` AsyncNotifier: `build()` fetches, `applySnapshot`, `refresh`.
- `CompleteResultDto` + `LessonResultDto` extended with `streakIncreased`, `newStreak`, `previousStreak`, `completedToday`, `studyDate` (all optional/nullable â€” backward compat).
- `LessonResultDto` for `/attempts/{id}/result` may not include streak (server may only add to `CompleteAttemptResponse`); document fallback = fetch `/me/streak` after complete if needed.

## Architecture

```
lib/features/streak/
  â”œâ”€â”€ data/
  â”‚   â”œâ”€â”€ streak_dto.dart               (StreakStateDto, StreakCalendarDto)
  â”‚   â”œâ”€â”€ streak_api_client.dart        (thin wrapper)
  â”‚   â”œâ”€â”€ streak_repository.dart        (abstract)
  â”‚   â”œâ”€â”€ api_streak_repository.dart
  â”‚   â”œâ”€â”€ mock_streak_repository.dart
  â”‚   â””â”€â”€ streak_providers.dart         (streakProvider, repo providers)
  â””â”€â”€ presentation/
      â”œâ”€â”€ streak_badge_widget.dart       (phase-06 uses)
      â””â”€â”€ streak_detail_screen.dart      (phase-07)

lib/features/learning/data/attempt_dtos.dart   (extend CompleteResultDto + LessonResultDto)
```

## Related Code Files

**Create**:
- `dau-viet-mobile/lib/features/streak/data/streak_dto.dart`
- `dau-viet-mobile/lib/features/streak/data/streak_api_client.dart`
- `dau-viet-mobile/lib/features/streak/data/streak_repository.dart`
- `dau-viet-mobile/lib/features/streak/data/api_streak_repository.dart`
- `dau-viet-mobile/lib/features/streak/data/mock_streak_repository.dart`
- `dau-viet-mobile/lib/features/streak/data/streak_providers.dart`

**Modify**:
- `dau-viet-mobile/lib/features/learning/data/attempt_dtos.dart` â€” extend `CompleteResultDto` + `LessonResultDto`.

## Implementation Steps

### Step 1 â€” `streak_dto.dart`

```dart
/// DTO tráº¡ng thĂ¡i streak (LEARNING-STREAK) â€” khá»›p StreakStateResponse.
/// Server lĂ  nguá»“n duy nháº¥t: `today`/`completedToday`/`streakAlive` Ä‘á»u Ä‘Ă£
/// Ä‘Æ°á»£c backend resolve theo timezone VN â€” client KHĂ”NG suy láº¡i báº±ng DateTime.now().
class StreakStateDto {
  final int currentStreak;
  final int longestStreak;
  final bool completedToday;
  final DateTime? lastQualifiedDate; // civil date VN â€” parse from "YYYY-MM-DD"
  final DateTime today;
  final String timezone;
  final DateTime? serverTime;
  final bool streakAlive;

  const StreakStateDto({
    required this.currentStreak,
    required this.longestStreak,
    required this.completedToday,
    this.lastQualifiedDate,
    required this.today,
    required this.timezone,
    this.serverTime,
    required this.streakAlive,
  });

  factory StreakStateDto.fromJson(Map<String, dynamic> json) =>
      StreakStateDto(
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
        completedToday: json['completedToday'] as bool? ?? false,
        lastQualifiedDate: _parseDate(json['lastQualifiedDate']),
        today: _parseDate(json['today']) ?? DateTime.now().toUtc(),
        timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
        serverTime: _parseInstant(json['serverTime']),
        streakAlive: json['streakAlive'] as bool? ?? false,
      );

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
  static DateTime? _parseInstant(Object? raw) => _parseDate(raw);

  static const empty = StreakStateDto(
    currentStreak: 0, longestStreak: 0,
    completedToday: false, today: DateTime.fromMillisecondsSinceEpoch(0),
    timezone: 'Asia/Ho_Chi_Minh', streakAlive: false,
  );
}

class StreakCalendarDto {
  final List<DateTime> dates;
  const StreakCalendarDto(this.dates);
  factory StreakCalendarDto.fromJson(Map<String, dynamic> json) =>
      StreakCalendarDto((json['dates'] as List? ?? const [])
          .whereType<String>()
          .map(DateTime.parse)
          .toList());
}
```

### Step 2 â€” `streak_api_client.dart`

```dart
class StreakApiClient {
  final ApiClient _client;
  const StreakApiClient(this._client);

  Future<StreakStateDto> getMyStreak() async =>
      StreakStateDto.fromJson(await _client.get('/api/v1/me/streak'));

  Future<StreakCalendarDto> getCalendar(
      {required DateTime from, required DateTime to}) async {
    final String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final json = await _client.get(
        '/api/v1/me/streak/calendar?from=${fmt(from)}&to=${fmt(to)}');
    return StreakCalendarDto.fromJson(json);
  }
}
```

### Step 3 â€” Repo trio

```dart
abstract class StreakRepository {
  Future<StreakStateDto> getMyStreak();
  Future<StreakCalendarDto> getCalendar({required DateTime from, required DateTime to});
}

class ApiStreakRepository implements StreakRepository {
  final StreakApiClient _client;
  ApiStreakRepository(this._client);
  @override getMyStreak() => _client.getMyStreak();
  @override getCalendar({required from, required to}) =>
      _client.getCalendar(from: from, to: to);
}

class MockStreakRepository implements StreakRepository {
  @override Future<StreakStateDto> getMyStreak() async => StreakStateDto(
      currentStreak: 7, longestStreak: 12, completedToday: true,
      lastQualifiedDate: DateTime.now(), today: DateTime.now(),
      timezone: 'Asia/Ho_Chi_Minh', streakAlive: true);
  @override Future<StreakCalendarDto> getCalendar({required from, required to}) async =>
      StreakCalendarDto(List.generate(7, (i) => DateTime.now().subtract(Duration(days: i))));
}
```

### Step 4 â€” `streak_providers.dart`

Mirror `energy_providers.dart` structure (session key, `_noRetry`, `applySnapshot`, `refresh`):

```dart
final streakApiClientProvider = Provider<StreakApiClient>(
  (ref) => StreakApiClient(ref.watch(apiClientProvider)),
);

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  if (ApiConfig.useMock) return MockStreakRepository();
  return ApiStreakRepository(ref.watch(streakApiClientProvider));
});

String _streakSessionKey(AuthState auth) { /* same as _energySessionKey */ }
Duration? _noRetry(int r, Object e) => null;

final streakProvider = AsyncNotifierProvider<StreakController, StreakStateDto>(
  StreakController.new, retry: _noRetry,
);

class StreakController extends AsyncNotifier<StreakStateDto> {
  String _sessionKey = '';
  @override Future<StreakStateDto> build() async {
    _sessionKey = _streakSessionKey(ref.watch(authSessionProvider));
    final repo = ref.watch(streakRepositoryProvider);
    if (ApiConfig.useMock) return repo.getMyStreak();
    return ref.read(authRepositoryProvider).withAuth(repo.getMyStreak);
  }
  void applySnapshot(StreakStateDto dto) { /* same pattern as energy */ }
  Future<void> refresh() async { /* invalidateSelf + await future */ }
}

/// Calendar: plain FutureProvider keyed by (from, to) â€” refetch on invalidate.
final streakCalendarProvider = FutureProvider.autoDispose
    .family<StreakCalendarDto, (DateTime, DateTime)>((ref, range) async {
  final repo = ref.watch(streakRepositoryProvider);
  if (ApiConfig.useMock) return repo.getCalendar(from: range.$1, to: range.$2);
  return ref.read(authRepositoryProvider)
      .withAuth(() => repo.getCalendar(from: range.$1, to: range.$2));
});
```

### Step 5 â€” Extend `CompleteResultDto` + `LessonResultDto`

```dart
class CompleteResultDto {
  // ... existing fields ...
  /// LEARNING-STREAK additive (server V1+): false/0/null khi replay hoáº·c
  /// backend cÅ© â€” client check `streakIncreased==true` má»›i cháº¡y flame anim.
  final bool streakIncreased;
  final int newStreak;
  final int previousStreak;
  final bool? completedToday;
  final String? studyDate;

  const CompleteResultDto({
    // ... existing ...
    this.streakIncreased = false,
    this.newStreak = 0,
    this.previousStreak = 0,
    this.completedToday,
    this.studyDate,
  });

  factory CompleteResultDto.fromJson(Map<String, dynamic> json) =>
      CompleteResultDto(
        // ... existing ...
        streakIncreased: json['streakIncreased'] as bool? ?? false,
        newStreak: (json['newStreak'] as num?)?.toInt() ?? 0,
        previousStreak: (json['previousStreak'] as num?)?.toInt() ?? 0,
        completedToday: json['completedToday'] as bool?,
        studyDate: json['studyDate'] as String?,
      );
}
```

Same 5 fields added to `LessonResultDto` (for `/attempts/{id}/result` path â€” if backend only ships them on complete response, keep `LessonResultDto` defaults so deep-link works without re-animating).

## Todo List
- [ ] Create `lib/features/streak/` directory + `data/` subdir.
- [ ] Write `streak_dto.dart` (StreakStateDto + StreakCalendarDto).
- [ ] Write `streak_api_client.dart`.
- [ ] Write `streak_repository.dart`, `api_streak_repository.dart`, `mock_streak_repository.dart`.
- [ ] Write `streak_providers.dart` (streakProvider + streakCalendarProvider).
- [ ] Extend `CompleteResultDto` with 5 streak fields.
- [ ] Extend `LessonResultDto` (same fields, default empty).
- [ ] `flutter analyze` clean.
- [ ] `flutter test` passes (no new tests yet â€” phase-08 adds widget tests).

## Success Criteria
- `flutter analyze` returns 0 issues in new files.
- `ref.watch(streakProvider)` returns `StreakStateDto` on auth user (verify by print/snackbar in dev).
- Mock mode returns fixed data without HTTP.
- DTO parse handles missing fields (older backend) without throwing.

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| `DateTime.parse` on date-only string interprets as UTC local-midnight | Use `DateTime.parse("YYYY-MM-DD")` â€” Dart treats as local-midnight; `today` comparisons in UI only need day granularity, not instants. |
| Backend ships `studyDate` field but mobile uses `today` from server | OK â€” `studyDate` is "the day just recorded", `today` is "current VN day"; both useful, both surfaced. |
| Provider rebuilds too often on auth state changes | Session key â€” same pattern as energy, proven in prod. |
| `applySnapshot` timing â€” push post-complete before build | `_sessionKey.isEmpty` fallback (energy already handles). |

## Security Considerations
- JWT auto-attached by `ApiClient` â€” no manual token plumbing.
- No client-supplied dates sent to server (only calendar `from`/`to` for read).

## Next Steps
- Phase 06: dashboard pill wires `streakProvider` into existing header.
