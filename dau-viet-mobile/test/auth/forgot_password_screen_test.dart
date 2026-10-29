import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:dau_viet_mobile/features/auth/presentation/reset_password_screen.dart';

/// Widget tests cho luồng quên mật khẩu (Issue #34).
void main() {
  testWidgets('ForgotPassword: render email field + submit button', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: ForgotPasswordScreen()),
    ));
    await tester.pump();

    expect(find.text('KHÔI PHỤC MẬT KHẨU'), findsOneWidget);
    expect(find.text('Gửi Mã Xác Thực'), findsOneWidget);
  });

  testWidgets('ForgotPassword: email sai format → validation error', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: ForgotPasswordScreen()),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Gửi Mã Xác Thực'));
    await tester.pump();

    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
  });

  testWidgets('ResetPassword: mismatch confirm → validation error', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: ResetPasswordScreen(email: 'a@b.vn', otpCode: '123456'),
      ),
    ));
    await tester.pump();

    expect(find.text('MẬT KHẨU MỚI'), findsOneWidget);
    expect(find.textContaining('a@b.vn'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'newpassword1');
    await tester.enterText(fields.at(1), 'different-pass');
    await tester.tap(find.text('Đặt Lại Mật Khẩu'));
    await tester.pump();

    expect(find.text('Mật khẩu nhập lại chưa khớp'), findsOneWidget);
  });

  testWidgets('ResetPassword: password ngắn → validation error', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: ResetPasswordScreen(email: 'a@b.vn', otpCode: '123456'),
      ),
    ));
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'short');
    await tester.enterText(fields.at(1), 'short');
    await tester.tap(find.text('Đặt Lại Mật Khẩu'));
    await tester.pump();

    expect(find.text('Mật khẩu tối thiểu 8 ký tự'), findsOneWidget);
  });
}
