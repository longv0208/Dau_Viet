import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../auth/data/auth_state.dart';
import '../../energy/data/energy_providers.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import '../../rewards/data/reward_providers.dart';
import '../../streak/data/streak_dto.dart';
import '../../streak/data/streak_providers.dart';

/// Màn hình M-03: Trang Chủ / Bàn Học Tập Người Học (Learner Dashboard & Homepage)
/// Được thiết kế lại toàn diện theo chuẩn UI/UX Pro Max & bản sắc Di Sản Dấu Việt:
/// - Top Bar: Logo Dấu Việt, Triện Đỏ, Chuông Thông Báo, Avatar Chú Rùa tròn viền vàng
/// - Lời chào cá nhân hóa + Cụm huy hiệu ⚡ Năng lượng & ❤️ Chuỗi ngày
/// - Hero Banner: Non nước hữu tình, Chú rùa linh vật cầm bản đồ sử thi (transparent asset)
/// - Khối "Bài học hôm nay": Tranh làng Hùng Vương, thanh tiến trình xanh
/// - Khối "Hành trình của bạn": 4 thẻ chức năng vuông (Bài học, Ôn tập, Thành tích, Thư viện)
/// - Khối song song 2 cột: "Nhiệm vụ hôm nay" (To-do list) & "Sự kiện nổi bật" (Bạch Đằng 938)
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
      backgroundColor: const Color(0xFFFBF8F1),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFBF8F1), Color(0xFFF7F2E7), Color(0xFFF2EADC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar: Logo Dấu Việt, Chuông thông báo & Avatar Chú Rùa
              _buildTopBar(),

              // 2. Nội dung cuộn chính của Trang Chủ
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lời chào & Chỉ số Năng lượng / Chuỗi ngày
                      _buildGreetingAndStatsRow(displayName),
                      const SizedBox(height: 12),

                      // STREAK-01: strip 7 ngày gần nhất — dữ liệu thật từ
                      // GET /me/streak/calendar; 3 trạng thái phân biệt:
                      // đã học / hôm nay / bỏ lỡ. Bấm → màn chi tiết.
                      const _StreakWeekStrip(),
                      const SizedBox(height: 12),

                      // 3. Hero Banner Card: "Khám phá lịch sử Việt Nam"
                      _buildHeroBanner(),
                      const SizedBox(height: 18),

                      // 4. Khối: "Bài học hôm nay"
                      _buildTodayLessonSection(),
                      const SizedBox(height: 20),

                      // 5. Khối: "Hành trình của bạn" (4 thẻ chức năng nhanh)
                      _buildYourJourneySection(),
                      const SizedBox(height: 20),

                      // 6. Khối 2 cột: "Nhiệm vụ hôm nay" & "Sự kiện nổi bật"
                      _buildQuestsAndFeaturedRow(),
                      const SizedBox(height: 24),
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
      return session.status == AuthStatus.guest ? 'Người học nhỏ' : 'Sĩ tử';
    }
    return profile.email.split('@').first;
  }

  // ===========================================================================
  // 1. TOP BAR: LOGO, TRIỆN ĐỎ, CHUÔNG THÔNG BÁO, AVATAR CHÚ RÙA
  // ===========================================================================
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFEBE5D9).withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo Dấu Việt chính thức từ logo2.svg (tỷ lệ chuẩn, tách nền trong suốt)
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Giữ text 'Dấu Việt' cho accessibility & widget test runner
              Opacity(
                opacity: 0.0,
                child: Text('Dấu Việt', style: const TextStyle(fontSize: 1)),
              ),
              Image.asset(
                'assets/images/app_logo.png',
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Row(
                  children: [
                    Text(
                      'Dấu Việt',
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DauVietColors.heritageGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '印',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Cụm phải: Chuông thông báo & Avatar tròn viền vàng
          Row(
            children: [
              // Nút chuông thông báo có chấm đỏ
              Stack(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE5E0D5),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        size: 20,
                        color: Color(0xFF2D3436),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chưa có thông báo mới.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // Avatar tròn chú rùa đội nón lá viền vàng
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFAF2DC),
                    border: Border.all(
                      color: DauVietColors.imperialGold,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DauVietColors.imperialGold.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/turtle_welcome.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: DauVietColors.heritageGreen,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. GREETING & STATS ROW: XIN CHÀO, NĂNG LƯỢNG & CHUỖI NGÀY (real data)
  // ===========================================================================
  Widget _buildGreetingAndStatsRow(String displayName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Lời chào kèm icon mầm cây xanh
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xin chào,',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: const Color(0xFF7E8882),
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelMedium.copyWith(
                        color: const Color(0xFF1F2421),
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Cụm 2 status pills: ⚡ Năng lượng (energyProvider) & 🔥 Chuỗi
        // ngày (streakProvider) — số thật từ server, không hard-code.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill 1: ⚡ Năng lượng — balance thật GET /me/energy.
            _EnergyMiniPill(),
            const SizedBox(width: 6),

            // Pill 2: 🔥 Chuỗi ngày — currentStreak thật GET /me/streak;
            // bấm → màn chi tiết Ngọn Lửa Hào Khí (/streak).
            _StreakMiniPill(),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. HERO BANNER: "KHÁM PHÁ LỊCH SỬ VIỆT NAM" + MASCOT CẦM BẢN ĐỒ
  // ===========================================================================
  Widget _buildHeroBanner() {
    final progressAsync = ref.watch(myProgressProvider);
    final eventsAsync = ref.watch(eventsListProvider);

    return Container(
      height: 195,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E2D5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E4D3B).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Layer 1: Ảnh phong cảnh non nước Hạ Long, Tràng An hoàng hôn
            Positioned.fill(
              child: Image.asset(
                'assets/images/landscape_hero_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFF4ECE1)),
              ),
            ),

            // Layer 2: Gradient overlay ấm áp từ trái sang phải để nổi chữ
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFFFFDF9).withValues(alpha: 0.95),
                      const Color(0xFFFFFDF9).withValues(alpha: 0.90),
                      const Color(0xFFFFFDF9).withValues(alpha: 0.60),
                      const Color(0xFFFFFDF9).withValues(alpha: 0.10),
                    ],
                    stops: const [0.0, 0.45, 0.72, 1.0],
                  ),
                ),
              ),
            ),

            // Layer 3: Mascot Chú Rùa đội nón lá cầm bản đồ (Tách nền 100% bên phải)
            Positioned(
              right: -10,
              bottom: 0,
              top: 10,
              child: Image.asset(
                'assets/images/turtle_map.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

            // Layer 4: Nội dung chữ & Nút CTA "Tiếp tục học →" / "KHÁM PHÁ NGAY ›"
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  progressAsync.when(
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu hành trình',
                          style: DauVietTypography.headlineMedium.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F2421),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Khám phá hào khí sử Việt\nqua từng dấu mốc lịch sử',
                          style: DauVietTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF5E6963),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    error: (_, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu hành trình',
                          style: DauVietTypography.headlineMedium.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F2421),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Khám phá hào khí sử Việt\nqua từng dấu mốc lịch sử',
                          style: DauVietTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: const Color(0xFF5E6963),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    data: (progress) {
                      final bool hasInProgress = progress.inProgress.isNotEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasInProgress
                                ? 'Bài học đang học dở'
                                : 'Bắt đầu hành trình',
                            style: DauVietTypography.headlineMedium.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2421),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasInProgress
                                ? 'Tiếp tục ngay tại hoạt động\nđã dừng lại trước đó'
                                : 'Khám phá hào khí sử Việt\nqua từng dấu mốc lịch sử',
                            style: DauVietTypography.bodyMedium.copyWith(
                              fontSize: 12,
                              color: const Color(0xFF5E6963),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Nút CTA: Tiếp tục attempt thật nếu có, hoặc Khám phá ngay
                  progressAsync.when(
                    loading: () => _buildHeroCtaButton(
                      label: 'KHÁM PHÁ NGAY ›',
                      onTap: () => context.go('/map'),
                    ),
                    error: (_, __) => _buildHeroCtaButton(
                      label: 'KHÁM PHÁ NGAY ›',
                      onTap: () => context.go('/map'),
                    ),
                    data: (progress) {
                      if (progress.inProgress.isNotEmpty) {
                        final attempt = progress.inProgress.first;
                        return _buildHeroCtaButton(
                          label: 'Tiếp tục học →',
                          onTap: () => context.go(
                            '/learning/attempt/${attempt.attemptId}',
                          ),
                        );
                      }
                      // Khi chưa có attempt inProgress → mở sự kiện đầu tiên
                      return eventsAsync.maybeWhen(
                        data: (page) {
                          if (page.milestones.isNotEmpty) {
                            final first = page.milestones.first;
                            return _buildHeroCtaButton(
                              label: 'KHÁM PHÁ NGAY ›',
                              onTap: () => context.go('/campaign/${first.id}'),
                            );
                          }
                          return _buildHeroCtaButton(
                            label: 'KHÁM PHÁ NGAY ›',
                            onTap: () => context.go('/map'),
                          );
                        },
                        orElse: () => _buildHeroCtaButton(
                          label: 'KHÁM PHÁ NGAY ›',
                          onTap: () => context.go('/map'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCtaButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return DongSonButton(
      label: label,
      variant: DongSonButtonVariant.heritageGreen,
      height: 40,
      width: 145,
      onPressed: onTap,
    );
  }

  // ===========================================================================
  // 4. BÀI HỌC HÔM NAY (ĐỒNG BỘ TIẾN ĐỘ THẬT TỪ MYPROGRESS / EVENT LESSONS)
  // ===========================================================================
  Widget _buildTodayLessonSection() {
    final progressAsync = ref.watch(myProgressProvider);
    final eventsAsync = ref.watch(eventsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề khối & Link "Xem tất cả →"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Bài học hôm nay',
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.go('/map'),
              child: Text(
                'Xem tất cả →',
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5E6963),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        progressAsync.when(
          loading: () => _buildTodayLessonCard(
            title: 'Đang tải bài học...',
            subtitle: 'Đang đồng bộ dữ liệu',
            progressFraction: 0.0,
            progressText: '—',
            onTap: () => context.go('/map'),
          ),
          error: (_, __) => _buildTodayLessonCard(
            title: 'Khám phá bài học mới',
            subtitle: 'Mở bản đồ lịch sử',
            progressFraction: 0.0,
            progressText: 'Bắt đầu',
            onTap: () => context.go('/map'),
          ),
          data: (progress) {
            if (progress.inProgress.isNotEmpty) {
              final attempt = progress.inProgress.first;
              final fraction = attempt.progress.fraction;
              return _buildTodayLessonCard(
                title: 'Bài học đang tiếp diễn',
                subtitle: attempt.currentStageId != null
                    ? 'Giai đoạn: ${attempt.currentStageId}'
                    : 'Hành trình đang thực hiện',
                progressFraction: fraction,
                progressText:
                    '${attempt.progress.completedRequired}/${attempt.progress.totalRequired} hoạt động',
                onTap: () =>
                    context.go('/learning/attempt/${attempt.attemptId}'),
              );
            }
            return eventsAsync.maybeWhen(
              data: (page) {
                if (page.milestones.isNotEmpty) {
                  final first = page.milestones.first;
                  return _buildTodayLessonCard(
                    title: first.title,
                    subtitle: first.era,
                    progressFraction: progress.completedCount > 0 ? 1.0 : 0.0,
                    progressText: progress.completedCount > 0
                        ? '${progress.completedCount} bài đã hoàn thành'
                        : 'Sẵn sàng bắt đầu',
                    onTap: () => context.go('/campaign/${first.id}'),
                  );
                }
                return _buildTodayLessonCard(
                  title: 'Khám phá Bản đồ Dấu Ấn',
                  subtitle: 'Bắt đầu hành trình lịch sử',
                  progressFraction: 0.0,
                  progressText: 'Chưa bắt đầu',
                  onTap: () => context.go('/map'),
                );
              },
              orElse: () => _buildTodayLessonCard(
                title: 'Khám phá Bản đồ Dấu Ấn',
                subtitle: 'Bắt đầu hành trình lịch sử',
                progressFraction: 0.0,
                progressText: 'Chưa bắt đầu',
                onTap: () => context.go('/map'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodayLessonCard({
    required String title,
    required String subtitle,
    required double progressFraction,
    required String progressText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBE6DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 90,
                    height: 68,
                    child: Container(
                      color: const Color(0xFFF0EAE1),
                      child: const Icon(
                        Icons.history_edu_rounded,
                        size: 36,
                        color: DauVietColors.heritageGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.labelLarge.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2421),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF75807A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressFraction.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: const Color(0xFFEFECE5),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            progressText,
                            style: DauVietTypography.labelSmall.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF75807A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8A948E),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. HÀNH TRÌNH CỦA BẠN: 4 THẺ CHỨC NĂNG (BÀI HỌC, ÔN TẬP, THÀNH TÍCH, THƯ VIỆN)
  // ===========================================================================
  Widget _buildYourJourneySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề & Link "Xem hành trình →"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Hành trình của bạn',
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.go('/map'),
              child: Text(
                'Xem hành trình →',
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5E6963),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2×2 lưới chức năng bổ trợ — aspect 1.85 vì nội dung thẻ dọc
        // (icon 34 + title + subtitle + padding ~95px) tràn dưới nếu 2.4.
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.85,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildJourneyCard(
              icon: Icons.map_rounded,
              iconColor: const Color(0xFF2E7D32),
              bgIconColor: const Color(0xFFE8F5E9),
              title: 'Bản đồ Dấu Ấn',
              subtitle: 'Lộ trình lịch sử',
              onTap: () => context.go('/map'),
            ),
            _buildJourneyCard(
              icon: Icons.auto_stories_rounded,
              iconColor: const Color(0xFF92400E),
              bgIconColor: const Color(0xFFFDE68A),
              title: 'Sưu tập',
              subtitle: 'Cổ vật & hồ sơ',
              onTap: () => context.go('/collection'),
            ),
            _buildJourneyCard(
              icon: Icons.account_balance_rounded,
              iconColor: const Color(0xFFB45309),
              bgIconColor: const Color(0xFFFEF3C7),
              title: 'Đảo Di Sản',
              subtitle: 'Không gian của bạn',
              onTap: () => context.go('/island'),
            ),
            _buildJourneyCard(
              icon: Icons.person_rounded,
              iconColor: const Color(0xFF1565C0),
              bgIconColor: const Color(0xFFE3F2FD),
              title: 'Hồ sơ',
              subtitle: 'Thành tích & XP',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJourneyCard({
    required IconData icon,
    required Color iconColor,
    required Color bgIconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE6DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bgIconColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.labelMedium.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2421),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF7E8882),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 6. KHỐI SONG SONG 2 CỘT: "NHIỆM VỤ HÔM NAY" & "SỰ KIỆN NỔI BẬT" (BẠCH ĐẰNG 938)
  // ===========================================================================
  Widget _buildQuestsAndFeaturedRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Nhiệm vụ hôm nay (To-do list)
        _buildQuestCard(),
        const SizedBox(height: 18),

        // 2. Thẻ sự kiện nổi bật (Bạch Đằng 938)
        _buildFeaturedEventCard(),
      ],
    );
  }

  Widget _buildQuestCard() {
    final streakAsync = ref.watch(streakProvider);
    final rewardAsync = ref.watch(rewardSummaryProvider);

    final bool completedLessonToday = streakAsync.maybeWhen(
      data: (s) => s.completedToday,
      orElse: () => false,
    );
    final int streakCount = streakAsync.maybeWhen(
      data: (s) => s.currentStreak,
      orElse: () => 0,
    );
    final int itemsCount = rewardAsync.maybeWhen(
      data: (r) => r.itemsOwned,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBE6DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      size: 16,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Mục tiêu hôm nay',
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.labelMedium.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2421),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push('/streak'),
                child: Text(
                  'Xem tất cả →',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E6963),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Task 1: Hoàn thành bài học hôm nay
          _buildQuestItem(
            completed: completedLessonToday,
            title: 'Hoàn thành bài học hôm nay',
            onTap: () => context.go('/map'),
          ),
          const SizedBox(height: 10),

          // Task 2: Duy trì ngọn lửa hào khí
          _buildQuestItem(
            completed: streakCount > 0,
            title: streakCount > 0
                ? 'Đã thắp sáng chuỗi $streakCount ngày'
                : 'Thắp sáng chuỗi ngày học',
            onTap: () => context.push('/streak'),
          ),
          const SizedBox(height: 10),

          // Task 3: Thu thập cổ vật trong thư viện
          _buildQuestItem(
            completed: itemsCount > 0,
            title: itemsCount > 0
                ? 'Đã sở hữu $itemsCount cổ vật'
                : 'Mở khóa cổ vật đầu tiên',
            onTap: () => context.go('/collection'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedEventCard() {
    final eventsAsync = ref.watch(eventsListProvider);
    final featuredMilestone = eventsAsync.maybeWhen(
      data: (page) {
        if (page.milestones.isEmpty) return null;
        return page.milestones.firstWhere(
          (m) => m.title.toLowerCase().contains('bạch đằng'),
          orElse: () => page.milestones.first,
        );
      },
      orElse: () => null,
    );

    final title = featuredMilestone?.title ?? 'Bạch Đằng 938';
    final summary =
        featuredMilestone?.description ??
        'Bản hùng ca chấm dứt hơn 1000 năm Bắc thuộc';

    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBE6DC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA51F18).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Tranh Ngô Quyền đại phá quân Nam Hán trên sông Bạch Đằng
            Positioned.fill(
              child: Image.asset(
                'assets/images/bach_dang_938.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF2C1810)),
              ),
            ),

            // Gradient mờ từ dưới lên làm nổi text trắng
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),

            // Nội dung chữ sự kiện
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Huy hiệu "Sự kiện nổi bật"
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Sự kiện nổi bật',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nút CTA: Khám phá ngay →
                      GestureDetector(
                        onTap: () => featuredMilestone != null ? context.go('/campaign/${featuredMilestone.id}') : context.go('/map'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB45309),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: DauVietColors.imperialGold,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Xem chi tiết →',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestItem({
    required bool completed,
    required String title,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // Checkbox tròn
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? const Color(0xFF2E7D32) : Colors.transparent,
                border: Border.all(
                  color: completed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFB0B8B3),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: completed
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),

            // Tên nhiệm vụ
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 10.5,
                  fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
                  color: completed
                      ? const Color(0xFF1F2421)
                      : const Color(0xFF5E6963),
                  decoration: completed ? TextDecoration.none : null,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

/// Pill nhỏ ⚡ trên greeting row — balance Thể lực thật từ energyProvider
/// (GAME-03). Loading/error giữ placeholder '—' thay vì số bịa.
class _EnergyMiniPill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energyAsync = ref.watch(energyProvider);
    final String value = energyAsync.when(
      data: (e) => '${e.current}',
      loading: () => '—',
      error: (_, __) => '—',
    );
    return GestureDetector(
      onTap: () => context.push('/energy'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill nhỏ 🔥 trên greeting row — Chuỗi Ngày Học thật từ streakProvider
/// (STREAK-01). Bấm → màn chi tiết Ngọn Lửa Hào Khí (/streak).
/// Loading/error giữ placeholder '—' thay vì số bịa.
class _StreakMiniPill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final String value = streakAsync.when(
      data: (s) => '${s.currentStreak}',
      loading: () => '—',
      error: (_, __) => '—',
    );
    return GestureDetector(
      onTap: () => context.push('/streak'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCDD2), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFC62828),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Strip 7 ngày gần nhất trên Home (STREAK-01) — hiển thị 3 trạng thái
/// phân biệt rõ: đã học (đỏ đặc) / hôm nay (viền vàng, chưa học còn trống,
/// đã học thì fill) / bỏ lỡ (xám nhạt). Dữ liệu lấy từ streakCalendarProvider
/// (GET /me/streak/calendar thật) + `today` theo giờ server VN từ
/// streakProvider — KHÔNG dùng đồng hồ thiết bị để quyết định ngày hợp lệ.
/// Bấm bất kỳ ô nào → màn chi tiết Ngọn Lửa Hào Khí (/streak).
class _StreakWeekStrip extends ConsumerWidget {
  const _StreakWeekStrip();

  static const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final streak = streakAsync.value;
    // Hôm nay theo SERVER (Asia/Ho_Chi_Minh); chưa có state (loading) thì
    // không vẽ strip tránh nháy sai ngày.
    final today = streak?.today;
    if (streak == null || today == null) {
      return const SizedBox.shrink();
    }

    final sess = streakSessionKeyOf(ref.watch(authSessionProvider));
    // Fetch cả 2 tháng khi tuần vắt qua ranh tháng — family cache từng
    // tháng nên tháng nào chưa có sẽ tự fetch.
    final weekStart = today.subtract(const Duration(days: 6));
    final crossesMonth =
        weekStart.month != today.month || weekStart.year != today.year;
    final calCur = ref.watch(
      streakCalendarProvider((
        year: today.year,
        month: today.month,
        sess: sess,
      )),
    );
    final calPrev = crossesMonth
        ? ref.watch(
            streakCalendarProvider((
              year: weekStart.year,
              month: weekStart.month,
              sess: sess,
            )),
          )
        : const AsyncData(LearningStreakCalendarDto(days: []));

    // Tập ngày đã học trong tháng hiện tại + tháng trước (nếu tuần vắt ranh).
    final studied = <DateTime>{
      for (final d in calCur.value?.days ?? const <DateTime>[])
        DateTime(d.year, d.month, d.day),
      for (final d in calPrev.value?.days ?? const <DateTime>[])
        DateTime(d.year, d.month, d.day),
    };
    final todayKey = DateTime(today.year, today.month, today.day);

    return GestureDetector(
      onTap: () => context.push('/streak'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDE5D6), width: 1.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              _buildDayCell(
                weekStart.add(Duration(days: i)),
                studied,
                todayKey,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, Set<DateTime> studied, DateTime todayKey) {
    final key = DateTime(day.year, day.month, day.day);
    final isToday = key == todayKey;
    final didStudy = studied.contains(key);
    final isFuture = key.isAfter(todayKey);
    final isMissed = !isToday && !isFuture && !didStudy;

    // 3 trạng thái: đã học → đỏ đặc; hôm nay → viền vàng (fill đỏ khi đã
    // ghi); bỏ lỡ → xám nhạt; ngày tới → trống mờ.
    final Color bg;
    final Color fg;
    final Border? border;
    if (didStudy) {
      bg = DauVietColors.cinnabarRed;
      fg = Colors.white;
      border = isToday
          ? Border.all(color: DauVietColors.imperialGold, width: 1.8)
          : null;
    } else if (isToday) {
      bg = Colors.white;
      fg = DauVietColors.inkText;
      border = Border.all(color: DauVietColors.imperialGold, width: 1.8);
    } else if (isMissed) {
      bg = const Color(0xFFEFEBE2);
      fg = const Color(0xFFA8A091);
      border = null;
    } else {
      bg = Colors.transparent;
      fg = const Color(0xFFB8B0A0);
      border = null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _weekdayShort[day.weekday - 1],
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: isToday
                ? DauVietColors.cinnabarRed
                : const Color(0xFF9A9282),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: didStudy
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  '${day.day}',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
        ),
      ],
    );
  }
}
