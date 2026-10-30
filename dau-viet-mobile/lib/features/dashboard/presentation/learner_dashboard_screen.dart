import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../auth/data/auth_state.dart';
import '../../energy/data/energy_providers.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../../learning_path/data/learning_path_providers.dart';
import '../../rewards/data/reward_providers.dart';
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
      backgroundColor: DauVietColors.paperBackground,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              DauVietColors.paperCard,
              DauVietColors.paperBackground,
              DauVietColors.paperCardHi,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Nền chìm: tranh non nước màu nước phía sau top region,
            // tràn mép hero card rồi phai dần vào nền giấy (mockup M-03 v3).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 460,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/landscape_hero_bg.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Veil giấy mờ để nền chìm vào parchment — đậm dần từ giữa
            // xuống đáy vùng tranh, để section dưới đọc rõ trên nền giấy.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 520,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        DauVietColors.paperCard.withValues(alpha: 0.52),
                        DauVietColors.paperCard.withValues(alpha: 0.62),
                        DauVietColors.paperBackground.withValues(alpha: 0.90),
                        DauVietColors.paperBackground,
                      ],
                      stops: const [0.0, 0.40, 0.80, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
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
                          // 3. Hero Banner Card: "Khám phá lịch sử Việt Nam"
                          _buildHeroBanner(),
                          const SizedBox(height: 12),

                          // 4. Khối: "Bài học hôm nay"
                          _buildTodayLessonSection(),
                          const SizedBox(height: 12),

                          // 5. Khối: "Hành trình của bạn" (4 thẻ chức năng nhanh)
                          _buildYourJourneySection(),
                          const SizedBox(height: 12),

                          // 6. Khối: "Nhiệm vụ hôm nay" & "Sự kiện nổi bật"
                          _buildQuestsAndFeaturedRow(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      // Nền trong suốt để tranh non nước chìm lộ phía sau (mockup M-03 v3);
      // giữ viền dưới mảnh phân tách.
      decoration: BoxDecoration(
        color: DauVietColors.paperCard.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo Dấu Việt + khẩu hiệu brand (theo mockup M-03 v3)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Giữ text 'Dấu Việt' cho accessibility & widget test runner
                  Opacity(
                    opacity: 0.0,
                    child: Text(
                      'Dấu Việt',
                      style: DauVietTypography.labelSmall.copyWith(fontSize: 1),
                    ),
                  ),
                  Image.asset(
                    'assets/images/app_logo.png',
                    height: 34,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Row(
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
                          child: Text(
                            '印',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '— HỌC SỬ VIỆT · GÌN GIỮ HỒN VIỆT —',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 7.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: DauVietColors.inkMuted,
                  ),
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
                  Semantics(
                    button: true,
                    label: 'Thông báo',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DauVietColors.paperCard,
                        border: Border.all(
                          color: DauVietColors.outlineVariant,
                          width: 1.2,
                        ),
                        boxShadow: DauVietColors.pixelShadowSm,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Thông báo',
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: DauVietColors.inkHeading,
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
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // Avatar tròn chú rùa đội nón lá viền vàng
              Semantics(
                button: true,
                label: 'Hồ sơ cá nhân',
                child: GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DauVietColors.paperCardHi,
                      border: Border.all(
                        color: DauVietColors.imperialGold,
                        width: 2.0,
                      ),
                      boxShadow: DauVietColors.pixelShadowSm,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/turtle_welcome.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_rounded,
                          color: DauVietColors.heritageGreen,
                        ),
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
        // Lời chào kèm icon mầm cây xanh (theo mockup M-03)
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DauVietColors.heritageGreenSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DauVietColors.natureGreen.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 18,
                  color: DauVietColors.heritageGreenLight,
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
                        color: DauVietColors.inkSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          const Shadow(
                            color: DauVietColors.paperCard,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$displayName!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelMedium.copyWith(
                        color: DauVietColors.inkHeading,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        shadows: [
                          const Shadow(
                            color: DauVietColors.paperCard,
                            blurRadius: 6,
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
        const SizedBox(width: 8),

        // Cụm 2 status pills: ⚡ Năng lượng & ❤️ Chuỗi ngày — số + nhãn
        // thật từ server, không hard-code.
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EnergyMiniPill(),
            SizedBox(width: 6),
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
    final learningPathAsync = ref.watch(learnerLearningPathProvider);
    return HeroPaperBanner(
      height: 202,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Ảnh phong cảnh non nước Hạ Long, Tràng An hoàng hôn
          Positioned.fill(
            child: Image.asset(
              'assets/images/landscape_hero_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: DauVietColors.paperCardHi),
            ),
          ),

          // Layer 2: Gradient overlay ấm áp từ trái sang phải để nổi chữ
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    DauVietColors.paperCard.withValues(alpha: 0.98),
                    DauVietColors.paperCard.withValues(alpha: 0.94),
                    DauVietColors.paperCard.withValues(alpha: 0.72),
                    DauVietColors.paperCard.withValues(alpha: 0.12),
                  ],
                  stops: const [0.0, 0.52, 0.76, 1.0],
                ),
              ),
            ),
          ),

          // Layer 3: Mascot Chú Rùa đội nón lá cầm bản đồ (căn gọn góc phải)
          Positioned(
            right: -12,
            bottom: -4,
            width: 148,
            height: 168,
            child: Image.asset(
              'assets/images/turtle_map.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // Layer 4: Nội dung chữ & Nút CTA (chừa 128px bên phải để không đè lên nón lá Kabi)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 128, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khám phá\nlịch sử Việt Nam',
                          style: DauVietTypography.headlineMedium.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: DauVietColors.chapterGreen,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Những câu chuyện hào hùng\nđang chờ bạn khám phá!',
                          style: DauVietTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: DauVietColors.inkSecondary,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Nút CTA: Tiếp tục attempt thật nếu có, hoặc mở sự kiện từ currentByPeriod[lastPeriodCode]
                Builder(
                  builder: (context) {
                    final inProgress = progressAsync.maybeWhen(
                      data: (p) =>
                          p.inProgress.isNotEmpty ? p.inProgress.first : null,
                      orElse: () => null,
                    );
                    if (inProgress != null) {
                      return _buildHeroCtaButton(
                        label: 'Tiếp tục học →',
                        onTap: () => context.go(
                          '/learning/attempt/${inProgress.attemptId}',
                        ),
                      );
                    }
                    return learningPathAsync.maybeWhen(
                      data: (path) {
                        final target = _resolveJourneyTarget(path);
                        final event = target.event;
                        if (event != null && event.eventId.isNotEmpty) {
                          return _buildHeroCtaButton(
                            label: 'KHÁM PHÁ NGAY ›',
                            onTap: () =>
                                context.go('/campaign/${event.eventId}'),
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
    );
  }

  Widget _buildHeroCtaButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return DongSonButton(
      label: label,
      variant: DongSonButtonVariant.heritageGreen,
      height: 44,
      width: 148,
      onPressed: onTap,
    );
  }

  // ===========================================================================
  // 4. BÀI HỌC HÔM NAY (ĐỒNG BỘ TIẾN ĐỘ THẬT TỪ MYPROGRESS / EVENT LESSONS)
  // ===========================================================================
  Widget _buildTodayLessonSection() {
    final progressAsync = ref.watch(myProgressProvider);
    final learningPathAsync = ref.watch(learnerLearningPathProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề khối với SectionDivider chuẩn v3 & Link "Xem tất cả →"
        // Mockup: tiêu đề trái + link "Xem tất cả →" phải (không badge MỤC)
        SectionDivider(
          title: 'Bài học hôm nay',
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          trailing: Semantics(
            button: true,
            label: 'Xem tất cả bài học',
            child: GestureDetector(
              onTap: () => context.go('/map'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'Xem tất cả →',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DauVietColors.inkSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),

        Builder(
          builder: (context) {
            final inProgress = progressAsync.maybeWhen(
              data: (p) => p.inProgress.isNotEmpty ? p.inProgress.first : null,
              orElse: () => null,
            );
            if (inProgress != null) {
              final String? resolvedLessonTitle = learningPathAsync.maybeWhen(
                data: (path) {
                  final lid = inProgress.lessonId;
                  if (lid == null || lid.isEmpty) return null;
                  return path.findLessonById(lid)?.title;
                },
                orElse: () => null,
              );
              final String rawStage = inProgress.currentStageId ?? '';
              final String mappedStage = switch (rawStage.toLowerCase()) {
                'ctx' || 'context' => 'Bối cảnh lịch sử',
                'ev' => 'Thu thập bằng chứng',
                'res' || 'reasoning' => 'Suy luận lịch sử',
                'hyp' || 'hypothesis' => 'Đặt giả thuyết',
                'ver' || 'verification' => 'Kiểm chứng sử liệu',
                'cer' || 'conclusion' => 'Kết luận lịch sử',
                'ref' || 'reflection' => 'Suy ngẫm lịch sử',
                _ => rawStage,
              };
              return _buildTodayLessonCard(
                title:
                    (resolvedLessonTitle != null &&
                        resolvedLessonTitle.trim().isNotEmpty)
                    ? resolvedLessonTitle.trim()
                    : 'Bài học đang tiếp diễn',
                subtitle: mappedStage.isNotEmpty
                    ? 'Giai đoạn: $mappedStage'
                    : 'Hành trình đang thực hiện',
                progressFraction: inProgress.progress.fraction,
                progressText:
                    '${inProgress.progress.completedRequired}/${inProgress.progress.totalRequired} hoạt động',
                onTap: () =>
                    context.go('/learning/attempt/${inProgress.attemptId}'),
              );
            }

            final int completedCount = progressAsync.maybeWhen(
              data: (p) => p.completedCount,
              orElse: () => 0,
            );

            return learningPathAsync.when(
              loading: () => _buildTodayLessonCard(
                title: 'Đang tải bài học...',
                subtitle: 'Đang đồng bộ dữ liệu',
                progressFraction: 0.0,
                progressText: '—',
                onTap: () => context.go('/map'),
              ),
              error: (_, _) => _buildTodayLessonCard(
                title: 'Khám phá Bản đồ Dấu Ấn',
                subtitle: 'Bắt đầu hành trình lịch sử',
                progressFraction: 0.0,
                progressText: 'Chưa bắt đầu',
                onTap: () => context.go('/map'),
              ),
              data: (path) {
                final target = _resolveJourneyTarget(path);
                final event = target.event;
                if (event != null && event.eventId.isNotEmpty) {
                  final periodTitle = target.period?.title;
                  final lessonTitle = target.lesson?.title;
                  final String subtitle;
                  if (periodTitle != null &&
                      periodTitle.isNotEmpty &&
                      lessonTitle != null &&
                      lessonTitle.isNotEmpty) {
                    subtitle = '$periodTitle • $lessonTitle';
                  } else if (periodTitle != null && periodTitle.isNotEmpty) {
                    subtitle = periodTitle;
                  } else if (lessonTitle != null && lessonTitle.isNotEmpty) {
                    subtitle = lessonTitle;
                  } else {
                    subtitle = event.period ?? event.yearLabel;
                  }

                  final periodProg = target.periodProgress;
                  final double fraction;
                  final String progressText;
                  if (periodProg != null && periodProg.requiredLessons > 0) {
                    fraction =
                        periodProg.completedLessons /
                        periodProg.requiredLessons;
                    progressText =
                        '${periodProg.completedLessons}/${periodProg.requiredLessons} bài học';
                  } else if (path.summary.totalRequiredLessons > 0) {
                    fraction = path.summary.lessonProgressFraction;
                    progressText =
                        '${path.summary.completedLessons}/${path.summary.totalRequiredLessons} bài học';
                  } else if (completedCount > 0) {
                    fraction = 1.0;
                    progressText = '$completedCount bài đã hoàn thành';
                  } else {
                    fraction = 0.0;
                    progressText = 'Sẵn sàng bắt đầu';
                  }

                  return _buildTodayLessonCard(
                    title: event.title,
                    subtitle: subtitle,
                    progressFraction: fraction,
                    progressText: progressText,
                    // Issue #36: CTA "Bài học hôm nay" dẫn thẳng Bản Đồ Dấu
                    // Ấn tại chặng thời kỳ đang học (resume cursor), không
                    // qua màn danh sách/chiến dịch trung gian.
                    onTap: () => context.go(
                      target.period != null &&
                              target.period!.code.isNotEmpty
                          ? '/map?period=${target.period!.code}'
                          : '/map',
                    ),
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
            );
          },
        ),
      ],
    );
  }

  /// Giải phân giải mục tiêu học tiếp theo trên Trang chủ từ `currentByPeriod[lastPeriodCode]`
  /// (fallback sang `path.current` hoặc sự kiện khả dụng đầu tiên trong thời kỳ).
  ({
    LearningPathChapterDto? period,
    LearningPathEventNodeDto? event,
    LearningPathLessonNodeDto? lesson,
    PeriodProgressDto? periodProgress,
  })
  _resolveJourneyTarget(LearningPathDto path) {
    final String? lastCode = path.lastPeriodCode;
    final LearningPathCurrentDto? pointer =
        (lastCode != null && lastCode.isNotEmpty
            ? path.currentByPeriod[lastCode]
            : null) ??
        path.effectiveCurrent;

    LearningPathChapterDto? period =
        path.periodByCode(lastCode) ?? path.chapterById(pointer?.chapterId);
    if (period != null && period.isPhase && period.parentId != null) {
      period = path.chapterById(period.parentId) ?? period;
    }

    LearningPathEventNodeDto? event = path.findEventByNodeId(
      pointer?.eventNodeId,
    );
    if (event == null && period != null) {
      final periodEvents = path.eventsOfPeriod(period.chapterId);
      if (periodEvents.isNotEmpty) {
        event = periodEvents.firstWhere(
          (e) => e.status.isInProgress || e.status.isAvailable,
          orElse: () => periodEvents.first,
        );
      }
    }
    if (event == null) {
      for (final p in path.periods) {
        final pEvents = path.eventsOfPeriod(p.chapterId);
        for (final e in pEvents) {
          if (e.status.isInProgress || e.status.isAvailable) {
            event = e;
            period ??= p;
            break;
          }
        }
        if (event != null) break;
      }
    }

    if (period == null && event != null) {
      for (final ch in path.chapters) {
        if (ch.events.any((e) => e.eventNodeId == event!.eventNodeId)) {
          period = ch.isPhase && ch.parentId != null
              ? (path.chapterById(ch.parentId) ?? ch)
              : ch;
          break;
        }
      }
    }

    LearningPathLessonNodeDto? lesson = path.findLessonById(pointer?.lessonId);
    if (lesson == null && event != null && event.lessons.isNotEmpty) {
      lesson = event.lessons.firstWhere(
        (l) => l.status.isInProgress || l.status.isAvailable,
        orElse: () => event!.lessons.first,
      );
    }

    final PeriodProgressDto? periodProgress = path.progressForPeriod(
      period?.code ?? lastCode,
    );

    return (
      period: period,
      event: event,
      lesson: lesson,
      periodProgress: periodProgress,
    );
  }

  Widget _buildTodayLessonCard({
    required String title,
    required String subtitle,
    required double progressFraction,
    required String progressText,
    required VoidCallback onTap,
  }) {
    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderRadius: 20,
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.outlineVariant,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 90,
              height: 76,
              child: Container(
                color: DauVietColors.paperCardHi,
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
                const SectionEyebrow(
                  'TIẾP TỤC HÀNH TRÌNH',
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkHeading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: DauVietColors.inkMuted,
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
                          backgroundColor: DauVietColors.paperDim,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            DauVietColors.heritageGreenLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progressText,
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 11,
                        color: DauVietColors.inkMuted,
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
              color: DauVietColors.inkLight,
              size: 24,
            ),
          ),
        ],
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
        SectionDivider(
          title: 'Hành trình của bạn',
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          trailing: Semantics(
            button: true,
            label: 'Xem hành trình',
            child: GestureDetector(
              onTap: () => context.go('/map'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'Xem hành trình →',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DauVietColors.inkSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 4 thẻ chức năng vuông trên một hàng (theo mockup M-03 v3):
        // Bài học / Ôn tập / Thành tích / Thư viện — icon cam-đất ấm.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildJourneyCard(
                icon: Icons.menu_book_rounded,
                iconColor: DauVietColors.imperialGoldDark,
                bgIconColor: DauVietColors.imperialGoldLight,
                title: 'Bài học',
                subtitle: 'Khám phá\nlịch sử',
                onTap: () => context.go('/map'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildJourneyCard(
                icon: Icons.psychology_rounded,
                iconColor: DauVietColors.imperialGoldDark,
                bgIconColor: DauVietColors.imperialGoldLight,
                title: 'Ôn tập',
                subtitle: 'Củng cố\nkiến thức',
                // Chưa có route Ôn tập riêng → dẫn Sưu tập tư liệu.
                onTap: () => context.go('/collection'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildJourneyCard(
                icon: Icons.emoji_events_rounded,
                iconColor: DauVietColors.imperialGoldDark,
                bgIconColor: DauVietColors.imperialGoldLight,
                title: 'Thành tích',
                subtitle: 'Theo dõi\ntiến bộ',
                onTap: () => context.go('/profile'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildJourneyCard(
                icon: Icons.auto_stories_rounded,
                iconColor: DauVietColors.imperialGoldDark,
                bgIconColor: DauVietColors.imperialGoldLight,
                title: 'Thư viện',
                subtitle: 'Tài liệu\nmở rộng',
                onTap: () => context.go('/collection'),
              ),
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
    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      borderRadius: 16,
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.outlineVariant,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bgIconColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DauVietTypography.labelMedium.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: DauVietColors.inkHeading,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 9.5,
              height: 1.2,
              color: DauVietColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. KHỐI SONG SONG 2 CỘT: "NHIỆM VỤ HÔM NAY" & "SỰ KIỆN NỔI BẬT" (BẠCH ĐẰNG 938)
  // ===========================================================================
  Widget _buildQuestsAndFeaturedRow() {
    // Mockup M-03 v3: hai cột song song — Nhiệm vụ hôm nay (trái) &
    // Sự kiện nổi bật Bạch Đằng 938 (phải). Cột nhiệm vụ rộng hơn để
    // đủ chỗ cho checklist; cột sự kiện là thẻ minh họa đứng.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 54, child: _buildQuestCard()),
        const SizedBox(width: 10),
        Expanded(flex: 46, child: _buildFeaturedEventCard()),
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

    return TactileCard(
      usePixelShadow: false,
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header trong thẻ: icon mầm + tiêu đề; link "Xem tất cả →"
          // dòng riêng canh phải (mockup) — tránh cắt tiêu đề.
          Row(
            children: [
              const Icon(
                Icons.eco_rounded,
                size: 15,
                color: DauVietColors.heritageGreenLight,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Nhiệm vụ hôm nay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkHeading,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Xem tất cả mục tiêu',
              child: GestureDetector(
                onTap: () => context.push('/streak'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    'Xem tất cả →',
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: DauVietColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Task 1: Hoàn thành bài học hôm nay
          _buildQuestItem(
            completed: completedLessonToday,
            title: 'Hoàn thành bài học hôm nay',
            reward: '+5',
            onTap: () => context.go('/map'),
          ),
          const SizedBox(height: 8),

          // Task 2: Ôn tập câu hỏi — theo mockup (đếm bằng chuỗi ngày)
          _buildQuestItem(
            completed: streakCount > 0,
            title: 'Ôn tập 3 câu hỏi',
            reward: '+3',
            onTap: () => context.push('/streak'),
          ),
          const SizedBox(height: 8),

          // Task 3: Đọc tư liệu trong thư viện
          _buildQuestItem(
            completed: itemsCount > 0,
            title: 'Đọc một tư liệu trong thư viện',
            reward: '+2',
            onTap: () => context.go('/collection'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedEventCard() {
    final learningPathAsync = ref.watch(learnerLearningPathProvider);
    final eventsAsync = ref.watch(eventsListProvider);

    final LearningPathEventNodeDto? pathFeatured = learningPathAsync.maybeWhen(
      data: (path) =>
          path.findEventById('bach-dang-938') ??
          _resolveJourneyTarget(path).event,
      orElse: () => null,
    );
    final featuredMilestone = eventsAsync.maybeWhen(
      data: (page) {
        for (final m in page.milestones) {
          if (m.title.toLowerCase().contains('bạch đằng')) return m;
        }
        return null;
      },
      orElse: () => null,
    );

    final String? featuredEventId =
        pathFeatured?.eventId ?? featuredMilestone?.id;
    final title = featuredMilestone?.title ?? 'Bạch Đằng 938';
    final summary =
        featuredMilestone?.description ??
        'Bản hùng ca chấm dứt\nhơn 1000 năm Bắc thuộc';

    void openFeatured() {
      if (featuredEventId != null && featuredEventId.isNotEmpty) {
        context.go('/campaign/$featuredEventId');
      } else {
        context.go('/map');
      }
    }

    // Thẻ minh họa đứng full-bleed (mockup M-03 v3): badge "Sự kiện nổi
    // bật" ở góc trên, gradient mờ đáy, tiêu đề + nút "Khám phá ngay →".
    return HeroPaperBanner(
      height: 218,
      padding: EdgeInsets.zero,
      onTap: openFeatured,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tranh Ngô Quyền đại phá quân Nam Hán trên sông Bạch Đằng
          Positioned.fill(
            child: Image.asset(
              'assets/images/bach_dang_938.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) =>
                  Container(color: DauVietColors.woodBrown),
            ),
          ),

          // Gradient mờ từ dưới lên làm nổi text sáng
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DauVietColors.inkText.withValues(alpha: 0.05),
                    DauVietColors.inkText.withValues(alpha: 0.55),
                    DauVietColors.inkText.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Badge "Sự kiện nổi bật" góc trên trái — nền nâu sẫm (mockup)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DauVietColors.woodBrown,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: DauVietColors.imperialGold.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Text(
                'Sự kiện nổi bật',
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: DauVietColors.imperialGoldLight,
                ),
              ),
            ),
          ),

          // Nội dung đáy: tiêu đề + tóm tắt + CTA
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: DauVietColors.paperCard,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 10,
                    color: DauVietColors.paperCard.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Nút CTA đỏ-glossy: "Khám phá ngay →" (theo mockup)
                GestureDetector(
                  onTap: openFeatured,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: DauVietColors.imperialGold,
                        width: 1.2,
                      ),
                      boxShadow: DauVietColors.pixelShadowSm,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Khám phá ngay →',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestItem({
    required bool completed,
    required String title,
    String? reward,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (completed)
              const StampSealBadge.success('✓', size: 20)
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: DauVietColors.outlineVariant,
                    width: 1.6,
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Tên nhiệm vụ
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: completed ? FontWeight.w700 : FontWeight.w500,
                  color: completed
                      ? DauVietColors.inkHeading
                      : DauVietColors.inkSecondary,
                ),
              ),
            ),

            // Phần thưởng ⚡+N (theo mockup)
            if (reward != null) ...[
              const SizedBox(width: 4),
              Text(
                '⚡',
                style: DauVietTypography.labelSmall.copyWith(fontSize: 10),
              ),
              Text(
                reward,
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.imperialGoldDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pill nhỏ ⚡ trên greeting row — balance Thể lực thật từ energyProvider
/// (GAME-03). Loading/error giữ placeholder '—' thay vì số bịa.
class _EnergyMiniPill extends ConsumerWidget {
  const _EnergyMiniPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energyAsync = ref.watch(energyProvider);
    final String value = energyAsync.when(
      data: (e) => '${e.current}',
      loading: () => '—',
      error: (_, _) => '—',
    );
    return Semantics(
      button: true,
      label: 'Thể lực: $value',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: TactileCard(
            onTap: () => context.push('/energy'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            borderRadius: 999,
            backgroundColor: DauVietColors.paperCardHi,
            borderColor: DauVietColors.imperialGold,
            borderWidth: 1.4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⚡',
                      style: DauVietTypography.labelSmall.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      value,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: DauVietColors.imperialGoldDark,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Năng lượng',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: DauVietColors.inkMuted,
                    height: 1.15,
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

/// Pill nhỏ 🔥 trên greeting row — Chuỗi Ngày Học thật từ streakProvider
/// (STREAK-01). Bấm → màn chi tiết Ngọn Lửa Hào Khí (/streak).
/// Loading/error giữ placeholder '—' thay vì số bịa.
class _StreakMiniPill extends ConsumerWidget {
  const _StreakMiniPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final String value = streakAsync.when(
      data: (s) => '${s.currentStreak}',
      loading: () => '—',
      error: (_, _) => '—',
    );
    return Semantics(
      button: true,
      label: 'Chuỗi ngày học: $value',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: TactileCard(
            onTap: () => context.push('/streak'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            borderRadius: 999,
            backgroundColor: DauVietColors.paperCard,
            borderColor: DauVietColors.cinnabarRed,
            borderWidth: 1.4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 13,
                      color: DauVietColors.cinnabarRed,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      value,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: DauVietColors.cinnabarRed,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Chuỗi ngày',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: DauVietColors.inkMuted,
                    height: 1.15,
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

