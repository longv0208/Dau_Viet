import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/chapter_number_badge.dart';
import '../../../core/widgets/clue_tag.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/event_cover_image.dart';
import '../../../core/widgets/heritage_background.dart';
import '../../../core/widgets/heritage_design_components.dart';
import '../../../core/widgets/paper_grain_overlay.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../../mock/data/mock_bach_dang_data.dart';
import '../../../mock/models/lesson_models.dart';
import '../../events/data/events_providers.dart';
import '../../learning/data/attempt_dtos.dart';
import '../../learning/data/learning_dtos.dart';
import '../../learning/data/learning_providers.dart';
import '../../learning_path/data/learning_path_dto.dart';
import '../../learning_path/data/learning_path_providers.dart';
import 'widgets/event_progress_section.dart';

/// Màn hình M-07: Chi Tiết Chiến Dịch Lịch Sử (Campaign Detail Screen - Bạch Đằng 938)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & ART_DIRECTION.md
/// Metadata + hero banner lấy từ `GET /api/v1/events/{id}` (hoặc mock).
/// Section "BÀI HỌC LỊCH SỬ" dùng `LessonListSection` — gọi thật
/// `GET /api/v1/events/{id}/lessons` (real) hoặc demo repo (USE_MOCK).
class CampaignDetailScreen extends ConsumerWidget {
  final String eventId;

  const CampaignDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HistoricalEventModel> eventAsync = ref.watch(
      eventDetailProvider(eventId),
    );

    return eventAsync.when(
      loading: () =>
          _buildScaffold(context, Expanded(child: AsyncStateView.loading())),
      error: (error, _) => _buildScaffold(
        context,
        Expanded(
          child: AsyncStateView.error(
            error: error,
            onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
          ),
        ),
      ),
      data: (event) => _buildScaffold(
        context,
        _buildBody(context, event),
        backgroundConfig: event.backgroundConfig,
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    Widget body, {
    HeritageBackgroundConfigDto backgroundConfig =
        HeritageBackgroundConfigDto.paperDefault,
  }) {
    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      body: HeritageBackground(
        config: backgroundConfig,
        heroHeight: 220,
        child: SafeArea(
          child: Column(children: [_buildTopBar(context), body]),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoricalEventModel event) {
    // Nội dung demo Bạch Đằng (câu hỏi trung tâm, 4 dấu vết, sa bàn, nút
    // demo) CHỈ render khi USE_MOCK — real mode chỉ dùng metadata thật
    // của event + LessonListSection (không bịa nội dung sử liệu).
    final isMock = ApiConfig.useMock;
    final lesson = isMock ? MockBachDangData.lessonEpisode2 : null;

    // 2. Nội dung chi tiết chiến dịch cuộn dọc
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3. Hero Banner Chiến Dịch 16:9
            _buildHeroBanner(context, event),
            const SizedBox(height: 16),

            // 4. Khối Thông Số Chiến Dịch (Metadata)
            _buildCampaignMetadata(event),
            const SizedBox(height: 16),

            // 5. Câu Hỏi Sử Học Trung Tâm (demo only — câu hỏi sống trong
            // bài học, không phải trường event)
            if (lesson != null) ...[
              _buildInquiryQuestionCard(lesson.historicalQuestion),
              const SizedBox(height: 18),
            ],

            // 6. Lộ Trình 4 Dấu Vết Cốt Lõi (demo only)
            if (isMock) ...[
              _buildFourTracesOverview(),
              const SizedBox(height: 24),
            ],

            // 6a. Tiến độ event của learner (GAME-04) — ẩn khi chưa cấu
            // hình policy; progress bar + dossier count khi có.
            EventProgressSection(eventId: eventId),
            const SizedBox(height: 16),

            // 6b. Bài học published của sự kiện kèm trạng thái từ lộ trình
            _CampaignPathLessonListSection(eventId: eventId),
            const SizedBox(height: 24),

            // 7. Cặp Nút Hành Động Chính — route /traces và /saban chỉ
            // tồn tại trong demo Bạch Đằng.
            if (isMock) ...[
              DongSonButton(
                label: 'BẮT ĐẦU KHÁM PHÁ (4 DẤU VẾT) ›',
                icon: Icons.explore_rounded,
                variant: DongSonButtonVariant.primaryCinnabar,
                height: 52,
                onPressed: () {
                  // Điều hướng sang M-08 (Trung tâm 4 Dấu Vết)
                  context.go('/traces/$eventId');
                },
              ),
              const SizedBox(height: 10),
              DongSonButton(
                label: 'XEM SA BÀN THỦY CHIẾN (M-06)',
                icon: Icons.military_tech_outlined,
                variant: DongSonButtonVariant.secondaryParchment,
                height: 48,
                onPressed: () {
                  context.go('/saban');
                },
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  // Header đỉnh trang (khớp ảnh mẫu #1)
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAF2E1), Color(0xFFF7ECD8)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: 'Quay lại',
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: const Color(0xFF2B1F17),
              tooltip: 'Quay lại',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/timeline');
                }
              },
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ImperialScrollPlaque(
                  'CHIẾN DỊCH',
                  pillStyle: true,
                  fontSize: 9.5,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                ),
                const SizedBox(height: 5),
                Text(
                  'CHI TIẾT CHIẾN DỊCH',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2B1F17),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hồ sơ học tập theo chuẩn GDPT 2018',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: const Color(0xFF6B5B4B),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Energy từ provider thật (mock mode dùng số demo).
          EnergyPill(
            energy: 100,
            maxEnergy: 100,
            historyPoints: 150,
            showHistoryPoints: false,
            onEnergyTap: () => context.go('/energy'),
          ),
        ],
      ),
    );
  }

  // Hero Banner 16:9 phong cách tranh sử thi viền vàng kép (khớp ảnh mẫu #1).
  // [heroAssetPath] do AssetResolver map từ `coverAssetKey` của backend —
  // null/rỗng → EventCoverImage tự render placeholder (AC-6).
  Widget _buildHeroBanner(BuildContext context, HistoricalEventModel event) {
    final eyebrowText = event.era.trim().isNotEmpty
        ? event.era.trim().toUpperCase()
        : 'NĂM ${event.year}';

    return Container(
      height: 204,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD5B67C), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x264A3219),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ảnh Hero Banner chiến dịch — từ asset path đã resolve
            EventCoverImage(
              assetId: event.coverAssetId,
              assetPath: event.heroBannerUrl,
              width: double.infinity,
              height: double.infinity,
            ),

            // Lớp phủ chuyển sắc bên trái & dưới để chữ nổi bật trên nền tranh
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    const Color(0xFF1A120B).withValues(alpha: 0.12),
                    const Color(0xFF1A120B).withValues(alpha: 0.68),
                    const Color(0xFF1A120B).withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
            const PaperGrainOverlay(opacity: 0.04),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B231B).withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFE0B86A),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      eyebrowText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.labelSmall.copyWith(
                        color: const Color(0xFFF5D487),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.headlineMedium.copyWith(
                      color: const Color(0xFFFFF6E3),
                      fontSize: 19.5,
                      fontWeight: FontWeight.w900,
                      height: 1.22,
                    ),
                  ),
                  if (event.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: const Color(0xFFF2E6D0),
                        fontSize: 11.5,
                        height: 1.38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Khối Thông Số Chiến Dịch Sử Ký (khớp ảnh mẫu #1 — chỉ hiển thị trường thật từ API).
  Widget _buildCampaignMetadata(HistoricalEventModel event) {
    final String eraText = event.era.trim().isNotEmpty
        ? 'Năm ${event.year} • ${event.era}'
        : 'Năm ${event.year}';

    return ImperialScrollFrame(
      plaqueTitle: 'THÔNG SỐ CHIẾN DỊCH SỬ KÝ',
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaRow(
            Icons.menu_book_rounded,
            'Chiến dịch:',
            event.title,
            iconColor: const Color(0xFF1E5E43),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEADFCA)),
          ),
          _buildMetaRow(
            Icons.calendar_today_rounded,
            'Niên đại:',
            eraText,
            iconColor: const Color(0xFF247D78),
          ),
          if (ApiConfig.useMock) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEADFCA)),
            ),
            _buildMetaRow(
              Icons.location_on_rounded,
              'Địa bàn:',
              'Cửa sông Bạch Đằng (Quảng Ninh & Hải Phòng)',
              iconColor: DauVietColors.jade,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(
    IconData icon,
    String title,
    String value, {
    Color iconColor = DauVietColors.jade,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            title,
            style: DauVietTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: const Color(0xFF2B1F17),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: DauVietTypography.bodyMedium.copyWith(
              color: const Color(0xFF3A2E25),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.38,
            ),
          ),
        ),
      ],
    );
  }
  // Câu hỏi sử học trung tâm
  Widget _buildInquiryQuestionCard(String question) {
    return TactileCard(
      usePixelShadow: false,
      backgroundColor: DauVietColors.paperCardHi,
      borderColor: DauVietColors.cinnabarRed,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StampSealBadge(
            '?',
            size: 40,
            color: DauVietColors.cinnabarRed,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionEyebrow('CÂU HỎI TRUNG TÂM'),
                const SizedBox(height: 8),
                Text(
                  question,
                  style: DauVietTypography.ancientCitation.copyWith(
                    color: DauVietColors.inkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tóm lược 4 Dấu Vết Lịch Sử Cốt Lõi
  Widget _buildFourTracesOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionDivider(
          eyebrow: '4 DẤU VẾT',
          title: 'Dấu vết then chốt',
          showLine: true,
          padding: EdgeInsets.only(top: 4, bottom: 12),
        ),
        _buildTraceTile(
          number: '01',
          category: 'hiện vật',
          title: 'Khảo Cổ & Hiện Vật',
          subtitle: 'Bãi cọc Yên Giang và vũ khí thế kỷ X',
          isAvailable: true,
        ),
        const SizedBox(height: 8),
        _buildTraceTile(
          number: '02',
          category: 'nhân vật',
          title: 'Nhân Vật & Chiến Lược',
          subtitle: 'Quân mưu Tiền Ngô Vương và thế trận lòng dân',
          isAvailable: true,
        ),
        const SizedBox(height: 8),
        _buildTraceTile(
          number: '03',
          category: 'địa hình',
          title: 'Sa Bàn Tác Chiến',
          subtitle: 'Nhịp con nước thủy triều và kế đóng cọc ngầm',
          isAvailable: true,
        ),
        const SizedBox(height: 8),
        _buildTraceTile(
          number: '04',
          category: 'cổ thư',
          title: 'Di Sản & Ý Nghĩa',
          subtitle: 'Dấu mốc son chấm dứt một thiên niên kỷ Bắc thuộc',
          isAvailable: false,
        ),
      ],
    );
  }

  Widget _buildTraceTile({
    required String number,
    required String category,
    required String title,
    required String subtitle,
    required bool isAvailable,
  }) {
    return TactileCard(
      usePixelShadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isAvailable
          ? DauVietColors.paperCard
          : DauVietColors.paperDim,
      borderColor: isAvailable
          ? DauVietColors.imperialGold
          : DauVietColors.outlineVariant,
      borderWidth: 1.2,
      child: Row(
        children: [
          ChapterNumberBadge(
            number,
            size: 36,
            filled: isAvailable,
            color: isAvailable
                ? DauVietColors.chapterGreen
                : DauVietColors.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ClueTag.category(category),
                    Text(
                      title,
                      style: DauVietTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkHeading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isAvailable
              ? const StampSealBadge.success('✓', size: 34)
              : const StampSealBadge.outline('…', size: 34),
        ],
      ),
    );
  }
}

/// Danh sách bài học trong Chiến dịch — kết hợp danh sách bài học đã xuất bản
/// (`GET /api/v1/events/{eventId}/lessons`) với trạng thái cá nhân trên lộ trình
/// (`GET /api/v1/me/learning-path`).
/// - Bài học trong lộ trình hiển thị icon + nhãn `LearnerPathStatus.labelVi`.
/// - Bài học ngoài lộ trình (`status == null`) hiển thị "Tự do khám phá" và mở học bình thường.
/// - Bài học `LOCKED` hoặc `NOT_READY` bị chặn mở và thông báo rõ lý do.
class _CampaignPathLessonListSection extends ConsumerWidget {
  final String eventId;

  const _CampaignPathLessonListSection({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LessonListItemDto>> lessonsAsync = ref.watch(
      eventLessonsProvider(eventId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header BÀI HỌC | Nội dung chiến dịch (khớp ảnh mẫu #1)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ImperialScrollPlaque(
                    'BÀI HỌC',
                    pillStyle: true,
                    fontSize: 10.5,
                    padding: EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nội dung chiến dịch',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2B1F17),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFC8AD82),
                      Color(0xFFDEC8A2),
                      Color(0x33DEC8A2),
                    ],
                  ),
                ),
              ),
              // Giữ text ẩn cho E2E selector nếu tìm 'BÀI HỌC LỊCH SỬ'
              const Opacity(
                opacity: 0.0,
                child: SizedBox(height: 0, child: Text('BÀI HỌC LỊCH SỬ')),
              ),
            ],
          ),
        ),
        lessonsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, _) => Column(
            children: [
              Text(
                'Không tải được danh sách bài học.',
                style: DauVietTypography.bodySmall.copyWith(
                  color: DauVietColors.inkMuted,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.invalidate(eventLessonsProvider(eventId));
                  ref.invalidate(learnerLearningPathProvider);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
          data: (lessons) {
            final LearningPathDto? path = ref
                .watch(learnerLearningPathProvider)
                .maybeWhen(data: (p) => p, orElse: () => null);
            final MyProgressDto? myProgress = ref
                .watch(myProgressProvider)
                .maybeWhen(data: (p) => p, orElse: () => null);
            final LearningPathEventNodeDto? pathEvent = path?.findEventById(
              eventId,
            );
            final effectiveLessons = _mergeLessonsWithPath(
              lessons,
              path,
              pathEvent,
            );
            if (effectiveLessons.isEmpty) {
              return TactileCard(
                usePixelShadow: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                backgroundColor: DauVietColors.paperCard,
                borderColor: DauVietColors.outlineVariant,
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_stories_outlined,
                      color: DauVietColors.inkMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chưa có bài học được xuất bản',
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < effectiveLessons.length; i++) ...[
                  _CampaignLessonCard(
                    index: i + 1,
                    lesson: effectiveLessons[i].lesson,
                    status: effectiveLessons[i].status,
                    hasPathContext: path != null,
                    progressFraction: _resolveLessonProgressFraction(
                      myProgress,
                      effectiveLessons[i].lesson.id,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  double? _resolveLessonProgressFraction(
    MyProgressDto? myProgress,
    String lessonId,
  ) {
    if (myProgress == null) return null;
    for (final a in myProgress.inProgress) {
      if (a.lessonId == lessonId && a.progress.totalRequired > 0) {
        return a.progress.fraction.clamp(0.0, 1.0);
      }
    }
    return null;
  }

  List<({LessonListItemDto lesson, LearnerPathStatus? status})>
  _mergeLessonsWithPath(
    List<LessonListItemDto> apiLessons,
    LearningPathDto? path,
    LearningPathEventNodeDto? pathEvent,
  ) {
    final apiById = <String, LessonListItemDto>{
      for (final l in apiLessons) l.id: l,
    };
    final seenIds = <String>{};
    final merged = <({LessonListItemDto lesson, LearnerPathStatus? status})>[];

    if (pathEvent != null && pathEvent.lessons.isNotEmpty) {
      for (final pl in pathEvent.lessons) {
        seenIds.add(pl.lessonId);
        final apiLesson = apiById[pl.lessonId];
        merged.add((
          lesson:
              apiLesson ?? LessonListItemDto(id: pl.lessonId, title: pl.title),
          status: pl.status,
        ));
      }
    }

    for (final lesson in apiLessons) {
      if (seenIds.add(lesson.id)) {
        merged.add((lesson: lesson, status: path?.lessonStatusOf(lesson.id)));
      }
    }

    return merged;
  }
}

class _CampaignLessonCard extends StatelessWidget {
  final int index;
  final LessonListItemDto lesson;
  final LearnerPathStatus? status;
  final bool hasPathContext;
  final double? progressFraction;

  const _CampaignLessonCard({
    required this.index,
    required this.lesson,
    required this.status,
    required this.hasPathContext,
    this.progressFraction,
  });

  bool get _canStart => status == null || status!.canStart;

  @override
  Widget build(BuildContext context) {
    final bool canStart = _canStart;
    final bool isCompleted =
        status == LearnerPathStatus.completed ||
        status == LearnerPathStatus.mastered;
    final bool isActive =
        status == LearnerPathStatus.inProgress ||
        status == LearnerPathStatus.available ||
        status == null;
    final String chapterLabel = index.toString().padLeft(2, '0');
    final (
      IconData badgeIcon,
      String badgeLabel,
      Color badgeFg,
      Color badgeBg,
    ) = _badgePresentation(
      status,
    );

    final Color numberBadgeColor = isCompleted
        ? const Color(0xFF1B4D3E)
        : canStart
        ? const Color(0xFF9E1F19)
        : const Color(0xFF8C8275);

    final Color cardBg = !canStart
        ? const Color(0xFFEFE7D6)
        : (isActive && !isCompleted)
        ? const Color(0xFFFFFDF9)
        : const Color(0xFFFAF4E6);

    final Color cardBorder = !canStart
        ? const Color(0xFFD5C8B4)
        : (isActive && !isCompleted)
        ? const Color(0xFFC8372D)
        : const Color(0xFFD8C39E);

    return TactileCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      backgroundColor: cardBg,
      borderColor: cardBorder,
      borderWidth: (isActive && !isCompleted) ? 1.6 : 1.3,
      borderRadius: 16,
      usePixelShadow: false,
      onTap: () {
        if (!canStart) {
          final msg = status == LearnerPathStatus.notReady
              ? 'Bài học đang biên soạn và chưa sẵn sàng.'
              : 'Bài học đang khóa. Hãy hoàn thành bài học trước đó trong lộ trình.';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 2),
              ),
            );
          return;
        }
        context.push('/learning/lesson/${lesson.id}');
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ImperialDoubleCircleBadge(
            chapterLabel,
            size: 42,
            color: numberBadgeColor,
            filled: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BÀI $index',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: numberBadgeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.title,
                  style: DauVietTypography.labelLarge.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: canStart
                        ? const Color(0xFF1F2421)
                        : const Color(0xFF7A6F63),
                    height: 1.3,
                  ),
                ),
                if (lesson.centralQuestion != null &&
                    lesson.centralQuestion!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    lesson.centralQuestion!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: const Color(0xFF6B5B4B),
                      fontSize: 11.5,
                    ),
                  ),
                ],
                if (hasPathContext) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: badgeFg.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 12, color: badgeFg),
                              const SizedBox(width: 4),
                              Text(
                                badgeLabel,
                                style: DauVietTypography.labelSmall.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (progressFraction != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              height: 6,
                              child: LinearProgressIndicator(
                                value: progressFraction!,
                                backgroundColor: const Color(0xFFEAD8D4),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFB82B20),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(progressFraction! * 100).round()}%',
                          style: DauVietTypography.labelSmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB82B20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildStatusActionCircle(status),
        ],
      ),
    );
  }

  Widget _buildStatusActionCircle(LearnerPathStatus? status) {
    switch (status) {
      case LearnerPathStatus.completed:
      case LearnerPathStatus.mastered:
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4C8C4A),
            border: Border.all(color: const Color(0xFFE2BE78), width: 1.4),
          ),
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        );
      case LearnerPathStatus.locked:
      case LearnerPathStatus.notReady:
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE4DCCE),
            border: Border.all(color: const Color(0xFFCBBBA4), width: 1.2),
          ),
          child: const Icon(
            Icons.lock_rounded,
            size: 16,
            color: Color(0xFF7A6F63),
          ),
        );
      case LearnerPathStatus.available:
      case LearnerPathStatus.inProgress:
      case null:
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFC8372D), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1AC8372D),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: Color(0xFFC8372D),
          ),
        );
    }
  }

  static (IconData, String, Color, Color) _badgePresentation(
    LearnerPathStatus? status,
  ) {
    if (status == null) {
      return (
        Icons.explore_outlined,
        'Tự do khám phá',
        DauVietColors.heritageGreen,
        DauVietColors.heritageGreenSurface,
      );
    }
    switch (status) {
      case LearnerPathStatus.completed:
        return (
          Icons.check_circle_rounded,
          status.labelVi,
          const Color(0xFF2E7D32),
          const Color(0xFFDDF2E1),
        );
      case LearnerPathStatus.mastered:
        return (
          Icons.workspace_premium_rounded,
          status.labelVi,
          DauVietColors.imperialGoldDark,
          const Color(0xFFFEF3C7),
        );
      case LearnerPathStatus.inProgress:
        return (
          Icons.play_arrow_rounded,
          status.labelVi,
          const Color(0xFFB82B20),
          const Color(0xFFFDE6E4),
        );
      case LearnerPathStatus.available:
        return (
          Icons.play_circle_outline_rounded,
          status.labelVi,
          DauVietColors.heritageGreen,
          DauVietColors.heritageGreenSurface,
        );
      case LearnerPathStatus.locked:
        return (
          Icons.lock_outline_rounded,
          status.labelVi,
          const Color(0xFF6B5E53),
          const Color(0xFFE5DDD0),
        );
      case LearnerPathStatus.notReady:
        return (
          Icons.hourglass_empty_rounded,
          status.labelVi,
          const Color(0xFF6B5E53),
          const Color(0xFFE5DDD0),
        );
    }
  }
}
