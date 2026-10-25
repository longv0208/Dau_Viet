import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/learning/data/learning_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  appContainer = ProviderContainer();
  // Khởi động phục hồi phiên đăng nhập ngay khi mở ứng dụng (hỗ trợ Web refresh / deep-linking)
  appContainer!.read(authSessionProvider.notifier).restore();
  runApp(
    UncontrolledProviderScope(
      container: appContainer!,
      child: const DauVietApp(),
    ),
  );
}
