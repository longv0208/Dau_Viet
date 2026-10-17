import 'package:dau_viet_mobile/core/api/api_error.dart';
import 'package:dau_viet_mobile/core/api/api_exception.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_list_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_attempt_repository.dart';

void main() {
  Widget buildApp(FakeAttemptRepository repo, {String eventId = 'evt-1'}) {
    return ProviderScope(
      overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(body: LessonListSection(eventId: eventId)),
      ),
    );
  }

  group('LessonListSection', () {
    testWidgets('có bài học → render card title + central question', (
      tester,
    ) async {
      final repo = FakeAttemptRepository()
        ..lessons = const [
          LessonListItemDto(
            id: 'l-1',
            title: 'Bí mật chiến thắng Bạch Đằng',
            centralQuestion: 'Vì sao cọc ngầm thắng được thủy quân Nam Hán?',
          ),
          LessonListItemDto(id: 'l-2', title: 'Bài học phụ'),
        ];
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('BÀI HỌC LỊCH SỬ'), findsOneWidget);
      expect(find.text('Bí mật chiến thắng Bạch Đằng'), findsOneWidget);
      expect(
        find.text('Vì sao cọc ngầm thắng được thủy quân Nam Hán?'),
        findsOneWidget,
      );
      expect(find.text('Bài học phụ'), findsOneWidget);
    });

    testWidgets(
      'danh sách rỗng → empty state "Chưa có bài học được xuất bản"',
      (tester) async {
        final repo = FakeAttemptRepository()..lessons = const [];
        await tester.pumpWidget(buildApp(repo));
        await tester.pumpAndSettle();

        expect(find.text('Chưa có bài học được xuất bản'), findsOneWidget);
        // Không hiện card nào, không crash.
        expect(find.byType(InkWell), findsNothing);
      },
    );

    testWidgets('API lỗi → thông báo + nút Thử lại (không fallback mock)', (
      tester,
    ) async {
      var calls = 0;
      var fail = true;
      // Repo trả lỗi lần đầu, thành công sau retry.
      final repo = _FlakyLessonsRepo(() {
        calls++;
        if (fail) {
          throw const ApiException(
            ApiError(code: 'NETWORK_ERROR', message: 'down'),
          );
        }
        return const [
          LessonListItemDto(id: 'l-1', title: 'Bài học đã tải lại'),
        ];
      });
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      expect(find.text('Không tải được danh sách bài học.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      fail = false;
      calls = 0;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(calls, 1); // invalidate gọi lại đúng 1 lần, không retry ngầm.
      expect(find.text('Bài học đã tải lại'), findsOneWidget);
    });
  });
}

/// Repo trả lessons theo closure — kiểm soát fail/success theo lần gọi.
class _FlakyLessonsRepo extends FakeAttemptRepository {
  final List<LessonListItemDto> Function() _handler;

  _FlakyLessonsRepo(this._handler);

  @override
  Future<List<LessonListItemDto>> listLessonsForEvent(String eventId) async =>
      _handler();
}
