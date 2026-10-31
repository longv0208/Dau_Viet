import 'package:dau_viet_mobile/features/learning/data/attempt_dtos.dart';
import 'package:dau_viet_mobile/features/learning/data/learning_dtos.dart';
import 'package:dau_viet_mobile/features/learning/presentation/renderers/evidence_select_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleContent = LessonContentDto(
  lessonId: 'les-1',
  lessonVersionId: 'ver-1',
  content: {
    'evidence': [
      {
        'id': 'ev-1',
        'title': 'Cọc gỗ lim vạt nhọn bịt sắt',
        'type': 'Hiện vật',
        'description': 'Cọc gỗ lim cắm ngầm dưới lòng sông Bạch Đằng.',
        'source': {'title': 'Bảo tàng Lịch sử Quốc gia', 'author': 'Khảo cổ'},
        'body': 'Chi tiết khảo cổ bãi cọc Yên Giang tại Quảng Ninh.',
      },
      {
        'id': 'ev-2',
        'title': 'Quy luật thủy triều bán nhật',
        'type': 'Địa hình',
        'description': 'Nước dâng cao buổi sáng và rút nhanh buổi chiều.',
        'source': 'Địa chí vùng cửa biển Đông Bắc',
      },
      {
        'id': 'ev-3',
        'title': 'Tư liệu nhiễu không liên quan',
        'type': 'Cổ thư',
        'description': 'Ghi chép về một sự kiện ở triều đại khác.',
        'source': 'Sử liệu đối chứng',
      },
    ],
  },
);

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  group('EvidenceSelectRenderer — Issue #43 UX & Mechanism', () {
    testWidgets(
      '1. COLLECT mode (graded:false): eyebrow hiện CHỌN ÍT NHẤT minRequired, subtitle không đe Thể lực',
      (tester) async {
        final activity = ActivityRefDto.fromJson(const {
          'id': 'es-collect',
          'type': 'EVIDENCE_SELECT',
          'graded': false,
          'config': {
            'graded': false,
            'visibleEvidenceIds': ['ev-1', 'ev-2', 'ev-3'],
            'minRequired': 2,
          },
        });

        await tester.pumpWidget(
          _wrap(
            EvidenceSelectRenderer(
              activity: activity,
              content: _sampleContent,
              submitting: false,
              onSubmit: (_) async {},
            ),
          ),
        );

        expect(
          find.text('THU THẬP DẤU VẾT · CHỌN ÍT NHẤT 2'),
          findsOneWidget,
        );
        expect(
          find.textContaining('không mất Thể lực'),
          findsOneWidget,
        );
        expect(find.textContaining('Sai mất'), findsNothing);
      },
    );

    testWidgets(
      '2. ASSESS mode (graded:true): eyebrow không chứa con số mâu thuẫn, subtitle hiện chi phí Thể lực và số lượt',
      (tester) async {
        final activity = ActivityRefDto.fromJson(const {
          'id': 'es-assess',
          'type': 'EVIDENCE_SELECT',
          'graded': true,
          'incorrectPenalty': 10,
          'config': {
            'graded': true,
            'visibleEvidenceIds': ['ev-1', 'ev-2', 'ev-3'],
            'minRequired': 2,
            'maxAttempts': 3,
            'remedialAttempts': 1,
          },
        });

        await tester.pumpWidget(
          _wrap(
            EvidenceSelectRenderer(
              activity: activity,
              content: _sampleContent,
              submitting: false,
              onSubmit: (_) async {},
            ),
          ),
        );

        expect(
          find.text('THU THẬP DẤU VẾT · CHỌN ĐÚNG CÁC DẤU VẾT LIÊN QUAN'),
          findsOneWidget,
        );
        expect(
          find.text('THU THẬP DẤU VẾT · CHỌN ÍT NHẤT 2'),
          findsNothing,
        );
        expect(
          find.textContaining('Sai mất 10 Thể lực · còn 3/3 lượt + 1 sửa'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '3. Tách vùng chạm: chạm vào thân thẻ mở bottom sheet chi tiết và KHÔNG tự chọn thẻ',
      (tester) async {
        final activity = ActivityRefDto.fromJson(const {
          'id': 'es-tap',
          'type': 'EVIDENCE_SELECT',
          'config': {
            'visibleEvidenceIds': ['ev-1', 'ev-2'],
            'minRequired': 1,
          },
        });

        await tester.pumpWidget(
          _wrap(
            EvidenceSelectRenderer(
              activity: activity,
              content: _sampleContent,
              submitting: false,
              onSubmit: (_) async {},
            ),
          ),
        );

        expect(find.text('Đã chọn 0/1'), findsOneWidget);

        // Chạm vào tiêu đề trên thân thẻ -> mở bottom sheet chi tiết, không chọn
        await tester.tap(find.text('Cọc gỗ lim vạt nhọn bịt sắt'));
        await tester.pumpAndSettle();

        expect(
          find.text('Chi tiết khảo cổ bãi cọc Yên Giang tại Quảng Ninh.'),
          findsOneWidget,
        );
        expect(find.text('CHỌN BẰNG CHỨNG NÀY'), findsOneWidget);
        expect(find.text('Đã chọn 0/1'), findsOneWidget);

        // Đóng sheet mà không bấm chọn -> vẫn 0/1
        Navigator.of(tester.element(find.text('CHỌN BẰNG CHỨNG NÀY'))).pop();
        await tester.pumpAndSettle();
        expect(find.text('Đã chọn 0/1'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Chạm nút Chọn toggle chọn/bỏ chọn và hiện cảnh báo khi chạm vượt maxSelect',
      (tester) async {
        Map<String, dynamic>? submitted;
        final activity = ActivityRefDto.fromJson(const {
          'id': 'es-select',
          'type': 'EVIDENCE_SELECT',
          'config': {
            'visibleEvidenceIds': ['ev-1', 'ev-2', 'ev-3'],
            'minRequired': 2,
            'maxSelect': 2,
          },
        });

        await tester.pumpWidget(
          _wrap(
            EvidenceSelectRenderer(
              activity: activity,
              content: _sampleContent,
              submitting: false,
              onSubmit: (ans) async => submitted = ans,
            ),
          ),
        );

        // Chọn ev-1 và ev-2 qua nút Chọn
        await tester.tap(
          find.byKey(const ValueKey('evidence-select-btn-ev-1')),
        );
        await tester.pump();
        expect(find.text('Đã chọn 1/2'), findsOneWidget);
        expect(find.text('Đọc đầy đủ'), findsWidgets);

        await tester.tap(
          find.byKey(const ValueKey('evidence-select-btn-ev-2')),
        );
        await tester.pump();
        expect(find.text('Đã chọn 2/2'), findsOneWidget);

        // Cố chọn thêm ev-3 khi đã đạt maxSelect=2 -> hiện cảnh báo giới hạn
        await tester.tap(
          find.byKey(const ValueKey('evidence-select-btn-ev-3')),
        );
        await tester.pump();
        expect(
          find.textContaining('Đã đạt giới hạn 2 dấu vết'),
          findsOneWidget,
        );
        expect(find.text('Đã chọn 2/2'), findsOneWidget);
        await tester.ensureVisible(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('GỬI CÂU TRẢ LỜI'));
        await tester.pump();
        expect(submitted?['selectedEvidenceIds'], ['ev-1', 'ev-2']);
      },
    );

    testWidgets(
      '5. Sau khi submit PARTIAL: hiển thị verdict đúng/sai trên thẻ đã chọn (không lộ thẻ chưa chọn) và InlineGradingHint',
      (tester) async {
        final activity = ActivityRefDto.fromJson(const {
          'id': 'es-verdict',
          'type': 'EVIDENCE_SELECT',
          'graded': true,
          'config': {
            'graded': true,
            'visibleEvidenceIds': ['ev-1', 'ev-2', 'ev-3'],
            'minRequired': 2,
            'maxAttempts': 3,
          },
        });

        final evaluation = EvaluationDto.fromJson(const {
          'outcome': 'PARTIAL',
          'completed': false,
          'output': {
            'score': 0.5,
            'correctCount': 1,
            'falseCount': 1,
            'attemptCount': 1,
            'selectedVerdicts': {
              'ev-1': 'correct',
              'ev-3': 'incorrect',
            },
          },
        });

        await tester.pumpWidget(
          _wrap(
            EvidenceSelectRenderer(
              activity: activity,
              content: _sampleContent,
              submitting: false,
              lastEvaluation: evaluation,
              onSubmit: (_) async {},
            ),
          ),
        );

        // Thẻ ev-1 hiện đúng, ev-3 hiện sai, ev-2 (chưa chọn) không lộ nhãn
        expect(find.text('✓ Đúng dấu vết liên quan'), findsOneWidget);
        expect(find.text('✗ Chưa liên quan câu hỏi'), findsOneWidget);
        // InlineGradingHint hiển thị số đúng/sai và lượt còn lại
        expect(
          find.textContaining('Đúng 1 · sai 1 dấu vết đã chọn · còn 2/3 lượt'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '6. Khi exhausted / budgetExhausted: InlineGradingHint hiển thị thông báo đã hết lượt',
      (tester) async {
        final activity = ActivityRefDto.fromJson(const {
          'id': 'es-exhausted',
          'type': 'EVIDENCE_SELECT',
          'graded': true,
          'config': {
            'graded': true,
            'visibleEvidenceIds': ['ev-1', 'ev-2'],
            'minRequired': 1,
            'maxAttempts': 2,
          },
        });

        final evaluation = EvaluationDto.fromJson(const {
          'outcome': 'INCORRECT',
          'completed': true,
          'output': {
            'score': 0.33,
            'attemptCount': 2,
            'exhausted': true,
          },
        });

        await tester.pumpWidget(
          _wrap(
            EvidenceSelectRenderer(
              activity: activity,
              content: _sampleContent,
              submitting: false,
              lastEvaluation: evaluation,
              onSubmit: (_) async {},
            ),
          ),
        );

        expect(
          find.textContaining('Kết quả một phần (điểm 33%) · Đã hết lượt — bước này được tính hoàn thành'),
          findsOneWidget,
        );
      },
    );
  });
}
