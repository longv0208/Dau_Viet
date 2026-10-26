import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/parchment_card.dart';
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
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DauVietColors.parchmentSurface, Color(0xFFFAF2E4)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  _ProfileHeader(session: session),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StatsCard(
                            summaryAsync: summaryAsync,
                            onRetry: () =>
                                ref.invalidate(rewardSummaryProvider),
                          ),
                          const SizedBox(height: 12),
                          // STREAK-01: chuỗi ngày + kỷ lục thật từ
                          // GET /me/streak — bấm mở màn chi tiết.
                          const _StreakCard(),
                          const SizedBox(height: 16),
                          const _SectionLabel('QUẢN LÝ'),
                          const SizedBox(height: 8),
                          _MenuTile(
                            icon: Icons.backpack_outlined,
                            label: 'Túi đồ & vật phẩm',
                            onTap: () => context.go('/inventory'),
                          ),
                          _MenuTile(
                            icon: Icons.auto_stories_outlined,
                            label: 'Bộ sưu tập bằng chứng',
                            onTap: () => context.go('/collection'),
                          ),
                          // Đảo di sản là sở hữu/trang trí thật — mở cho
                          // mọi learner, không gating demo.
                          _MenuTile(
                            icon: Icons.landscape_outlined,
                            label: 'Đảo di sản',
                            onTap: () => context.go('/island'),
                          ),
                          // GAME-03: Viện Thái Y có backend thật — mở
                          // cho cả real mode (mock gắn nhãn demo).
                          _MenuTile(
                            icon: Icons.bolt_outlined,
                            label: ApiConfig.useMock
                                ? 'Viện Thái Y (demo)'
                                : 'Viện Thái Y — Thể lực',
                            onTap: () => context.go('/energy'),
                          ),
                          // STREAK-01: Ngọn Lửa Hào Khí backend thật.
                          _MenuTile(
                            icon: Icons.local_fire_department_outlined,
                            label: 'Ngọn Lửa Hào Khí — Chuỗi ngày học',
                            onTap: () => context.go('/streak'),
                          ),
                          const SizedBox(height: 16),
                          const _SectionLabel('TÀI KHOẢN'),
                          const SizedBox(height: 8),
                          if (session.status == AuthStatus.guest)
                            _MenuTile(
                              icon: Icons.login_rounded,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.parchmentContainer,
              border: Border.all(color: DauVietColors.imperialGold, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              _name.isNotEmpty ? _name.substring(0, 1).toUpperCase() : 'S',
              style: const TextStyle(
                fontFamily: 'Noto Serif',
                fontWeight: FontWeight.w800,
                color: DauVietColors.cinnabarRed,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: DauVietTypography.headlineSmall.copyWith(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subline,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: summaryAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Column(
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
              height: 40,
              onPressed: onRetry,
            ),
          ],
        ),
        data: (summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'THÀNH TÍCH HỌC TẬP',
              style: DauVietTypography.labelSmall.copyWith(
                color: DauVietColors.inkMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCell(
                  icon: Icons.star_rounded,
                  color: DauVietColors.imperialGold,
                  value: '${summary.exp}',
                  label: 'EXP',
                ),
                _StatCell(
                  icon: Icons.history_edu_rounded,
                  color: DauVietColors.cinnabarRed,
                  value: '${summary.historyPoints}',
                  label: 'Điểm Sử Ký',
                ),
                _StatCell(
                  icon: Icons.school_rounded,
                  color: DauVietColors.natureGreen,
                  value: '${summary.lessonsCompleted}',
                  label: 'Bài học',
                ),
                _StatCell(
                  icon: Icons.workspace_premium_rounded,
                  color: DauVietColors.riverBlue,
                  value: '${summary.itemsOwned}',
                  label: 'Vật phẩm',
                ),
              ],
            ),
          ],
        ),
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
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.cinnabarRed,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: InkWell(
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
          error: (_, __) => Row(
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
                    Text(
                      'CHUỖI NGÀY HỌC',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.inkMuted,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: DauVietTypography.headlineSmall.copyWith(
              fontSize: 17,
              color: DauVietColors.inkText,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: DauVietTypography.labelSmall.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: DauVietTypography.labelSmall.copyWith(
        color: DauVietColors.inkMuted,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? DauVietColors.errorRed : DauVietColors.inkText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DauVietColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: DauVietTypography.labelMedium.copyWith(color: color),
                  ),
                ),
                Icon(
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
