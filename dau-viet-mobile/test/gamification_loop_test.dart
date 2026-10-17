import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/core/widgets/combo_streak_badge_widget.dart';
import 'package:dau_viet_mobile/core/widgets/bite_sized_completion_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComboStreakBadgeWidget Tests', () {
    testWidgets('Renders streak count and flame icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ComboStreakBadgeWidget(streakCount: 3, multiplier: 1.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      // Khi multiplier <= 1.0, không hiển thị huy hiệu nhân điểm
      expect(find.text('x1.0'), findsNothing);
    });

    testWidgets('Renders bonus multiplier badge when multiplier > 1.0', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ComboStreakBadgeWidget(streakCount: 5, multiplier: 1.5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('x1.5'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('Displays explanation dialog on tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ComboStreakBadgeWidget(streakCount: 4, multiplier: 1.5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm vào badge
      await tester.tap(find.byType(ComboStreakBadgeWidget));
      await tester.pumpAndSettle();

      // Xác nhận dialog xuất hiện
      expect(find.text('Ngọn Lửa Hào Khí'), findsOneWidget);
      expect(
        find.textContaining('Chuỗi trả lời đúng liên tiếp: 4 câu'),
        findsOneWidget,
      );
      expect(find.text('ĐÃ HIỂU'), findsOneWidget);

      // Đóng dialog
      await tester.tap(find.text('ĐÃ HIỂU'));
      await tester.pumpAndSettle();

      expect(find.text('Ngọn Lửa Hào Khí'), findsNothing);
    });

    testWidgets('Triggers custom onTap callback when provided', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ComboStreakBadgeWidget(
                streakCount: 2,
                multiplier: 1.0,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ComboStreakBadgeWidget));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('BiteSizedCompletionModal Tests', () {
    testWidgets('Renders all celebratory components and accuracy label', (
      WidgetTester tester,
    ) async {
      bool continued = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    BiteSizedCompletionModal.show(
                      context: context,
                      title: 'CHIẾN CÔNG HOÀN TẤT!',
                      subtitle: 'Bạn đã hoàn thành xuất sắc Dấu Vết 1.',
                      scorePoints: 100,
                      xpPoints: 50,
                      accuracy: 1.0,
                      streakCount: 3,
                      multiplier: 1.5,
                      onContinue: () {
                        continued = true;
                      },
                    );
                  },
                  child: const Text('MỞ MODAL'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mở modal
      await tester.tap(find.text('MỞ MODAL'));
      await tester.pumpAndSettle();

      // Xác nhận các thành phần của modal
      expect(find.text('CHIẾN CÔNG HOÀN TẤT!'), findsOneWidget);
      expect(
        find.text('Bạn đã hoàn thành xuất sắc Dấu Vết 1.'),
        findsOneWidget,
      );
      expect(find.text('100% Tuyệt Đỉnh'), findsOneWidget);
      expect(find.text('Chuỗi 3 🔥'), findsOneWidget);
      expect(find.text('Điểm Sử Ký (x1.5)'), findsOneWidget);
      expect(find.text('Kinh Nghiệm XP'), findsOneWidget);
      expect(find.text('TIẾP TỤC HÀNH TRÌNH ›'), findsOneWidget);

      // Bấm nút tiếp tục hành trình
      await tester.tap(find.text('TIẾP TỤC HÀNH TRÌNH ›'));
      await tester.pumpAndSettle();

      expect(continued, isTrue);
      // Modal đã đóng
      expect(find.text('CHIẾN CÔNG HOÀN TẤT!'), findsNothing);
    });

    testWidgets('Renders lower accuracy labels correctly (80% and 50%)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BiteSizedCompletionModal(
                title: 'THỬ THÁCH HOÀN THÀNH',
                subtitle: 'Ghi nhận kết quả khảo cứu.',
                scorePoints: 80,
                xpPoints: 40,
                accuracy: 0.85,
                streakCount: 2,
                multiplier: 1.0,
                onContinue: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('85% Xuất Sắc'), findsOneWidget);
      expect(find.text('Chuỗi 2 🔥'), findsOneWidget);
      expect(find.text('Điểm Sử Ký'), findsOneWidget);
    });
  });
}
