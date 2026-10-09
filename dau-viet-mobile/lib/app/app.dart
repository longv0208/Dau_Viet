import 'package:flutter/material.dart';
import '../core/theme/dau_viet_theme.dart';
import 'router.dart';

/// Ứng dụng Dấu Việt Mobile Root Widget
class DauVietApp extends StatelessWidget {
  const DauVietApp({super.key});

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
