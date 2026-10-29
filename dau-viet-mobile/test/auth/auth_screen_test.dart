import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/core/widgets/dong_son_button.dart';
import 'package:dau_viet_mobile/features/auth/presentation/auth_screen.dart';

void main() {
  group('AuthScreen UI/UX Pro Max Tests', () {
    testWidgets('renders all UI Pro Max login elements properly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Verify header & title
      expect(find.text('Đăng nhập'), findsNWidgets(2)); // Header bar + Submit button

      // Verify form fields
      expect(find.text('Email hoặc tên đăng nhập'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);

      // Google sign-in button + divider (Issue #34)
      expect(find.text('hoặc'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Chưa có tài khoản? '), findsOneWidget);
      expect(find.text('Đăng ký ngay'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Tap submit button with empty input
      await tester.tap(find.widgetWithText(DongSonButton, 'Đăng nhập'));
      await tester.pump();

      expect(find.text('Vui lòng nhập email hoặc tên đăng nhập'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    });
  });
}
