import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/features/auth/presentation/otp_verification_screen.dart';

/// Widget tests cho màn OTP (Issue #34). Provider thật không được khởi tạo
/// (không có ApiClient/platform) — test chỉ assert render + validation local;
/// submit path được cover bởi auth_repository_test.
void main() {
  Widget wrap(OtpFlowArgs args) => ProviderScope(
        child: MaterialApp(home: OtpVerificationScreen(args: args)),
      );

  testWidgets('registerVerify: hiển thị email + ô nhập + nút xác thực', (tester) async {
    await tester.pumpWidget(wrap(
      OtpFlowArgs.register(email: 'hoc.vien@dauviet.vn'),
    ));
    await tester.pump();

    expect(find.text('XÁC THỰC EMAIL'), findsOneWidget);
    expect(find.textContaining('hoc.vien@dauviet.vn'), findsOneWidget);
    expect(find.text('Xác Thực & Vào Học'), findsOneWidget);
    // Resend đang trong cooldown → disabled với countdown.
    expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
  });

  testWidgets('nhập chưa đủ 6 số → báo lỗi local', (tester) async {
    await tester.pumpWidget(wrap(
      OtpFlowArgs.register(email: 'a@b.vn'),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Xác Thực & Vào Học'));
    await tester.pump();

    expect(find.text('Nhập đủ 6 chữ số của mã.'), findsOneWidget);
  });

  testWidgets('passwordReset flow: nút tiếp tục', (tester) async {
    await tester.pumpWidget(wrap(
      OtpFlowArgs.passwordReset(email: 'b@c.vn'),
    ));
    await tester.pump();

    expect(find.text('Tiếp Tục'), findsOneWidget);
  });
}
