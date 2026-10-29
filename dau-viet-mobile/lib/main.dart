import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app/app.dart';
import 'features/learning/data/learning_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
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
