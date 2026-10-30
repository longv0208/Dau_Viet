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
import '../../../core/widgets/section_divider.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DauVietColors.paperBackground, DauVietColors.paperCard],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _ProfileHeader(session: session),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionDivider(
                            eyebrow: 'TIẾN ĐỘ',
                            title: 'Thành tích',
                            padding: EdgeInsets.only(top: 4, bottom: 12),
                          ),
                          _StatsCard(
                            summaryAsync: summaryAsync,
                            onRetry: () =>
                                ref.invalidate(rewardSummaryProvider),
                          ),
                          const SizedBox(height: 12),
                          // STREAK-01: chuỗi ngày + kỷ lục thật từ
                          // GET /me/streak — bấm mở màn chi tiết.
                          const _StreakCard(),
                          const SectionDivider(
                            eyebrow: 'QUẢN LÝ',
                            title: 'Hành trang & di sản',
                          ),
                          _MenuTile(
                            icon: Icons.backpack_outlined,
                            iconColor: DauVietColors.jade,
                            label: 'Túi đồ & vật phẩm',
                            onTap: () => context.go('/inventory'),
                          ),
                          _MenuTile(
                            icon: Icons.auto_stories_outlined,
                            iconColor: DauVietColors.heritageGreen,
                            label: 'Bộ sưu tập bằng chứng',
                            onTap: () => context.go('/collection'),
                          ),
                          // Đảo di sản là sở hữu/trang trí thật — mở cho
                          // mọi learner, không gating demo.
                          _MenuTile(
                            icon: Icons.landscape_outlined,
                            iconColor: DauVietColors.jade,
                            label: 'Đảo di sản',
                            onTap: () => context.push('/island'),
                          ),
                          // GAME-03: Viện Thái Y có backend thật — mở
                          // cho cả real mode (mock gắn nhãn demo).
                          _MenuTile(
                            icon: Icons.bolt_outlined,
                            iconColor: DauVietColors.heritageGreen,
                            label: ApiConfig.useMock
                                ? 'Viện Thái Y (demo)'
                                : 'Viện Thái Y — Thể lực',
                            onTap: () => context.push('/energy'),
                          ),
                          // STREAK-01: Ngọn Lửa Hào Khí backend thật.
                          _MenuTile(
                            icon: Icons.local_fire_department_outlined,
                            iconColor: DauVietColors.jade,
                            label: 'Ngọn Lửa Hào Khí — Chuỗi ngày học',
                            onTap: () => context.push('/streak'),
                          ),
                          const SectionDivider(
                            eyebrow: 'TÀI KHOẢN',
                            title: 'Thiết lập',
                          ),
                          if (session.status == AuthStatus.guest)
                            _MenuTile(
                              icon: Icons.login_rounded,
                              iconColor: DauVietColors.heritageGreen,
                              label: 'Đăng nhập để lưu tiến độ',
                              onTap: () => context.go('/auth'),
                            )
                          else
                            _MenuTile(
                              icon: Icons.logout_rounded,
                              label: 'Đăng xuất',
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
      ),
      bottomNavigationBar: const MainBottomNav(),
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
    // Issue #41: dv_avatar_scholar.png bị 404 — dùng con dấu chữ cái đầu
    // làm avatar cho tới khi có asset thật.
    final Widget avatarWidget = StampSealBadge(
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
                value: '${summary.exp}',
                label: 'EXP',
              ),
              const SizedBox(width: 10),
              _StatCell(
                icon: Icons.history_edu_rounded,
                color: DauVietColors.cinnabarRed,
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
                color: DauVietColors.natureGreen,
                value: '${summary.lessonsCompleted}',
                label: 'BÀI HỌC',
              ),
              const SizedBox(width: 10),
              _StatCell(
                icon: Icons.workspace_premium_rounded,
                color: DauVietColors.jade,
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
  final String value;
  final String label;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TactileCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: DauVietColors.paperCard,
        borderColor: color.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: SectionEyebrow(
                    label,
                    color: color,
                    showShadow: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: DauVietTypography.chapterNumberSmall.copyWith(
                fontSize: 16,
                color: DauVietColors.inkHeading,
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
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuTile({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = danger ? DauVietColors.errorRed : DauVietColors.inkText;
    final resolvedIconColor = danger
        ? DauVietColors.errorRed
        : (iconColor ?? DauVietColors.jade);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TactileCard(
        onTap: onTap,
        backgroundColor: DauVietColors.paperCard,
        borderColor: danger
            ? DauVietColors.errorRed.withValues(alpha: 0.45)
            : DauVietColors.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              Icon(icon, size: 22, color: resolvedIconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: DauVietTypography.labelMedium.copyWith(
                    color: textColor,
                  ),
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
