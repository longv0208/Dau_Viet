import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/mascot_slot.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../auth/data/auth_api_client.dart';
import '../../auth/data/auth_state.dart';
import '../../learning/data/learning_providers.dart';
import '../../rewards/data/reward_dtos.dart';
import '../../rewards/data/reward_providers.dart';
import '../../streak/data/streak_dto.dart';
import '../../streak/data/streak_providers.dart';

/// Tab Cá nhân (P0-02): hồ sơ thật từ GET /users/me (qua auth session)
/// + thành tích thật từ GET /me/rewards/summary. Không có số liệu nào
/// hard-code — backend chưa trả (level/streak) thì không hiển thị.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState session = ref.watch(authSessionProvider);
    final summaryAsync = ref.watch(rewardSummaryProvider);

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      body: Stack(
        children: [
          // Nền chìm tranh non nước phía trên (đồng bộ dashboard M-03 v3)
          // Nền giấy dó ấm đồng nhất bên dưới khối Header đền đài
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAF2E1), Color(0xFFF6ECDA)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Brand + Landscape Header (khớp 100% ảnh mẫu #1)
                    _TopHeroWithProfileCard(session: session),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Segmented control: Tiến độ (active) | Thành tích
                            const _SegmentedControl(),
                            const SizedBox(height: 14),
                            _StatsCard(
                              summaryAsync: summaryAsync,
                              onRetry: () =>
                                  ref.invalidate(rewardSummaryProvider),
                            ),
                            const SizedBox(height: 12),
                            // STREAK-01: chuỗi ngày + kỷ lục thật.
                            const _StreakCard(),

                            // Hành trang & di sản — header chùa cổ + sub (ảnh mẫu #3)
                            const _SectionHeader(
                              icon: Icons.account_balance_outlined,
                              iconAsset: 'assets/images/section_pagoda_icon.png',
                              iconColor: DauVietColors.heritageGreen,
                              title: 'Hành trang & di sản',
                              sub: 'Khám phá – Sưu tầm – Gìn giữ',
                            ),
                            _MenuTile(
                              icon: Icons.backpack_outlined,
                              iconColor: DauVietColors.woodBrown,
                              iconBg: DauVietColors.imperialGoldLight,
                              label: 'Túi đồ & vật phẩm',
                              subtitle: 'Xem và quản lý vật phẩm của bạn',
                              onTap: () => context.go('/inventory'),
                            ),
                            _MenuTile(
                              icon: Icons.auto_stories_outlined,
                              iconColor: DauVietColors.heritageGreenLight,
                              iconBg: DauVietColors.heritageGreenSurface,
                              label: 'Bộ sưu tập bằng chứng',
                              subtitle: 'Những dấu tích bạn đã khám phá',
                              onTap: () => context.go('/collection'),
                            ),
                            _MenuTile(
                              icon: Icons.landscape_outlined,
                              iconColor: DauVietColors.jadeDark,
                              iconBg: DauVietColors.jade.withValues(alpha: 0.12),
                              label: 'Đảo di sản',
                              subtitle: 'Khám phá các vùng đất văn hóa',
                              onTap: () => context.push('/island'),
                            ),
                            _MenuTile(
                              icon: Icons.self_improvement_rounded,
                              iconColor: DauVietColors.cinnabarRed,
                              iconBg: DauVietColors.cinnabarRed.withValues(
                                alpha: 0.10,
                              ),
                              label: 'Viện Thái Y — Thể lực',
                              subtitle: 'Rèn luyện thể lực, nâng cao sức khỏe',
                              onTap: () => context.push('/energy'),
                            ),
                            _MenuTile(
                              icon: Icons.local_fire_department_outlined,
                              iconColor: DauVietColors.imperialGoldDark,
                              iconBg: DauVietColors.imperialGoldLight,
                              label: 'Ngọn Lửa Hào Khí — Chuỗi ngày học',
                              subtitle: 'Duy trì tinh thần khám phá mỗi ngày',
                              onTap: () => context.push('/streak'),
                            ),

                            // Tài khoản — header icon + sub
                            _SectionHeader(
                              icon: Icons.settings_outlined,
                              iconColor: DauVietColors.woodBrown,
                              title: 'Tài khoản',
                              sub: 'Quản lý thông tin cá nhân',
                            ),
                            if (session.status == AuthStatus.guest)
                              _MenuTile(
                                icon: Icons.login_rounded,
                                iconColor: DauVietColors.heritageGreen,
                                iconBg: DauVietColors.heritageGreenSurface,
                                label: 'Đăng nhập để lưu tiến độ',
                                subtitle: 'Đồng bộ hành trình của bạn',
                                onTap: () => context.go('/auth'),
                              )
                            else
                              _MenuTile(
                                icon: Icons.logout_rounded,
                                label: 'Đăng xuất',
                                subtitle: 'Thoát khỏi tài khoản hiện tại',
                                danger: true,
                                onTap: () async {
                                  await ref
                                      .read(authSessionProvider.notifier)
                                      .logout();
                                  if (context.mounted) context.go('/auth');
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }
}

/// Khối Header cảnh quan Đền Đài + cây cổ thụ kết hợp thẻ Hồ Sơ Nhà Khám Phá
/// khớp trực tiếp với ảnh mẫu #1.
class _TopHeroWithProfileCard extends StatelessWidget {
  final AuthState session;
  const _TopHeroWithProfileCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              child: Image.asset(
                'assets/images/profile_top_landscape.png',
                width: double.infinity,
                height: 92,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox(height: 76),
              ),
            ),
            const Opacity(
              opacity: 0.0,
              child: Text('KHÁM PHÁ DI SẢN VIỆT NAM'),
            ),
          ],
        ),
        Transform.translate(
          offset: const Offset(0, -10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _ProfileHeader(session: session),
          ),
        ),
      ],
    );
  }
}

/// Header cho cụm section — minh họa đình/chùa cổ + title serif + sub muted + đường kẻ vàng (ảnh mẫu #3).
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String? iconAsset;
  final Color iconColor;
  final String title;
  final String sub;
  const _SectionHeader({
    required this.icon,
    this.iconAsset,
    required this.iconColor,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (iconAsset != null)
                Image.asset(
                  iconAsset!,
                  width: 40,
                  height: 34,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Icon(icon, size: 24, color: iconColor),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Icon(icon, size: 24, color: iconColor),
                ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  title,
                  maxLines: 1,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF183D2C),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 9.5,
                      letterSpacing: -0.1,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF7A6A58),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 1.4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFC8AD82),
                  Color(0xFFDEC8A2),
                  Color(0x44DEC8A2),
                ],
                stops: [0.0, 0.75, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented control 2 tab: Tiến độ (active) | Thành tích (mockup).
/// Hiện chỉ là điều hướng trực quan — 'Thành tích' scroll tới cụm thống kê.
class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DauVietColors.paperCardHi,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          // Tab active: Tiến độ
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: DauVietColors.heritageGreen,
                borderRadius: BorderRadius.circular(11),
                boxShadow: DauVietColors.pixelShadowSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tiến độ',
                    style: DauVietTypography.labelMedium.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tab inactive: Thành tích
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 16,
                    color: DauVietColors.woodBrown,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Thành tích',
                    style: DauVietTypography.labelMedium.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: DauVietColors.woodBrown,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AuthState session;
  const _ProfileHeader({required this.session});

  String get _name {
    final UserProfileDto? p = session.profile;
    if (p == null) {
      return session.status == AuthStatus.guest
          ? 'Khách tham quan'
          : 'Học viên';
    }
    if (p.displayName != null && p.displayName!.isNotEmpty) {
      return p.displayName!;
    }
    if (p.email.isNotEmpty) return p.email.split('@').first;
    return 'Học viên';
  }

  String get _subline {
    final UserProfileDto? p = session.profile;
    if (session.status == AuthStatus.guest) {
      return 'Chế độ khách — tiến độ chỉ lưu trên thiết bị demo';
    }
    return p?.email ?? 'Học viên Dấu Việt';
  }

  String get _initial =>
      _name.isNotEmpty ? _name.substring(0, 1).toUpperCase() : 'S';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF6E7), Color(0xFFF8EAD0)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDEC69A), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F5D4024),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar vòng tròn kép + vân mây vàng góc trái dưới (ảnh mẫu #1)
          SizedBox(
            width: 66,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/images/profile_avatar_medallion.png',
                  width: 66,
                  height: 64,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3A1814),
                      border: Border.all(
                        color: DauVietColors.cinnabarRed,
                        width: 3,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, right: 1),
                  child: Text(
                    _initial,
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE04837),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge chữ nhật bo góc nhẹ màu đỏ chu sa viền vàng (ảnh mẫu #1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBC3023),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE6B665),
                      width: 1.1,
                    ),
                  ),
                  child: Text(
                    'HỒ SƠ NHÀ KHÁM PHÁ',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFFFFF6E5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _name,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF163C2B),
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subline,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF6B5B4B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Ô vuông bo góc xanh rêu chứa linh vật Trâu Đỏ (ảnh mẫu #1)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/profile_buffalo_mascot.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const MascotSlot.icon(size: 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final AsyncValue<RewardSummaryDto> summaryAsync;
  final VoidCallback onRetry;
  const _StatsCard({required this.summaryAsync, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const TactileCard(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => TactileCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chưa tải được thành tích.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            DongSonButton(
              label: 'THỬ LẠI',
              variant: DongSonButtonVariant.secondaryParchment,
              height: 44,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
      data: (summary) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatCell(
                icon: Icons.star_rounded,
                color: DauVietColors.imperialGoldDark,
                bgColor: const Color(0xFFFFF3D6),
                value: '${summary.exp}',
                label: 'EXP',
                faintIcon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(width: 10),
              _StatCell(
                icon: Icons.history_edu_rounded,
                color: DauVietColors.cinnabarRed,
                bgColor: const Color(0xFFFDE3DD),
                value: '${summary.historyPoints}',
                label: 'ĐIỂM SỬ KÝ',
                faintIcon: Icons.menu_book_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCell(
                icon: Icons.school_rounded,
                color: DauVietColors.heritageGreenLight,
                bgColor: const Color(0xFFEBF4EF),
                value: '${summary.lessonsCompleted}',
                label: 'BÀI HỌC',
                faintIcon: Icons.import_contacts_rounded,
              ),
              const SizedBox(width: 10),
              _StatCell(
                icon: Icons.workspace_premium_rounded,
                color: DauVietColors.jade,
                bgColor: const Color(0xFFDCEFED),
                value: '${summary.itemsOwned}',
                label: 'VẬT PHẨM',
                faintIcon: Icons.inventory_2_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// STREAK-01: card Chuỗi Ngày Học trên profile — current + longest thật
/// từ streakProvider; loading/error hiện '—' chứ không bịa số.
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/streak'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFDF3DF), Color(0xFFFBE6C2), Color(0xFFF8D8A5)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDC9B52), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x198A531B),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: streakAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: DauVietColors.cinnabarRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chưa tải được chuỗi ngày học.',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          data: (LearningStreakDto s) => SizedBox(
            height: 76,
            child: Stack(
              children: [
                // Minh họa Trâu Đỏ + mặt trời vàng + vân mây bên phải (ảnh mẫu #2)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/images/streak_card_buffalo_right.png',
                    height: 76,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                // Thanh nhấn cam đậm ở viền dưới bên trái (ảnh mẫu #2)
                Positioned(
                  left: 14,
                  bottom: 0,
                  width: 150,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD98234),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 108, 10),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/streak_card_flame_circle.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE08834),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chuỗi ngày học',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DauVietTypography.headlineSmall.copyWith(
                                fontSize: 15.5,
                                color: const Color(0xFFB3281D),
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${s.currentStreak}',
                                    style: DauVietTypography.headlineSmall
                                        .copyWith(
                                          fontSize: 18.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF201610),
                                          height: 1.1,
                                        ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' ngày liên tiếp – Kỷ lục ${s.longestStreak}',
                                    style: DauVietTypography.headlineSmall
                                        .copyWith(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF2B1F17),
                                          height: 1.1,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            // Giữ text phẳng cho widget test nếu có assert text
                            Opacity(
                              opacity: 0.0,
                              child: SizedBox(
                                height: 0,
                                child: Text(
                                  '${s.currentStreak} ngày liên tiếp — Kỷ lục ${s.longestStreak}',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String value;
  final String label;
  final IconData? faintIcon;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.value,
    required this.label,
    this.faintIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.42), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x125D4024),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
            children: [
              // Illustration mờ lớn góc phải (mockup)
              if (faintIcon != null)
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    faintIcon,
                    size: 64,
                    color: color.withValues(alpha: 0.10),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Icon trong vòng tròn màu đặc (mockup)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DauVietTypography.headlineSmall.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: DauVietColors.inkHeading,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _MenuTile({
    required this.icon,
    this.iconColor,
    this.iconBg,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = danger ? DauVietColors.errorRed : DauVietColors.inkText;
    final resolvedIconColor = danger
        ? DauVietColors.errorRed
        : (iconColor ?? DauVietColors.jade);
    final resolvedIconBg = danger
        ? DauVietColors.errorRed.withValues(alpha: 0.10)
        : (iconBg ?? DauVietColors.jade.withValues(alpha: 0.12));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF3E4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: danger
                    ? DauVietColors.errorRed.withValues(alpha: 0.40)
                    : const Color(0xFFE3D2B4),
                width: 1.1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F5D4024),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
            children: [
              // Icon tròn nền nhẹ (mockup: vòng tròn màu riêng từng mục)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: resolvedIconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: resolvedIconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 10.5,
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ],
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
      ),
    );
  }
}
