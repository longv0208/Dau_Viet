import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/event_cover_image.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../mock/data/mock_bach_dang_data.dart';
import '../../../mock/models/lesson_models.dart';
import '../../events/data/events_providers.dart';
import '../../learning/presentation/lesson_list_section.dart';

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
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DauVietColors.parchmentSurface, Color(0xFFFAF2E4)],
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

            // 6b. Bài học published của sự kiện (real backend / demo repo)
            LessonListSection(eventId: eventId),
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
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: DauVietColors.inkText,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/timeline');
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHI TIẾT CHIẾN DỊCH',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 16,
                    color: DauVietColors.inkText,
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
          // Energy/điểm sử ký là cơ chế demo — chưa có backend thật.
          if (ApiConfig.useMock)
            const EnergyPill(energy: 100, maxEnergy: 100, historyPoints: 150),
        ],
      ),
    );
  }

  // Hero Banner 16:9 phong cách tranh khắc gỗ di sản.
  // [heroAssetPath] do AssetResolver map từ `coverAssetKey` của backend —
  // null/rỗng → EventCoverImage tự render placeholder (AC-6).
  Widget _buildHeroBanner(BuildContext context, HistoricalEventModel event) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B3A42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DauVietColors.imperialGold, width: 2),
        boxShadow: DauVietColors.heritageShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            // Ảnh Hero Banner chiến dịch — từ asset path đã resolve
            EventCoverImage(
              assetPath: event.heroBannerUrl,
              width: double.infinity,
              height: double.infinity,
            ),

            // Lớp phủ thông tin chữ vàng trên nền khói sóng
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      // Badge/headline dùng metadata event thật — demo
                      // Bạch Đằng có copy riêng trong mock payload.
                      'SỰ KIỆN • NĂM ${event.year}',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
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
                      color: const Color(0xFFE2E2E2),
                      fontSize: 11,
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

  // Khối Thông Số Chiến Dịch (Metadata).
  // Thời gian/Địa bàn lấy từ API (event.year / summary); phần chỉ huy/đối thủ/
  // chi phí chưa có trường backend — giữ copy mô tả cho tới task mở rộng DTO.
  Widget _buildCampaignMetadata(HistoricalEventModel event) {
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
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
          _buildMetaRow(Icons.auto_stories_rounded, 'Chiến dịch:', event.title),
          const SizedBox(height: 8),
          _buildMetaRow(
            Icons.calendar_today_rounded,
            'Niên đại:',
            'Năm ${event.year} • ${event.era}',
          ),
          const SizedBox(height: 8),
          // Địa bàn/Chỉ huy/Đối thủ/Chi phí là copy demo Bạch Đằng — chưa
          // có trường backend, chỉ render trong USE_MOCK.
          if (ApiConfig.useMock) ...[
            _buildMetaRow(
              Icons.location_on_rounded,
              'Địa bàn:',
              'Cửa sông Bạch Đằng (Quảng Ninh & Hải Phòng)',
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.shield_rounded,
              'Chỉ huy Ta:',
              'Tiền Ngô Vương Ngô Quyền (Ái Châu)',
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.dangerous_rounded,
              'Đối thủ:',
              'Vạn sứ quân Nam Hán dưới trướng Lưu Hoằng Tháo',
            ),
            const SizedBox(height: 8),
            _buildMetaRow(
              Icons.bolt_rounded,
              'Chi phí:',
              '⚡ 20 Thể lực  •  Nhận 150 Điểm Sử Ký + 50 XP',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: DauVietColors.cinnabarRed),
        const SizedBox(width: 8),
        Text(
          title,
          style: DauVietTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: DauVietColors.inkText,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.cinnabarRed, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.help_outline_rounded,
            color: DauVietColors.cinnabarRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CÂU HỎI TRUNG TÂM BÀI HỌC',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  question,
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 15,
                    color: DauVietColors.inkText,
                    height: 1.4,
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
        Text(
          '4 DẤU VẾT LỊCH SỬ CẦN GIẢI MÃ',
          style: DauVietTypography.labelSmall.copyWith(
            color: DauVietColors.inkMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildTraceTile(
          '1',
          'Khảo Cổ & Hiện Vật',
          'Bãi cọc Yên Giang và vũ khí thế kỷ X',
          Icons.museum_outlined,
          true,
        ),
        const SizedBox(height: 8),
        _buildTraceTile(
          '2',
          'Nhân Vật & Chiến Lược',
          'Quân mưu Tiền Ngô Vương và thế trận lòng dân',
          Icons.person_pin_outlined,
          true,
        ),
        const SizedBox(height: 8),
        _buildTraceTile(
          '3',
          'Sa Bàn Tác Chiến',
          'Nhịp con nước thủy triều và kế đóng cọc ngầm',
          Icons.military_tech_outlined,
          true,
        ),
        const SizedBox(height: 8),
        _buildTraceTile(
          '4',
          'Di Sản & Ý Nghĩa',
          'Dấu mốc son chấm dứt một thiên niên kỷ Bắc thuộc',
          Icons.auto_stories_outlined,
          false,
        ),
      ],
    );
  }

  Widget _buildTraceTile(
    String number,
    String title,
    String subtitle,
    IconData icon,
    bool isAvailable,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAvailable
              ? DauVietColors.imperialGold
              : DauVietColors.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAvailable
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.outlineVariant,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
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
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          Icon(
            icon,
            size: 20,
            color: isAvailable
                ? DauVietColors.cinnabarRed
                : DauVietColors.inkMuted,
          ),
        ],
      ),
    );
  }
}
