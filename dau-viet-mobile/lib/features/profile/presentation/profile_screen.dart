import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/mascot_slot.dart';
import '../../../core/widgets/rare_frame_badge.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/landscape_hero_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DauVietColors.paperCard.withValues(alpha: 0.45),
                      DauVietColors.paperBackground.withValues(alpha: 0.85),
                      DauVietColors.paperBackground,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
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
                    // Brand: logo + tagline (mockup: KHÁM PHÁ DI SẢN VIỆT NAM)
                    const _BrandHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _ProfileHeader(
                        session: session,
                        frameAsset: session.isAuthenticated
                            ? 'assets/images/dv_avatar_scholar.png'
                            : null,
                      ),
                    ),
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

                            // Hành trang & di sản — header icon + sub
                            _SectionHeader(
                              icon: Icons.account_balance_outlined,
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
                              icon: Icons.fitness_center_rounded,
                              iconColor: DauVietColors.cinnabarRed,
                              iconBg: DauVietColors.cinnabarRed.withValues(
                                alpha: 0.10,
                              ),
                              label: ApiConfig.useMock
                                  ? 'Viện Thái Y (demo)'
                                  : 'Viện Thái Y — Thể lực',
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

/// Header brand nhỏ trên đầu profile: logo + tagline
/// 'KHÁM PHÁ DI SẢN VIỆT NAM' (khác tagline dashboard).
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        children: [
          Image.asset(
            'assets/images/app_logo.png',
            height: 30,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text(
              'Dấu Việt',
              style: DauVietTypography.headlineMedium.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DauVietColors.heritageGreen,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'KHÁM PHÁ DI SẢN VIỆT NAM',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 8.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header cho cụm section — icon tròn + title serif + sub muted (mockup).
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DauVietTypography.headlineSmall.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkHeading,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 8.5,
                color: DauVietColors.inkMuted,
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
  final String? frameAsset;
  const _ProfileHeader({required this.session, this.frameAsset});

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
    final Widget avatarWidget = frameAsset != null
        ? RareFrameBadge(
            rarity: ItemRarity.rare,
            borderRadius: 28,
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Image.asset(
                frameAsset!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => StampSealBadge(
                  _initial,
                  size: 48,
                  color: DauVietColors.cinnabarRed,
                  filled: false,
                  rotationDeg: -6,
                ),
              ),
            ),
          )
        : StampSealBadge(
            _initial,
            size: 52,
            color: DauVietColors.cinnabarRed,
            filled: false,
            rotationDeg: -6,
          );

    return HeroPaperBanner(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatarWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionEyebrow('HỒ SƠ NHÀ KHÁM PHÁ'),
                const SizedBox(height: 8),
                Text(
                  _name,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 18,
                    color: DauVietColors.inkHeading,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subline,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const RareFrameBadge(
            rarity: ItemRarity.rare,
            borderRadius: 14,
            showGlow: false,
            padding: EdgeInsets.all(4),
            child: MascotSlot.icon(size: 44),
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
                bgColor: DauVietColors.imperialGoldLight.withValues(alpha: 0.35),
                value: '${summary.exp}',
                label: 'EXP',
              ),
              const SizedBox(width: 10),
              _StatCell(
                icon: Icons.history_edu_rounded,
                color: DauVietColors.cinnabarRed,
                bgColor: DauVietColors.cinnabarRed.withValues(alpha: 0.10),
                value: '${summary.historyPoints}',
                label: 'ĐIỂM SỬ KÝ',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCell(
                icon: Icons.school_rounded,
                color: DauVietColors.heritageGreenLight,
                bgColor: DauVietColors.heritageGreenSurface,
                value: '${summary.lessonsCompleted}',
                label: 'BÀI HỌC',
              ),
              const SizedBox(width: 10),
              _StatCell(
                icon: Icons.workspace_premium_rounded,
                color: DauVietColors.jade,
                bgColor: DauVietColors.jade.withValues(alpha: 0.12),
                value: '${summary.itemsOwned}',
                label: 'VẬT PHẨM',
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
    return TactileCard(
      backgroundColor: DauVietColors.paperCardHi,
      borderColor: DauVietColors.cinnabarRed,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/streak'),
      child: streakAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => Row(
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
        data: (LearningStreakDto s) => Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 28,
              color: (s.completedToday || s.streakAlive)
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.cinnabarRed.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionEyebrow(
                    'CHUỖI NGÀY HỌC',
                    showShadow: false,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.currentStreak} ngày liên tiếp — Kỷ lục ${s.longestStreak}',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w700,
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
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String value;
  final String label;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TactileCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: bgColor,
        borderColor: color.withValues(alpha: 0.5),
        child: Row(
          children: [
            // Icon trong vòng tròn màu đặc (mockup)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                    style: DauVietTypography.chapterNumberSmall.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: DauVietColors.inkHeading,
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
      child: TactileCard(
        onTap: onTap,
        backgroundColor: DauVietColors.paperCard,
        borderColor: danger
            ? DauVietColors.errorRed.withValues(alpha: 0.45)
            : DauVietColors.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
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
    );
  }
}
