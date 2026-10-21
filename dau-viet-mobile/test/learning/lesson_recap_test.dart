import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_providers.dart';
import 'package:dau_viet_mobile/features/learning/presentation/lesson_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_attempt_repository.dart';

/// Recap semantics: section liệt kê evidence phải là "TƯ LIỆU TRONG BÀI HỌC"
/// (đúng bản chất — snapshot evidence, không ngụ ý learner đã khảo sát từng
/// mục); excerpt chỉ lấy từ READ content authored trong pinned snapshot.
void main() {
  FakeAttemptRepository repoWithContent(Map<String, dynamic> content) =>
      FakeAttemptRepository()
        ..content = LessonContentDto(
          lessonId: 'l',
          lessonVersionId: 'v1',
          content: content,
        )
        ..result = const LessonResultDto(
          attemptId: 'a-1',
          lessonVersionId: 'v1',
          status: 'COMPLETED',
          score: 90,
          result: {'summary': 'Tốt'},
        );

  Future<void> pump(WidgetTester tester, FakeAttemptRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attemptRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: LessonResultScreen(
            attemptId: 'a-1',
            initialResult: LessonResultDto(
              attemptId: 'a-1',
              lessonVersionId: 'v1',
              status: 'COMPLETED',
              score: 90,
              result: {'summary': 'Tốt'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('evidence section nhãn "TƯ LIỆU TRONG BÀI HỌC"', (tester) async {
    final repo = repoWithContent({
      'title': 'Bài học thử',
      'evidence': [
        {'id': 'e1', 'title': 'Sử ký', 'source': 'ĐVSKTT'},
        {'id': 'e2', 'title': 'Bi ký', 'source': 'Văn bia'},
      ],
    });
    await pump(tester, repo);
    expect(find.text('TƯ LIỆU TRONG BÀI HỌC'), findsOneWidget);
    expect(find.text('BẰNG CHỨNG ĐÃ KHẢO SÁT'), findsNothing);
    expect(find.textContaining('Sử ký'), findsOneWidget);
  });

  testWidgets('READ content → trích đoạn hiển thị trong recap', (tester) async {
    final repo = repoWithContent({
      'title': 'Bài học có đọc',
      'stages': [
        {
          'id': 's1',
          'title': 'Bối cảnh',
          'activities': [
            {
              'id': 'a1',
              'type': 'READ',
              'config': {
                'body':
                    'Năm 938, quân Nam Hán kéo thủy quân vào Bạch Đằng. '
                    'Ngô Quyền dùng cọc ngầm mai phục.',
              },
            },
          ],
        },
      ],
    });
    await pump(tester, repo);
    expect(find.textContaining('Năm 938, quân Nam Hán'), findsOneWidget);
  });

  testWidgets('không có content đáng kể → chỉ result-only, không crash', (
    tester,
  ) async {
    final repo = repoWithContent(const {}); // content trống
    await pump(tester, repo);
    expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
    expect(find.text('ÔN LẠI BÀI HỌC'), findsNothing);
  });

  testWidgets('getAttemptContent throw → fallback result-only', (tester) async {
    final repo = repoWithContent(const {'title': 'Không bao giờ load được'})
      ..throwOnGetContent = true;
    await pump(tester, repo);
    expect(find.text('HOÀN THÀNH BÀI HỌC'), findsOneWidget);
    expect(find.text('ÔN LẠI BÀI HỌC'), findsNothing);
  });
}
