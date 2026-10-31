import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'snackbar_route_observer.dart';

/// Bottom navigation chuẩn 5 tab của app — một nơi duy nhất định nghĩa
/// label/icon/route, mọi màn dùng chung. Tab đang chọn suy ra từ route
/// thực của go_router (không giữ index rời trên từng màn).
///
/// Tab mapping:
///   0 Học tập  → /dashboard   (bàn học + resume bài học)
///   1 Hành trình → /journey   (cây Era→Period→Sự kiện→Bài học — HỌC)
///   2 Đảo      → /island      (Đảo Di Sản — màn hình đầu sau đăng nhập)
///   3 Bản đồ   → /map         (di tích mở khoá sau bài học)
///   4 Cá nhân  → /profile     (hồ sơ + thành tích + đăng xuất)
class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key});

  /// Route prefix → tab index. Thứ tự match: prefix dài đứng trước để
  /// /collection/x vẫn thuộc tab Cá nhân.
  static const List<(String prefix, int tab)> _routeTabs = [
    ('/dashboard', 0),
    ('/learning', 0),
    ('/campaign', 0),
    ('/traces', 0),
    ('/journey', 1),
    ('/timeline', 1),
    ('/island', 2),
    ('/map', 3),
    ('/saban', 3),
    ('/heritage', 3),
    ('/collection', 4),
    ('/profile', 4),
    ('/inventory', 4),
    ('/energy', 4),
  ];

  /// Tab index cho location hiện tại; route lạ → -1 (không chọn tab nào).
  static int tabForLocation(String location) {
    for (final (prefix, tab) in _routeTabs) {
      if (location == prefix || location.startsWith('$prefix/')) {
        return tab;
      }
    }
    return -1;
  }

  static const _destinations = [
    ('/dashboard', Icons.school_outlined, Icons.school_rounded, 'Học tập'),
    (
      '/journey',
      Icons.explore_outlined,
      Icons.explore_rounded,
      'Hành trình',
    ),
    (
      '/island',
      Icons.landscape_outlined,
      Icons.landscape_rounded,
      'Đảo',
    ),
    ('/map', Icons.map_outlined, Icons.map_rounded, 'Bản đồ'),
    ('/profile', Icons.person_outline_rounded, Icons.person_rounded, 'Cá nhân'),
  ];

  /// Route hiện tại — thử GoRouterState (khi dưới RouteBase.builder); nếu
  /// không có (widget test bọc trực tiếp) thì đọc từ GoRouter nếu có, cuối
  /// cùng fallback chuỗi rỗng → không chọn tab nào.
  static String _locationOf(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      // Không nằm dưới route builder (vd: widget test). Bỏ qua — tab -1.
      try {
        return GoRouter.of(
          context,
        ).routeInformationProvider.value.uri.toString();
      } catch (_) {
        return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String location = _locationOf(context);
    final int current = tabForLocation(location);

    return Container(
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          top: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        boxShadow: DauVietColors.heritageShadow,
      ),
      child: BottomNavigationBar(
        currentIndex: current < 0 ? 0 : current,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DauVietColors.heritageGreen,
        unselectedItemColor: DauVietColors.inkMuted,
        selectedLabelStyle: DauVietTypography.labelSmall.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: DauVietTypography.labelSmall,
        onTap: (index) {
          if (index == current) return; // đang ở tab này
          rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..clearSnackBars();
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..clearSnackBars();
          try {
            context.go(_destinations[index].$1);
          } catch (_) {
            // Không có GoRouter (widget test) — bỏ qua điều hướng.
          }
        },
        items: [
          for (final (_, icon, activeIcon, label) in _destinations)
            BottomNavigationBarItem(
              icon: Icon(icon),
              activeIcon: Icon(activeIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}
