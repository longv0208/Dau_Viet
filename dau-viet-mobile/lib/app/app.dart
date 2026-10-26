import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/dau_viet_theme.dart';
import '../features/energy/data/energy_providers.dart';
import '../features/streak/data/streak_providers.dart';
import 'router.dart';

/// Ứng dụng Dấu Việt Mobile Root Widget
/// GAME-03: chuyển sang StatefulWidget để observe app lifecycle — khi app
/// quay lại foreground thì refetch Thể lực (recovery trôi trong lúc nền).
class DauVietApp extends ConsumerStatefulWidget {
  const DauVietApp({super.key});

  @override
  ConsumerState<DauVietApp> createState() => _DauVietAppState();
}

class _DauVietAppState extends ConsumerState<DauVietApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // refresh() tự kiểm phiên còn sống — guest/unauth → notifier lo.
      ref.read(energyProvider.notifier).refresh();
      // STREAK-01: resume có thể đã qua nửa đêm VN → refetch streak để
      // cập nhật streakAlive/completedToday theo ngày server mới.
      ref.read(streakProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dấu Việt',
      debugShowCheckedModeBanner: false,
      theme: DauVietTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
