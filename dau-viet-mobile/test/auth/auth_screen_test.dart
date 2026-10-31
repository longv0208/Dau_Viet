import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dau_viet_mobile/features/auth/presentation/auth_screen.dart';

void main() {
  group('AuthScreen Rhino Mascot Redesign Tests', () {
    testWidgets('renders Rhino mascot login elements matching new mockup', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      // Verify original brand logo is shown and VI language pill is removed
      expect(find.byKey(const ValueKey('auth_app_logo')), findsOneWidget);
      expect(find.text('VI'), findsNothing);

      // Verify welcome title & subtitle
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Chào mừng trở lại!'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Đăng nhập để tiếp tục hành trình\nkhám phá lịch sử Việt Nam.',
        ),
        findsOneWidget,
      );

      // Verify Rhino mascot hero image is rendered
      expect(find.byKey(const ValueKey('rhino_mascot_hero')), findsOneWidget);

      // Verify form fields & placeholders
      expect(find.text('Email hoặc số điện thoại'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);

      // Verify primary login button, divider, Google sign-in, and register footer
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('hoặc'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Chưa có tài khoản? '), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );

      final loginBtn = find.text('Đăng nhập');
      await tester.ensureVisible(loginBtn);
      await tester.tap(loginBtn);
      await tester.pump();

      expect(
        find.text('Vui lòng nhập email hoặc số điện thoại'),
        findsOneWidget,
      );
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on 360x800 and 390x844 viewports', (tester) async {
      for (final size in [const Size(360, 800), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: AuthScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });
  });
}
