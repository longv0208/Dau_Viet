import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/main-bottom-nav.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../auth/data/auth_state.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/attempt_dtos.dart';
import '../../learning/data/learning_providers.dart';

/// Màn hình M-03: Bàn Học Tập Người Học (Learner Dashboard & Resume Card)
/// Resume card hiển thị attempt IN_PROGRESS thật từ `GET /me/progress`
/// (hoặc demo repo khi USE_MOCK) — không hard-code tiến độ.
class LearnerDashboardScreen extends ConsumerStatefulWidget {
  const LearnerDashboardScreen({super.key});

  @override
  ConsumerState<LearnerDashboardScreen> createState() =>
      _LearnerDashboardScreenState();
}

class _LearnerDashboardScreenState
    extends ConsumerState<LearnerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final AuthState session = ref.watch(authSessionProvider);
    final String displayName = _displayName(session);

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
          child: Column(
            children: [
              // 1. Top Bar: Hồ Sơ Sĩ Tử & Chỉ Số Sinh Lực
              _buildTopHeader(displayName),

              // 2. Nội dung cuộn chính của Bàn Học Tập
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lời chào & Huy hiệu ngày học
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào $displayName,',
                                  style: DauVietTypography.bodySmall.copyWith(
                                    color: DauVietColors.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Học tập',
                                  style: DauVietTypography.headlineMedium
                                      .copyWith(
                                        color: DauVietColors.cinnabarRed,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Chuỗi ngày học — chỉ hiện số demo khi USE_MOCK;
                          // backend chưa trả streak nên real mode chỉ gắn nhãn.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: DauVietColors.parchmentContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: DauVietColors.imperialGold,
                                width: 1.2,
                              ),
                              boxShadow: DauVietColors.heritageShadow,
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ApiConfig.useMock ? '3 ngày' : 'Sắp có',
                                  style: DauVietTypography.labelMedium.copyWith(
                                    color: DauVietColors.inkText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. Hero Resume Card: attempt IN_PROGRESS thật
                      // (refetch mỗi lần dashboard hiện — vừa học xong quay
                      // về sẽ thấy tiến độ mới nhất).
                      _buildResumeCard(),
                      const SizedBox(height: 24),

                      // 4. Bắt đầu từ đây — card sự kiện PUBLISHED đầu tiên
                      // cho người mới hiểu ngay ứng dụng học gì (P1-01).
                      Text(
                        'BẮT ĐẦU TỪ ĐÂY',
                        style: DauVietTypography.labelMedium.copyWith(
                          color: DauVietColors.inkMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFirstEventCard(),
                      const SizedBox(height: 24),

                      // 5. Khối Lối Tắt Nhanh — chỉ đích đến nội dung thật;
                      // màn demo (Sa Bàn/Timeline) ẩn ở real mode (P1-06).
                      Text(
                        'KHÁM PHÁ THÊM',
                        style: DauVietTypography.labelMedium.copyWith(
                          color: DauVietColors.inkMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickShortcuts(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  String _displayName(AuthState session) {
    final profile = session.profile;
    if (profile == null || profile.email.isEmpty) {
      return session.status == AuthStatus.guest ? 'Sĩ tử Khách' : 'Sĩ tử';
    }
    return profile.email.split('@').first;
  }

  // Top Bar với Avatar và EnergyPill
  Widget _buildTopHeader(String displayName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar Sĩ tử tròn viền vàng
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.parchmentContainer,
              border: Border.all(color: DauVietColors.imperialGold, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              displayName.isNotEmpty
                  ? displayName.substring(0, 1).toUpperCase()
                  : 'S',
              style: const TextStyle(
                fontFamily: 'Noto Serif',
                fontWeight: FontWeight.w800,
                color: DauVietColors.cinnabarRed,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sĩ tử $displayName',
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ApiConfig.useMock
                      ? 'Cấp độ 5 • Tập sự Sử ký'
                      : 'Học viên Dấu Việt',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.natureGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Energy/điểm chỉ là số liệu demo — ẩn hoàn toàn ở real mode
          // thay vì hiển thị số dư giả cho learner thật.
          if (ApiConfig.useMock)
            GestureDetector(
              onTap: () {
                context.go('/energy');
              },
              child: const EnergyPill(
                energy: 100,
                maxEnergy: 100,
                historyPoints: 150,
              ),
            ),
        ],
      ),
    );
  }

  // Resume Card: attempt IN_PROGRESS đầu tiên từ /me/progress.
  // Không có attempt → card mời khám phá sự kiện (mock → gắn nhãn demo).
  Widget _buildResumeCard() {
    // Dashboard hiển thị → invalidate để quay về từ player thấy tiến độ mới.
    // (build() gọi lại khi watch đổi — FutureProvider chỉ refetch một lần
    // vì invalidate giữa hai watch của cùng một frame không lặp vô hạn:
    // chỉ chạy khi widget được khởi tạo lại sau điều hướng.)
    final progressAsync = ref.watch(myProgressProvider);

    return progressAsync.when(
      loading: () => ParchmentCard(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, st) => _discoverCard(
        title: 'Khám phá sự kiện',
        subtitle: 'Không tải được tiến độ — chọn một sự kiện để học',
      ),
      data: (progress) {
        if (progress.inProgress.isEmpty) {
          return _discoverCard(
            title: 'Bắt đầu hành trình',
            subtitle: 'Chọn một sự kiện lịch sử để khám phá',
            progressText: 'Đã hoàn thành ${progress.completedCount} bài học',
          );
        }
        final AttemptSummaryDto attempt = progress.inProgress.first;
        final double fraction = attempt.progress.fraction;
        final String pct = (fraction * 100).round().toString();
        return _resumeShell(
          title: 'Bài học đang học dở',
          subtitle: 'Tiếp tục ngay tại hoạt động đã dừng lại',
          progressText:
              '$pct% (${attempt.progress.completedRequired}/${attempt.progress.totalRequired} hoạt động)',
          fraction: fraction,
          buttonLabel: 'TIẾP TỤC BÀI HỌC ›',
          onPressed: () => context.go('/learning/attempt/${attempt.attemptId}'),
        );
      },
    );
  }

  /// Card mời khám phá khi chưa có attempt IN_PROGRESS (hoặc progress lỗi).
  /// Không hard-code event — dùng event PUBLISHED đầu tiên, ẩn CTA nếu
  /// chưa có event nào thay vì điều hướng tới id giả.
  Widget _discoverCard({
    required String title,
    required String subtitle,
    String? progressText,
  }) {
    final eventsAsync = ref.watch(eventsListProvider);
    return eventsAsync.when(
      loading: () => _resumeShell(
        title: title,
        subtitle: subtitle,
        progressText: progressText,
        buttonLabel: 'ĐANG TẢI...',
        onPressed: () {},
      ),
      error: (_, _) => _resumeShell(
        title: title,
        subtitle: 'Không tải được danh sách sự kiện. Thử lại sau.',
        progressText: progressText,
        buttonLabel: 'THỬ LẠI ›',
        onPressed: () => ref.invalidate(eventsListProvider),
      ),
      data: (page) {
        if (page.milestones.isEmpty) {
          return _resumeShell(
            title: title,
            subtitle: 'Chưa có sự kiện nào được xuất bản.',
            progressText: progressText,
            buttonLabel: 'CHƯA CÓ SỰ KIỆN',
            onPressed: () {},
          );
        }
        final first = page.milestones.first;
        return _resumeShell(
          title: title,
          subtitle: subtitle,
          progressText: progressText,
          buttonLabel: 'KHÁM PHÁ NGAY ›',
          onPressed: () => context.go('/campaign/${first.id}'),
        );
      },
    );
  }

  Widget _resumeShell({
    required String title,
    required String subtitle,
    required String? progressText,
    required String buttonLabel,
    required VoidCallback onPressed,
    double fraction = 0,
  }) {
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DauVietColors.cinnabarRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                // Mock mode → gắn nhãn rõ đây là nội dung demo.
                ApiConfig.useMock ? 'BÀI HỌC • DEMO' : 'BÀI HỌC',
                style: DauVietTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: DauVietTypography.headlineMedium.copyWith(
              color: DauVietColors.cinnabarRed,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: DauVietTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (progressText != null) ...[
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Tiến độ hoàn thành',
                        style: DauVietTypography.bodySmall,
                      ),
                    ),
                    Text(
                      progressText,
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.cinnabarRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: DauVietColors.parchmentHigh,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      DauVietColors.cinnabarRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          DongSonButton(
            label: buttonLabel,
            icon: Icons.play_arrow_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            height: 48,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  /// Card "Bắt đầu từ đây": sự kiện PUBLISHED đầu tiên từ `GET /api/v1/events`
  /// (hoặc demo repo khi USE_MOCK) — người mới thấy ngay nội dung học thật.
  /// Không hard-code eventId; không có event → hướng sang tab Khám phá.
  Widget _buildFirstEventCard() {
    final eventsAsync = ref.watch(eventsListProvider);
    return eventsAsync.when(
      loading: () => const ParchmentCard(
        padding: EdgeInsets.all(18),
        child: SizedBox(
          height: 72,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => _shortcutCard(
        icon: Icons.explore_rounded,
        color: DauVietColors.riverBlue,
        title: 'Khám phá bản đồ dấu ấn',
        subtitle: 'Mở các chặng đường lịch sử đã mở khoá',
        onTap: () => context.go('/map'),
      ),
      data: (page) {
        if (page.milestones.isEmpty) {
          return _shortcutCard(
            icon: Icons.explore_rounded,
            color: DauVietColors.riverBlue,
            title: 'Khám phá bản đồ dấu ấn',
            subtitle: 'Chưa có sự kiện nào được xuất bản',
            onTap: () => context.go('/map'),
          );
        }
        final first = page.milestones.first;
        return ParchmentCard(
          padding: const EdgeInsets.all(16),
          onTap: () => context.go('/campaign/${first.id}'),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DauVietColors.parchmentContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DauVietColors.imperialGold),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: DauVietColors.cinnabarRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.title,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vào chiến dịch đầu tiên của bạn',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: DauVietColors.inkMuted,
              ),
            ],
          ),
        );
      },
    );
  }

  // Khối lối tắt khám phá — chỉ điểm đến nội dung thật; các màn demo
  // (Sa Bàn, Timeline tường thuật) chỉ hiển thị khi USE_MOCK (P1-06).
  Widget _buildQuickShortcuts() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _shortcutCard(
                icon: Icons.map_rounded,
                color: DauVietColors.riverBlue,
                title: 'Khám phá',
                subtitle: 'Bản đồ hành trình đã mở khoá',
                onTap: () => context.go('/map'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _shortcutCard(
                icon: Icons.auto_stories_rounded,
                color: DauVietColors.natureGreen,
                title: 'Sưu tập',
                subtitle: 'Bằng chứng đã thu thập',
                onTap: () => context.go('/collection'),
              ),
            ),
          ],
        ),
        if (ApiConfig.useMock) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _shortcutCard(
                  icon: Icons.military_tech_rounded,
                  color: DauVietColors.cinnabarRed,
                  title: 'Sa Bàn (demo)',
                  subtitle: 'Diễn biến Bạch Đằng 938',
                  onTap: () => context.go('/saban'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _shortcutCard(
                  icon: Icons.timeline_rounded,
                  color: DauVietColors.imperialGold,
                  title: 'Niên biểu (demo)',
                  subtitle: 'Dòng thời gian các triều đại',
                  onTap: () => context.go('/timeline'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _shortcutCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ParchmentCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: DauVietTypography.labelMedium),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: DauVietTypography.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
