import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';

/// Banner chúc mừng địa điểm di sản vừa mở khóa trên màn Kết quả bài học (E5 - Issue #25).
///
/// Quy tắc nghiệp vụ:
/// - Chỉ hiển thị khi [locations] (`newlyUnlockedLocations`) không rỗng.
/// - Có 2 nút hành động rõ ràng: **Xem địa điểm** và **Tiếp tục học**.
/// - Chỉ phát animation mở khóa đúng MỘT lần khi màn kết quả được mở từ luồng
///   hoàn thành bài học ([animate] = true). Khi mở lại qua deep-link / reload
///   ([animate] = false) hoặc khi widget rebuild, animation KHÔNG phát lại.
class UnlockedLocationBanner extends StatefulWidget {
  final List<UnlockedLocationCueDto> locations;

  /// Có cho phép phát animation chào mừng khi mount lần đầu hay không.
  /// Deep-link mở lại kết quả truyền `false` để không phát lại animation.
  final bool animate;

  /// Callback tùy chọn khi bấm "Xem địa điểm" (mặc định điều hướng tới
  /// `/heritage/:locationId` hoặc `/map?locationId=:locationId`).
  final void Function(UnlockedLocationCueDto location)? onViewLocation;

  /// Callback tùy chọn khi bấm "Tiếp tục học" (mặc định điều hướng tới
  /// `/dashboard` hoặc `/journey`).
  final VoidCallback? onContinueLearning;

  const UnlockedLocationBanner({
    super.key,
    required this.locations,
    this.animate = true,
    this.onViewLocation,
    this.onContinueLearning,
  });

  @override
  State<UnlockedLocationBanner> createState() => UnlockedLocationBannerState();
}

class UnlockedLocationBannerState extends State<UnlockedLocationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _badgePulseAnimation;

  bool _hasAnimated = false;
  int _animationRunCount = 0;

  /// Phục vụ widget test kiểm chứng animation chỉ chạy tối đa 1 lần và không
  /// chạy khi mở lại qua deep-link (`animate == false`).
  @visibleForTesting
  bool get hasAnimated => _hasAnimated;

  @visibleForTesting
  int get animationRunCount => _animationRunCount;

  @visibleForTesting
  AnimationController get animationController => _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _badgePulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.75, end: 1.12), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animate && widget.locations.isNotEmpty) {
      _hasAnimated = true;
      _animationRunCount = 1;
      _controller.forward();
    } else {
      // Deep-link hoặc tắt animation: giữ trạng thái tĩnh hoàn tất, không chạy tween.
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant UnlockedLocationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tuyệt đối không reset hay chạy lại _controller khi widget cha rebuild
    // (ví dụ khi _recapContentProvider tải xong dữ liệu).
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleViewLocation(
    BuildContext context,
    UnlockedLocationCueDto location,
  ) {
    if (widget.onViewLocation != null) {
      widget.onViewLocation!(location);
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final locId = location.locationId;
      if (locId.isNotEmpty &&
          _hasRoutePrefix(router.configuration.routes, '/heritage')) {
        router.go('/heritage/$locId');
        return;
      }
      if (locId.isNotEmpty) {
        router.go('/map?locationId=${Uri.encodeComponent(locId)}');
        return;
      }
      router.go('/map');
    }
  }

  void _handleContinueLearning(BuildContext context) {
    if (widget.onContinueLearning != null) {
      widget.onContinueLearning!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final routes = router.configuration.routes;
      if (_hasRoutePrefix(routes, '/dashboard')) {
        router.go('/dashboard');
        return;
      }
      if (_hasRoutePrefix(routes, '/journey')) {
        router.go('/journey');
        return;
      }
    }
    Navigator.of(context).maybePop();
  }

  bool _hasRoutePrefix(List<RouteBase> routes, String prefix) {
    for (final r in routes) {
      if (r is GoRoute && (r.path == prefix || r.path.startsWith('$prefix/'))) {
        return true;
      }
      if (r.routes.isNotEmpty && _hasRoutePrefix(r.routes, prefix)) {
        return true;
      }
    }
    return false;
  }

  IconData _iconForKind(String? kind) {
    switch (kind?.toUpperCase()) {
      case 'HERITAGE_SITE':
        return Icons.account_balance_rounded;
      case 'BATTLEFIELD':
        return Icons.shield_rounded;
      case 'ANCIENT_CAPITAL':
        return Icons.castle_rounded;
      case 'ARCHAEOLOGICAL_SITE':
        return Icons.terrain_rounded;
      case 'MEMORIAL':
        return Icons.volunteer_activism_rounded;
      case 'SCHEMATIC_REGION':
        return Icons.map_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locations.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final int count = widget.locations.length;
    final String headerText = count == 1
        ? 'ĐỊA ĐIỂM DI SẢN VỪA MỞ KHÓA'
        : 'ĐÃ MỞ KHÓA $count ĐỊA ĐIỂM DI SẢN';

    final Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: DauVietColors.imperialGold.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header chúc mừng mở khóa địa điểm
          Row(
            children: [
              ScaleTransition(
                scale: reduceMotion
                    ? const AlwaysStoppedAnimation<double>(1.0)
                    : _badgePulseAnimation,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DauVietColors.heritageGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DauVietColors.heritageGreen,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: DauVietColors.heritageGreen,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerText,
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.heritageGreen,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dấu ấn mới đã xuất hiện trên Bản đồ Di sản',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Danh sách địa điểm vừa mở khóa
          for (int i = 0; i < widget.locations.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _UnlockedLocationTile(
              location: widget.locations[i],
              icon: _iconForKind(widget.locations[i].kind),
              onTap: () => _handleViewLocation(context, widget.locations[i]),
            ),
          ],
          const SizedBox(height: 14),

          // 3. Hai nút hành động: Xem địa điểm & Tiếp tục học
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      _handleViewLocation(context, widget.locations.first),
                  icon: const Icon(Icons.place_rounded, size: 18),
                  label: const Text('Xem địa điểm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DauVietColors.heritageGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: DauVietTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleContinueLearning(context),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Tiếp tục học'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DauVietColors.inkText,
                    backgroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: const BorderSide(
                      color: Color(0xFFD8C8B0),
                      width: 1.2,
                    ),
                    textStyle: DauVietTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (reduceMotion || !widget.animate) {
      return card;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: card),
    );
  }
}

class _UnlockedLocationTile extends StatelessWidget {
  final UnlockedLocationCueDto location;
  final IconData icon;
  final VoidCallback onTap;

  const _UnlockedLocationTile({
    required this.location,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = location.title.isNotEmpty
        ? location.title
        : 'Địa điểm lịch sử mới';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5DAC6), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DauVietColors.imperialGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFB45309)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.kindLabelVi,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DauVietColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
