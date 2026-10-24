import 'dart:async';

import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_repository.dart';
import 'package:dau_viet_mobile/features/auth/data/auth_state.dart';
import 'package:dau_viet_mobile/features/campaign/presentation/widgets/event_progress_section.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_providers.dart';
import 'package:dau_viet_mobile/features/collection/data/collection_repository.dart';
import 'package:dau_viet_mobile/features/collection/data/event_progress_dto.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget test cho EventProgressSection (FIX 8 + FIX 7):
///  - loading → placeholder "Đang tải…" (không SizedBox.shrink);
///  - error → thông báo + THỬ LẠI; retry invalidate provider và refetch;
///  - NOT_CONFIGURED → info trung lập;
///  - earnedPolicyVersion < policyVersion → banner "phiên bản trước";
///  - earnedPolicyVersion == null hoặc == policyVersion → không banner.
/// Repo tối thiểu — chỉ eventProgress được dùng trong test này.
class Repo implements CollectionRepository {
  Object? error;
  EventProgressDto value;
  int calls = 0;

  /// Khi non-null, eventProgress chờ Completer này — test kiểm soát timing
  /// (không pending timer ảo).
  Completer<EventProgressDto>? gate;

  Repo(this.value);

  @override
  Future<EventProgressDto> eventProgress(String id) {
    calls++;
    if (gate != null) return gate!.future;
    if (error != null) return Future.error(error!);
    return Future.value(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements AuthRepository {
  @override
  Future<T> withAuth<T>(Future<T> Function() action) => action();

  @override
  Future<AuthState> restore() async => const AuthState.unauthenticated();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Session cố định — provider key không đổi giữa các build trong test.
class _FixedAuthSession extends AuthSessionController {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

void main() {
  const eventId = 'evt-1';

  EventProgressDto progress({
    String status = 'EVENT_COMPLETED',
    int? policyVersion,
    int? earnedPolicyVersion,
    int requiredTotal = 2,
    int requiredDone = 2,
    bool eventCompleted = true,
    bool eventMastered = false,
    int unlockedCount = 1,
  }) => EventProgressDto(
    eventId: eventId,
    status: status,
    policyVersion: policyVersion,
    requiredLessonsTotal: requiredTotal,
    requiredLessonsCompleted: requiredDone,
    eventCompleted: eventCompleted,
    eventMastered: eventMastered,
    requiredLessons: const [],
    unlockedDossiersCount: unlockedCount,
    earnedPolicyVersion: earnedPolicyVersion,
  );

  Widget buildApp(Repo repo) => ProviderScope(
    overrides: [
      collectionRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(FakeAuth()),
      authSessionProvider.overrideWith(() => _FixedAuthSession()),
    ],
    child: const MaterialApp(
      home: Scaffold(body: EventProgressSection(eventId: eventId)),
    ),
  );

  testWidgets('loading → placeholder có spinner, không shrink', (tester) async {
    // Gate không complete → provider ở loading; không dùng timer ảo nên
    // pumpAndSettle/pump thoải mái mà không lỗi timersPending.
    final gate = Completer<EventProgressDto>();
    final repo = Repo(progress())..gate = gate;
    await tester.pumpWidget(buildApp(repo));
    await tester.pump(); // một frame — provider còn pending

    expect(find.text('Đang tải tiến độ sự kiện…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Gate không bao giờ resolve — teardown để nguyên (không pending timer).
  });

  testWidgets('error → thông báo + THỬ LẠI; retry refetch thành công', (
    tester,
  ) async {
    final repo = Repo(progress())
      ..error = const ApiException(
        ApiError(code: 'NETWORK_ERROR', message: 'down'),
      );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Không tải được tiến độ'), findsOneWidget);
    expect(find.text('THỬ LẠI'), findsOneWidget);
    expect(repo.calls, 1);

    // Hết lỗi → retry → data state.
    repo.error = null;
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text('ĐÃ HOÀN THÀNH SỰ KIỆN'), findsOneWidget);
  });

  testWidgets('NOT_CONFIGURED → info trung lập, không crash', (tester) async {
    final repo = Repo(
      progress(
        status: 'NOT_CONFIGURED',
        requiredTotal: 0,
        requiredDone: 0,
        eventCompleted: false,
        unlockedCount: 0,
      ),
    );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('chưa có mục tiêu'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'earnedPolicyVersion < policyVersion → banner "phiên bản trước"',
    (tester) async {
      final repo = Repo(progress(policyVersion: 2, earnedPolicyVersion: 1));
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('phiên bản trước'), findsOneWidget);
    },
  );

  testWidgets('earnedPolicyVersion == policyVersion → không banner', (
    tester,
  ) async {
    final repo = Repo(progress(policyVersion: 2, earnedPolicyVersion: 2));
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('phiên bản trước'), findsNothing);
    expect(find.text('ĐÃ HOÀN THÀNH SỰ KIỆN'), findsOneWidget);
  });

  testWidgets('earnedPolicyVersion null → không banner (an toàn legacy)', (
    tester,
  ) async {
    final repo = Repo(progress(policyVersion: 1));
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('phiên bản trước'), findsNothing);
  });
}
