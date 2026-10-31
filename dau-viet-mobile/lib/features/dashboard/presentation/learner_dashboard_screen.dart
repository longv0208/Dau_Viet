import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_resolver.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/gamification/gamification_widgets.dart';
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../energy/data/energy_providers.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/learning_providers.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../../learning_path/data/learning_path_providers.dart';
import '../../streak/data/streak_providers.dart';

/// Màn hình M-03: Trang Chủ / Bàn Học Tập Người Học (Learner Dashboard & Homepage)
/// Thiết kế Gamification Di Sản Dấu Việt với linh vật Chú Tê Giác:
/// - Top Scenic Hero: Thành cổ cờ đỏ, vịnh thuyền buồm đỏ, Chú Tê Giác vẫy tay chào
/// - Top Bar: Logo Dấu Việt chính thức (`app_logo.png`), 2 Gamified Pills (⚡ Năng lượng, 🔥 Chuỗi ngày) & Chuông thông báo có badge
/// - Thẻ Folder-Tab "Tiếp tục hành trình": Đồng bộ trực tiếp từ `myProgressProvider` & `learnerLearningPathProvider`, ưu tiên ảnh từ DB (`assetId`)
/// - Hàng 4 thẻ Gamification: Thời kỳ lịch sử, Bản đồ di sản, Thành tựu, Kho báu
/// - Banner toàn cảnh: "Khám phá bản đồ Việt Nam"
/// - Carousel ngang: "Bài học nổi bật" (đồng bộ sự kiện/bài học & ảnh bìa từ DB)
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6EFE0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF9F3E6),
              Color(0xFFF5EDE0),
              Color(0xFFF4EBDC),
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Khối Hero Scenic + Top Bar + Lời chào + Thẻ Folder-Tab "Tiếp tục hành trình"
              _buildHeroAndContinueSection(context),
              const SizedBox(height: 14),

              // 2. Các phần nội dung bên dưới có padding ngang 16px
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hàng 4 thẻ chức năng Gamification
                    _buildQuickActionsRow(context),
                    const SizedBox(height: 14),

                    // Banner "Khám phá bản đồ Việt Nam"
                    _buildExploreMapBanner(context),
                    const SizedBox(height: 16),

                    // Khối "Bài học nổi bật" (Carousel ngang lấy từ DB)
                    _buildFeaturedLessonsSection(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  // ===========================================================================
  // 1. TOP SCENIC HERO + CHÚ TÊ GIÁC + THẺ FOLDER-TAB "TIẾP TỤC HÀNH TRÌNH"
  // ===========================================================================
  Widget _buildHeroAndContinueSection(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    final learningPathAsync = ref.watch(learnerLearningPathProvider);

    // Nếu thời kỳ hoặc sự kiện hiện tại trong DB có cấu hình ảnh nền riêng
    // (`backgroundConfig.resolvedAssetId`), có thể lấy từ DB; mặc định dùng
    // tranh thành cổ + vịnh Hạ Long + chú Tê Giác chuẩn mockup.
    final String? dbHeroAssetId = learningPathAsync.maybeWhen(
      data: (path) {
        final target = _resolveJourneyTarget(path);
        return target.period?.backgroundConfig.resolvedAssetId;
      },
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 280 + topInset,
          child: ClipRect(
            child: Stack(
            fit: StackFit.expand,
            children: [
              DbOrBundledImage(
                assetId: dbHeroAssetId,
                bundledPath: 'assets/images/home/home_hero_scenic_bg.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.35),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFF6EFE0).withValues(alpha: 0.0),
                        const Color(0xFFF6EFE0).withValues(alpha: 0.88),
                        const Color(0xFFF6EFE0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: topInset + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildTopBar(context),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(left: 18, right: 158),
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: _buildHeroGreeting(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _buildContinueJourneyCard(context),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo chính thức giữ nguyên theo yêu cầu (`assets/images/app_logo.png`)
        Flexible(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Opacity(
                opacity: 0.0,
                child: Text(
                  'Dấu Việt',
                  style: DauVietTypography.labelSmall.copyWith(fontSize: 1),
                ),
              ),
              Image.asset(
                'assets/images/app_logo.png',
                height: 38,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => Text(
                  'Dấu Việt',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.heritageGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),

        // Cụm phải: ⚡ Energy Pill + 🔥 Streak Pill + Chuông thông báo có badge đỏ
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _EnergyMiniPill(),
                const SizedBox(width: 6),
                const _StreakMiniPill(),
                const SizedBox(width: 6),
                _buildNotificationBellButton(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBellButton(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: 'Thông báo',
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFBF6EC),
              border: Border.all(
                color: const Color(0xFFE4D5BC),
                width: 1.1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18382314),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Thông báo',
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: Color(0xFF2D1E14),
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
        // Badge đỏ "1" góc trên phải như mockup
        Positioned(
          top: -2,
          right: -2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFD62424),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                '1',
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Chào mừng\ntrở lại!',
          style: DauVietTypography.headlineLarge.copyWith(
            fontFamily: DauVietTypography.titleSmall.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF23120B),
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cùng khám phá những câu chuyện\nhào hùng của dân tộc Việt Nam nhé!',
          style: DauVietTypography.bodyMedium.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3E2D21),
            height: 1.32,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. THẺ FOLDER-TAB "TIẾP TỤC HÀNH TRÌNH" (ĐỒNG BỘ DB & PROVIDERS)
  // ===========================================================================
  Widget _buildContinueJourneyCard(BuildContext context) {
    final progressAsync = ref.watch(myProgressProvider);
    final learningPathAsync = ref.watch(learnerLearningPathProvider);
    final assetResolver = ref.watch(assetResolverProvider);

    final inProgress = progressAsync.maybeWhen(
      data: (p) => p.inProgress.isNotEmpty ? p.inProgress.first : null,
      orElse: () => null,
    );

    if (inProgress != null) {
      final resolvedInfo = learningPathAsync.maybeWhen(
        data: (path) {
          final lid = inProgress.lessonId;
          final lesson = (lid != null && lid.isNotEmpty)
              ? path.findLessonById(lid)
              : null;
          final target = _resolveJourneyTarget(path);
          final String? dbAssetId = _extractLessonOrEventAssetId(
            lesson: lesson,
            event: target.event,
            period: target.period,
          );
          final String bundled = _resolveBundledCover(
            assetResolver: assetResolver,
            event: target.event,
            period: target.period,
            fallbackTitle: lesson?.title ?? target.event?.title ?? '',
          );
          return (
            title: lesson?.title,
            dbAssetId: dbAssetId,
            bundledPath: bundled,
          );
        },
        orElse: () => (
          title: null,
          dbAssetId: null,
          bundledPath: 'assets/images/bach_dang_938.jpg',
        ),
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

      return _buildFolderTabCardBody(
        title: (resolvedInfo.title != null &&
                resolvedInfo.title!.trim().isNotEmpty)
            ? resolvedInfo.title!.trim()
            : 'Bài học đang tiếp diễn',
        subtitle: mappedStage.isNotEmpty
            ? 'Giai đoạn: $mappedStage'
            : 'Hành trình đang thực hiện',
        progressFraction: inProgress.progress.fraction,
        progressText:
            '${inProgress.progress.completedRequired}/${inProgress.progress.totalRequired} hoạt động',
        ctaSemanticLabel: 'Tiếp tục học →',
        assetId: resolvedInfo.dbAssetId,
        bundledImagePath: resolvedInfo.bundledPath,
        onCardTap: () =>
            context.go('/learning/attempt/${inProgress.attemptId}'),
        onPlayTap: () =>
            context.go('/learning/attempt/${inProgress.attemptId}'),
      );
    }

    final int completedCount = progressAsync.maybeWhen(
      data: (p) => p.completedCount,
      orElse: () => 0,
    );

    return learningPathAsync.when(
      loading: () => _buildFolderTabCardBody(
        title: 'Đang tải bài học...',
        subtitle: 'Đang đồng bộ dữ liệu',
        progressFraction: 0.0,
        progressText: '—',
        ctaSemanticLabel: 'KHÁM PHÁ NGAY ›',
        assetId: null,
        bundledImagePath: 'assets/images/bach_dang_938.jpg',
        onCardTap: () => context.go('/journey'),
        onPlayTap: () => context.go('/journey'),
      ),
      error: (_, _) => _buildFolderTabCardBody(
        title: 'Khám phá Hành trình Lịch sử',
        subtitle: 'Bắt đầu hành trình lịch sử',
        progressFraction: 0.0,
        progressText: 'Chưa bắt đầu',
        ctaSemanticLabel: 'KHÁM PHÁ NGAY ›',
        assetId: null,
        bundledImagePath: 'assets/images/bach_dang_938.jpg',
        onCardTap: () => context.go('/journey'),
        onPlayTap: () => context.go('/journey'),
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
            fraction = periodProg.completedLessons / periodProg.requiredLessons;
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

          final String? dbAssetId = _extractLessonOrEventAssetId(
            lesson: target.lesson,
            event: event,
            period: target.period,
          );
          final String bundledPath = _resolveBundledCover(
            assetResolver: assetResolver,
            event: event,
            period: target.period,
            fallbackTitle: event.title,
          );

          final String periodRoute =
              (target.period != null && target.period!.code.isNotEmpty)
                  ? '/journey/${target.period!.code}'
                  : '/journey';

          return _buildFolderTabCardBody(
            title: event.title,
            subtitle: subtitle,
            progressFraction: fraction,
            progressText: progressText,
            ctaSemanticLabel: 'KHÁM PHÁ NGAY ›',
            assetId: dbAssetId,
            bundledImagePath: bundledPath,
            onCardTap: () => context.go(periodRoute),
            onPlayTap: () => context.go('/campaign/${event.eventId}'),
          );
        }

        final String periodRoute =
            (target.period != null && target.period!.code.isNotEmpty)
                ? '/journey/${target.period!.code}'
                : '/journey';

        return _buildFolderTabCardBody(
          title: 'Khám phá Hành trình Lịch sử',
          subtitle: 'Bắt đầu hành trình lịch sử',
          progressFraction: 0.0,
          progressText: 'Chưa bắt đầu',
          ctaSemanticLabel: 'KHÁM PHÁ NGAY ›',
          assetId: null,
          bundledImagePath: 'assets/images/bach_dang_938.jpg',
          onCardTap: () => context.go(periodRoute),
          onPlayTap: () => context.go(periodRoute),
        );
      },
    );
  }

  Widget _buildFolderTabCardBody({
    required String title,
    required String subtitle,
    required double progressFraction,
    required String progressText,
    required String ctaSemanticLabel,
    required String? assetId,
    required String bundledImagePath,
    required VoidCallback onCardTap,
    required VoidCallback onPlayTap,
  }) {
    return CustomPaint(
      painter: const FolderTabCardPainter(
        fillColor: Color(0xFFFBF6EC),
        borderColor: Color(0xFFE5D7BE),
        tabHeight: 36.0,
        tabWidthRatio: 0.56,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phần tai Folder-Tab góc trên bên trái
          SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Text(
                'Tiếp tục hành trình',
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF23120B),
                  height: 1.15,
                ),
              ),
            ),
          ),

          // Phần thân thẻ chính
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Vùng bấm mở lộ trình thời kỳ (ảnh thumbnail + tiêu đề + tiến độ)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCardTap,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ảnh minh họa sự kiện/bài học (lấy từ DB nếu có assetId)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 84,
                            height: 68,
                            child: DbOrBundledImage(
                              assetId: assetId,
                              bundledPath: bundledImagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Thông tin tiêu đề + phụ đề + thanh tiến độ xanh
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DauVietTypography.labelLarge.copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF23120B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DauVietTypography.bodySmall.copyWith(
                                  fontSize: 11.5,
                                  color: const Color(0xFF655547),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: GamifiedProgressBar(
                                      value: progressFraction,
                                      height: 8.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      progressText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          DauVietTypography.labelSmall.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF5A4B3E),
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
                ),
                const SizedBox(width: 8),

                // Cột phải: Chevron nhỏ phía trên + Nút Play tròn đỏ phía dưới
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onCardTap,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 4, bottom: 6),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFFC92525),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: ctaSemanticLabel,
                      child: GestureDetector(
                        onTap: onPlayTap,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFE02F2F),
                                Color(0xFFB81818),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x38B81818),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const IgnorePointer(
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              Opacity(
                                opacity: 0.0,
                                child: Text(
                                  ctaSemanticLabel,
                                  style: const TextStyle(fontSize: 1),
                                ),
                              ),
                            ],
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
    );
  }

  // ===========================================================================
  // 3. HÀNG 4 THẺ GAMIFICATION NHANH (THỜI KỲ, BẢN ĐỒ, THÀNH TỰU, KHO BÁU)
  // ===========================================================================
  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildGamifiedActionCard(
            imagePath: 'assets/images/home/icon_scroll_period.png',
            fallbackIcon: Icons.menu_book_rounded,
            label: 'Thời kỳ\nlịch sử',
            semanticAlias: 'Bài học',
            onTap: () => context.go('/journey'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGamifiedActionCard(
            imagePath: 'assets/images/home/icon_map_heritage.png',
            fallbackIcon: Icons.map_rounded,
            label: 'Bản đồ\ndi sản',
            semanticAlias: 'Bản đồ',
            onTap: () => context.go('/map'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGamifiedActionCard(
            imagePath: 'assets/images/home/icon_trophy_achievement.png',
            fallbackIcon: Icons.emoji_events_rounded,
            label: 'Thành tựu',
            semanticAlias: 'Thành tích',
            onTap: () => context.go('/profile'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGamifiedActionCard(
            imagePath: 'assets/images/home/icon_chest_treasure.png',
            fallbackIcon: Icons.inventory_2_rounded,
            label: 'Kho báu',
            semanticAlias: 'Thư viện',
            onTap: () => context.go('/collection'),
          ),
        ),
      ],
    );
  }

  Widget _buildGamifiedActionCard({
    required String imagePath,
    required IconData fallbackIcon,
    required String label,
    required String semanticAlias,
    required VoidCallback onTap,
  }) {
    return TactileCard(
      onTap: onTap,
      usePixelShadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      borderRadius: 16,
      backgroundColor: const Color(0xFFFBF6EC),
      borderColor: const Color(0xFFE5D7BE),
      borderWidth: 1.1,
      child: SizedBox(
        height: 86,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: DbOrBundledImage(
                bundledPath: imagePath,
                fit: BoxFit.contain,
                placeholder: Icon(
                  fallbackIcon,
                  color: DauVietColors.imperialGoldDark,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelMedium.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: const Color(0xFF23120B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. BANNER TOÀN CẢNH "KHÁM PHÁ BẢN ĐỒ VIỆT NAM"
  // ===========================================================================
  Widget _buildExploreMapBanner(BuildContext context) {
    return HeroPaperBanner(
      height: 86,
      padding: EdgeInsets.zero,
      usePixelShadow: false,
      borderRadius: 18,
      borderColor: const Color(0xFFE2D1B3),
      borderWidth: 1.1,
      onTap: () => context.go('/map'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh nền vịnh thuyền buồm đỏ & núi đá vôi (đã xóa nút '>' tĩnh trong ảnh để không bị trùng)
          const Positioned.fill(
            child: DbOrBundledImage(
              bundledPath: 'assets/images/home/map_banner_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Lớp phủ gradient kem ở vùng chữ (chừa thuyền đỏ bên trái 0..10% và vịnh bên phải 55..100%)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFF9EED8).withValues(alpha: 0.0),
                    const Color(0xFFF9EED8).withValues(alpha: 0.94),
                    const Color(0xFFF9EED8).withValues(alpha: 0.88),
                    const Color(0xFFF9EED8).withValues(alpha: 0.0),
                  ],
                  stops: const [0.07, 0.14, 0.46, 0.62],
                ),
              ),
            ),
          ),

          // Nội dung tiêu đề & phụ đề
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 10, 48, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Khám phá bản đồ Việt Nam',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF23120B),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Mở khóa các địa danh lịch sử\ndọc theo hành trình thời gian',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4A3A2C),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          // Nút tròn '>' góc phải
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFDF7EA),
                  border: Border.all(
                    color: const Color(0xFFE4D5BC),
                    width: 1.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF23120B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. CAROUSEL NGANG "BÀI HỌC NỔI BẬT" (ĐỒNG BỘ SỰ KIỆN & ẢNH TỪ DB)
  // ===========================================================================
  Widget _buildFeaturedLessonsSection(BuildContext context) {
    final learningPathAsync = ref.watch(learnerLearningPathProvider);
    final eventsAsync = ref.watch(eventsListProvider);
    final assetResolver = ref.watch(assetResolverProvider);

    final List<_FeaturedCardItem> items = _buildFeaturedItemsFromDb(
      learningPathAsync: learningPathAsync,
      eventsAsync: eventsAsync,
      assetResolver: assetResolver,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: 🔥 Bài học nổi bật + Xem tất cả >
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: DbOrBundledImage(
                      bundledPath: 'assets/images/home/icon_fire_flame.png',
                      fit: BoxFit.contain,
                      placeholder: Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFE8541E),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Bài học nổi bật',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF23120B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Xem tất cả bài học nổi bật',
              child: GestureDetector(
                onTap: () => context.go('/journey'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Xem tất cả',
                        style: DauVietTypography.labelMedium.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC92525),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFFC92525),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Carousel ngang các thẻ bài học/sự kiện nổi bật
        SizedBox(
          height: 188,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return FeaturedLessonCarouselCard(
                title: item.title,
                activitiesLabel: item.activitiesLabel,
                durationLabel: item.durationLabel,
                badgeText: item.badgeText,
                assetId: item.assetId,
                bundledImagePath: item.bundledImagePath,
                onTap: () {
                  if (item.eventId != null && item.eventId!.isNotEmpty) {
                    context.go('/campaign/${item.eventId}');
                  } else {
                    context.go('/journey');
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Tổng hợp danh sách thẻ "Bài học nổi bật" từ DB (`learnerLearningPathProvider`
  /// & `eventsListProvider`), tự động lấy `assetId` từ DB nếu admin đã cấu hình
  /// ảnh bìa cho sự kiện/bài học/thời kỳ.
  List<_FeaturedCardItem> _buildFeaturedItemsFromDb({
    required AsyncValue<LearningPathDto> learningPathAsync,
    required AsyncValue<dynamic> eventsAsync,
    required AssetResolver assetResolver,
  }) {
    final List<_FeaturedCardItem> results = [];
    final Set<String> seenEventIds = {};

    learningPathAsync.whenData((path) {
      // Ưu tiên sự kiện Bạch Đằng 938 đầu tiên (nếu có trong lộ trình DB) để khớp trải nghiệm nổi bật
      final bachDang = path.findEventById('bach-dang-938');
      final List<(LearningPathChapterDto, LearningPathEventNodeDto)> allPairs =
          [];
      for (final ch in path.chapters) {
        for (final ev in ch.events) {
          allPairs.add((ch, ev));
        }
      }

      if (bachDang != null) {
        allPairs.sort((a, b) {
          if (a.$2.eventNodeId == bachDang.eventNodeId) return -1;
          if (b.$2.eventNodeId == bachDang.eventNodeId) return 1;
          return 0;
        });
      }

      for (final (ch, ev) in allPairs) {
        final String key = ev.eventId.isNotEmpty ? ev.eventId : ev.eventNodeId;
        if (key.isEmpty || seenEventIds.contains(key)) continue;
        seenEventIds.add(key);

        final LearningPathLessonNodeDto? firstLesson =
            ev.lessons.isNotEmpty ? ev.lessons.first : null;
        final String? dbAssetId = _extractLessonOrEventAssetId(
          lesson: firstLesson,
          event: ev,
          period: ch,
        );
        final String bundledPath = _resolveBundledCover(
          assetResolver: assetResolver,
          event: ev,
          period: ch,
          fallbackTitle: ev.title,
          cardIndex: results.length,
        );
        final int activityCount =
            ev.lessons.isNotEmpty ? (ev.lessons.length + 2) : 5;
        final String duration =
            activityCount >= 5 ? '10 - 15 phút' : '8 - 12 phút';

        results.add(
          _FeaturedCardItem(
            eventId: ev.eventId,
            title: ev.title,
            activitiesLabel: '$activityCount hoạt động',
            durationLabel: duration,
            badgeText: results.isEmpty ? 'Mới' : null,
            assetId: dbAssetId,
            bundledImagePath: bundledPath,
          ),
        );
      }
    });

    // Bổ sung các thẻ chuẩn thiết kế nếu lộ trình đang tải hoặc có ít hơn 3 sự kiện
    const List<_FeaturedCardItem> defaultShowcases = [
      _FeaturedCardItem(
        eventId: null,
        title: 'Chiến thắng\nBạch Đằng 938',
        activitiesLabel: '5 hoạt động',
        durationLabel: '10 - 15 phút',
        badgeText: 'Mới',
        assetId: null,
        bundledImagePath: 'assets/images/bach_dang_938.jpg',
      ),
      _FeaturedCardItem(
        eventId: null,
        title: 'Nhà Đinh\nthống nhất đất nước',
        activitiesLabel: '4 hoạt động',
        durationLabel: '8 - 12 phút',
        badgeText: null,
        assetId: null,
        bundledImagePath: 'assets/images/home/featured_nha_dinh.jpg',
      ),
      _FeaturedCardItem(
        eventId: null,
        title: 'Khởi nghĩa\nHai Bà Trưng',
        activitiesLabel: '4 hoạt động',
        durationLabel: '8 - 12 phút',
        badgeText: null,
        assetId: null,
        bundledImagePath: 'assets/images/home/featured_hai_ba_trung.jpg',
      ),
    ];

    for (final fallback in defaultShowcases) {
      if (results.length >= 3) break;
      final bool alreadyHasSimilar = results.any(
        (r) =>
            r.title.toLowerCase().contains(
              fallback.title.split('\n').last.toLowerCase(),
            ),
      );
      if (!alreadyHasSimilar) {
        results.add(
          _FeaturedCardItem(
            eventId: fallback.eventId,
            title: fallback.title,
            activitiesLabel: fallback.activitiesLabel,
            durationLabel: fallback.durationLabel,
            badgeText: results.isEmpty ? 'Mới' : null,
            assetId: fallback.assetId,
            bundledImagePath: fallback.bundledImagePath,
          ),
        );
      }
    }

    return results;
  }

  /// Trích xuất UUID ảnh từ DB (`assets` table) theo thứ tự ưu tiên:
  /// 1. `lesson.coverAssetId` / `lesson.coverImageUrl` / `lesson.backgroundConfig`
  /// 2. `event.coverAssetKey` (UUID hoặc key logic ánh xạ sang bảng `assets` trong V50) / `event.backgroundConfig`
  /// 3. `period.coverImageKey` / `period.backgroundConfig`
  String? _extractLessonOrEventAssetId({
    LearningPathLessonNodeDto? lesson,
    LearningPathEventNodeDto? event,
    LearningPathChapterDto? period,
  }) {
    final String? fromLesson =
        HeritageBackgroundConfigDto.extractAssetId(lesson?.coverAssetId) ??
        HeritageBackgroundConfigDto.extractAssetId(lesson?.coverImageUrl) ??
        lesson?.backgroundConfig.resolvedAssetId;
    if (fromLesson != null && fromLesson.isNotEmpty) return fromLesson;

    if (event != null && event.lessons.isNotEmpty) {
      for (final l in event.lessons) {
        final String? lid =
            HeritageBackgroundConfigDto.extractAssetId(l.coverAssetId) ??
            HeritageBackgroundConfigDto.extractAssetId(l.coverImageUrl) ??
            l.backgroundConfig.resolvedAssetId;
        if (lid != null && lid.isNotEmpty) return lid;
      }
    }

    final String? fromEvent =
        HeritageBackgroundConfigDto.extractAssetId(event?.coverAssetKey) ??
        event?.backgroundConfig.resolvedAssetId ??
        _dbSeededAssetIdForSlugOrKey(event?.slug, event?.coverAssetKey);
    if (fromEvent != null && fromEvent.isNotEmpty) return fromEvent;

    final String? fromPeriod =
        HeritageBackgroundConfigDto.extractAssetId(period?.coverImageKey) ??
        period?.backgroundConfig.resolvedAssetId;
    if (fromPeriod != null && fromPeriod.isNotEmpty) return fromPeriod;

    return null;
  }

  /// Ánh xạ các key logic `events/<slug>/hero.jpg` hoặc `slug` sang đúng UUID trong bảng `assets`
  /// của DB (đã seed tại `V50__seed_lesson_cover_assets.sql`) khi sự kiện chưa có bài học con.
  String? _dbSeededAssetIdForSlugOrKey(String? slug, String? coverAssetKey) {
    final String combined =
        '${slug ?? ''} ${coverAssetKey ?? ''}'.trim().toLowerCase();
    if (combined.isEmpty) return null;
    if (combined.contains('bach-dang-938')) {
      return 'd7a70000-0000-4000-8000-000000000011';
    }
    if (combined.contains('hung-vuong')) {
      return 'd7a70000-0000-4000-8000-000000000001';
    }
    if (combined.contains('hai-ba-trung')) {
      return 'd7a70000-0000-4000-8000-000000000002';
    }
    if (combined.contains('thang-long') || combined.contains('ly-thai-to')) {
      return 'd7a70000-0000-4000-8000-000000000004';
    }
    if (combined.contains('nhu-nguyet')) {
      return 'd7a70000-0000-4000-8000-000000000005';
    }
    if (combined.contains('dien-bien-phu')) {
      return 'd7a70000-0000-4000-8000-000000000006';
    }
    return null;
  }

  /// Chọn đường dẫn ảnh bundle cục bộ khi bản ghi DB chưa gắn UUID asset riêng.
  String _resolveBundledCover({
    required AssetResolver assetResolver,
    LearningPathEventNodeDto? event,
    LearningPathChapterDto? period,
    required String fallbackTitle,
    int cardIndex = 0,
  }) {
    final String? byEvent = assetResolver.resolveEventCover(
      event?.coverAssetKey,
      event?.slug,
    );
    if (byEvent != null && byEvent.isNotEmpty) return byEvent;

    final String lower = fallbackTitle.toLowerCase();
    if (lower.contains('bạch đằng') || lower.contains('ngô quyền')) {
      return 'assets/images/bach_dang_938.jpg';
    }
    if (lower.contains('đinh') ||
        lower.contains('thăng long') ||
        lower.contains('lý')) {
      return 'assets/images/home/featured_nha_dinh.jpg';
    }
    if (lower.contains('hai bà trưng') || lower.contains('trưng')) {
      return 'assets/images/home/featured_hai_ba_trung.jpg';
    }
    if (lower.contains('văn lang') ||
        lower.contains('hùng vương') ||
        lower.contains('âu cơ')) {
      return 'assets/images/hung_vuong_village.jpg';
    }

    final String? byPeriod = assetResolver.resolvePeriodCover(
      period?.coverImageKey,
      period?.code,
    );
    if (byPeriod != null && byPeriod.isNotEmpty) return byPeriod;

    const List<String> cycle = [
      'assets/images/bach_dang_938.jpg',
      'assets/images/home/featured_nha_dinh.jpg',
      'assets/images/home/featured_hai_ba_trung.jpg',
    ];
    return cycle[cardIndex % cycle.length];
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
}

class _FeaturedCardItem {
  final String? eventId;
  final String title;
  final String activitiesLabel;
  final String durationLabel;
  final String? badgeText;
  final String? assetId;
  final String bundledImagePath;

  const _FeaturedCardItem({
    required this.eventId,
    required this.title,
    required this.activitiesLabel,
    required this.durationLabel,
    required this.badgeText,
    required this.assetId,
    required this.bundledImagePath,
  });
}

/// Pill ⚡ trên Top Bar — balance Thể lực thật từ `energyProvider` (GAME-03).
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
      child: TactileCard(
        onTap: () => context.push('/energy'),
        usePixelShadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        borderRadius: 999,
        backgroundColor: const Color(0xFFFBF6EC),
        borderColor: const Color(0xFFE4D5BC),
        borderWidth: 1.1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: Color(0xFFE59A18),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    value,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF23120B),
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: 0.0,
              child: Text(
                'Năng lượng',
                style: DauVietTypography.labelSmall.copyWith(fontSize: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill 🔥 trên Top Bar — Chuỗi Ngày Học thật từ `streakProvider` (STREAK-01).
class _StreakMiniPill extends ConsumerWidget {
  const _StreakMiniPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final String value = streakAsync.when(
      data: (s) => '${s.currentStreak} ngày',
      loading: () => '—',
      error: (_, _) => '—',
    );
    return Semantics(
      button: true,
      label: 'Chuỗi ngày học: $value',
      child: TactileCard(
        onTap: () => context.push('/streak'),
        usePixelShadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        borderRadius: 999,
        backgroundColor: const Color(0xFFFBF6EC),
        borderColor: const Color(0xFFE4D5BC),
        borderWidth: 1.1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: Color(0xFFE8541E),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    value,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF23120B),
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: 0.0,
              child: Text(
                'Chuỗi ngày',
                style: DauVietTypography.labelSmall.copyWith(fontSize: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
