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
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/paper_grain_overlay.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/section_eyebrow.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../../mock/data/mock_bach_dang_data.dart';
import '../../../mock/models/lesson_models.dart';
import '../../events/data/events_providers.dart';
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
      data: (event) => _buildScaffold(context, _buildBody(context, event)),
    );
  }

  Widget _buildScaffold(BuildContext context, Widget body) {
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
        child: SafeArea(child: Column(children: [_buildTopBar(context), body])),
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

  // Header đỉnh trang
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.paperBackground,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Quay lại',
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: DauVietColors.inkText,
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
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionEyebrow(
                  'CHIẾN DỊCH',
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  'CHI TIẾT CHIẾN DỊCH',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 16,
                    color: DauVietColors.inkHeading,
                  ),
                ),
                Text(
                  'Hồ sơ sử liệu chuẩn giáo dục GDPT 2018',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Energy/điểm sử ký từ provider thật (mock mode dùng số demo).
          EnergyPill(
            energy: 100,
            maxEnergy: 100,
            historyPoints: 150,
            onEnergyTap: () => context.go('/energy'),
          ),
        ],
      ),
    );
  }

  // Hero Banner 16:9 phong cách tranh khắc gỗ di sản.
  // [heroAssetPath] do AssetResolver map từ `coverAssetKey` của backend —
  // null/rỗng → EventCoverImage tự render placeholder (AC-6).
  Widget _buildHeroBanner(BuildContext context, HistoricalEventModel event) {
    final eyebrowText = event.era.trim().isNotEmpty
        ? '${event.era} • NĂM ${event.year}'
        : 'SỰ KIỆN • NĂM ${event.year}';

    return HeroPaperBanner(
      height: 200,
      padding: EdgeInsets.zero,
      showGrain: true,
      eyebrow: eyebrowText,
      title: event.title,
      subtitle: event.summary,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ảnh Hero Banner chiến dịch — từ asset path đã resolve
          EventCoverImage(
            assetPath: event.heroBannerUrl,
            width: double.infinity,
            height: double.infinity,
          ),

          // Lớp phủ thông tin chữ vàng trên nền khói sóng
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DauVietColors.inkHeading.withValues(alpha: 0.08),
                  DauVietColors.inkHeading.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          const PaperGrainOverlay(opacity: 0.05),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionEyebrow(
                  eyebrowText,
                  color: DauVietColors.imperialGold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  style: DauVietTypography.headlineMedium.copyWith(
                    color: DauVietColors.imperialGold,
                    fontSize: 18,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                // Tóm tắt chiến dịch từ backend (HistoricalEventModel.summary)
                Text(
                  event.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.paperCard,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khối Thông Số Chiến Dịch (Metadata).
  // Thời gian/Địa bàn lấy từ API (event.year / summary); phần chỉ huy/đối thủ/
  // chi phí chưa có trường backend — giữ copy mô tả cho tới task mở rộng DTO.
  Widget _buildCampaignMetadata(HistoricalEventModel event) {
    return TactileCard(
      usePixelShadow: false,
      backgroundColor: DauVietColors.paperCard,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THÔNG SỐ CHIẾN DỊCH SỬ KÝ',
            style: DauVietTypography.labelSmall.copyWith(
              color: DauVietColors.inkMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetaRow(
            Icons.auto_stories_rounded,
            'Chiến dịch:',
            event.title,
            iconColor: DauVietColors.heritageGreen,
          ),
          const SizedBox(height: 8),
          _buildMetaRow(
            Icons.calendar_today_rounded,
            'Niên đại:',
            'Năm ${event.year} • ${event.era}',
            iconColor: DauVietColors.jade,
          ),
          const SizedBox(height: 8),
          // Địa bàn/Chỉ huy/Đối thủ/Chi phí là copy demo Bạch Đằng — chưa
          // có trường backend, chỉ render trong USE_MOCK.
          if (ApiConfig.useMock) ...[
            _buildMetaRow(
              Icons.location_on_rounded,
              'Địa bàn:',
              'Cửa sông Bạch Đằng (Quảng Ninh & Hải Phòng)',
              iconColor: DauVietColors.jade,
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.shield_rounded,
              'Chỉ huy Ta:',
              'Tiền Ngô Vương Ngô Quyền (Ái Châu)',
              iconColor: DauVietColors.heritageGreen,
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.dangerous_rounded,
              'Đối thủ:',
              'Vạn sứ quân Nam Hán dưới trướng Lưu Hoằng Tháo',
              iconColor: DauVietColors.heritageGreen,
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.bolt_rounded,
              'Chi phí:',
              '⚡ 20 Thể lực  •  Nhận 150 Điểm Sử Ký + 50 XP',
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
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: DauVietTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: DauVietColors.inkHeading,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
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
        const SectionDivider(
          eyebrow: 'BÀI HỌC',
          title: 'Nội dung chiến dịch',
          padding: EdgeInsets.only(top: 4, bottom: 12),
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
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
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

  const _CampaignLessonCard({
    required this.index,
    required this.lesson,
    required this.status,
    required this.hasPathContext,
  });

  bool get _canStart => status == null || status!.canStart;

  @override
  Widget build(BuildContext context) {
    final bool canStart = _canStart;
    final bool isCompleted =
        status == LearnerPathStatus.completed ||
        status == LearnerPathStatus.mastered;
    final String chapterLabel = index.toString().padLeft(2, '0');
    final (
      IconData badgeIcon,
      String badgeLabel,
      Color badgeFg,
      Color badgeBg,
    ) = _badgePresentation(
      status,
    );

    return TactileCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: canStart
          ? DauVietColors.paperCard
          : DauVietColors.paperDim,
      borderColor: canStart
          ? DauVietColors.imperialGold
          : DauVietColors.outlineVariant,
      borderWidth: 1.4,
      usePixelShadow: canStart,
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
        children: [
          ChapterNumberBadge(
            chapterLabel,
            size: 32,
            filled: isCompleted,
            color: canStart
                ? DauVietColors.chapterGreen
                : DauVietColors.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: canStart
                        ? DauVietColors.inkText
                        : DauVietColors.inkMuted,
                  ),
                ),
                if (lesson.centralQuestion != null &&
                    lesson.centralQuestion!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lesson.centralQuestion!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (hasPathContext) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: badgeFg.withValues(alpha: 0.35),
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
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusSeal(status),
        ],
      ),
    );
  }

  Widget _buildStatusSeal(LearnerPathStatus? status) {
    switch (status) {
      case LearnerPathStatus.completed:
      case LearnerPathStatus.mastered:
        return const StampSealBadge.success('✓', size: 34);
      case LearnerPathStatus.locked:
      case LearnerPathStatus.notReady:
        return const StampSealBadge.outline('…', size: 34);
      case LearnerPathStatus.available:
      case LearnerPathStatus.inProgress:
      case null:
        return const StampSealBadge(
          'MỞ',
          size: 34,
          color: DauVietColors.cinnabarRed,
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
          DauVietColors.natureGreen,
          DauVietColors.heritageGreenSurface,
        );
      case LearnerPathStatus.mastered:
        return (
          Icons.workspace_premium_rounded,
          status.labelVi,
          DauVietColors.imperialGoldDark,
          DauVietColors.paperCardHi,
        );
      case LearnerPathStatus.inProgress:
        return (
          Icons.timelapse_rounded,
          status.labelVi,
          DauVietColors.cinnabarRed,
          DauVietColors.paperCardHi,
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
          DauVietColors.inkMuted,
          DauVietColors.paperDim,
        );
      case LearnerPathStatus.notReady:
        return (
          Icons.hourglass_empty_rounded,
          status.labelVi,
          DauVietColors.inkMuted,
          DauVietColors.paperDim,
        );
    }
  }
}
