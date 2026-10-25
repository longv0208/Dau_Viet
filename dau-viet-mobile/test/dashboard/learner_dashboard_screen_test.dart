import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/core/widgets/dong_son_button.dart';
import 'package:dau_viet_mobile/features/dashboard/presentation/learner_dashboard_screen.dart';

void main() {
  group('LearnerDashboardScreen UI/UX Pro Max Tests', () {
    testWidgets('renders all 6 UI Pro Max homepage sections properly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LearnerDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // 1. Top Bar: Dấu Việt logo, chuông thông báo & avatar
      expect(find.text('Dấu Việt'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // 2. Greeting & Status Row
      expect(find.text('Xin chào,'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // 3. Hero Banner Card
      expect(find.text('Bắt đầu hành trình'), findsOneWidget);
      expect(find.widgetWithText(DongSonButton, 'KHÁM PHÁ NGAY ›'), findsOneWidget);

      // 4. Section: Bài học hôm nay
      expect(find.text('Bài học hôm nay'), findsOneWidget);
      expect(find.text('Thời Hùng Vương'), findsOneWidget);
      expect(find.text('Nguồn gốc dân tộc'), findsOneWidget);
      expect(find.text('3/5 bài học'), findsOneWidget);

      // 5. Section: Hành trình của bạn (4 thẻ chức năng)
      expect(find.text('Hành trình của bạn'), findsOneWidget);
      expect(find.text('Bài học'), findsOneWidget);
      expect(find.text('Ôn tập'), findsOneWidget);
      expect(find.text('Thành tích'), findsOneWidget);
      expect(find.text('Thư viện'), findsOneWidget);

      // 6. Section: Nhiệm vụ hôm nay & Sự kiện nổi bật
      expect(find.text('Nhiệm vụ hôm nay'), findsOneWidget);
      expect(find.text('Hoàn thành bài học hôm nay'), findsOneWidget);
      expect(find.text('Ôn tập 3 câu hỏi'), findsOneWidget);
      expect(find.text('Đọc một tư liệu trong thư viện'), findsOneWidget);

      expect(find.text('Sự kiện nổi bật'), findsOneWidget);
      expect(find.text('Bạch Đằng 938'), findsOneWidget);
      expect(find.text('Khám phá ngay →'), findsOneWidget);
    });
  });
}
