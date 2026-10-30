import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app/app.dart';
import 'features/learning/data/learning_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // KHÔNG gọi SemanticsBinding.instance.ensureSemantics() ở đây — trên web
  // nó render <flt-semantics> overlay chặn click vào <iframe> của GIS
  // renderButton (google_sign_in_web). Semantics vẫn hoạt động khi user bật a11y.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  appContainer = ProviderContainer();
  // Khởi động phục hồi phiên đăng nhập trước khi mount router (hỗ trợ Web refresh / deep-linking)
  await appContainer!.read(authSessionProvider.notifier).restore();
  runApp(
    UncontrolledProviderScope(
      container: appContainer!,
      child: const DauVietApp(),
    ),
  );
}
