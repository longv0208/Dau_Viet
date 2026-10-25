import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../data/attempt_dtos.dart';
import '../data/attempt_repository.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';

Duration? _noRetry(int retryCount, Object error) => null;

final _lessonMetadataProvider =
    FutureProvider.family<LessonMetadataDto, String>(retry: _noRetry, (
      ref,
      lessonId,
    ) {
      final AttemptRepository repo = ref.watch(attemptRepositoryProvider);
      if (ApiConfig.useMock) return repo.getLessonMetadata(lessonId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getLessonMetadata(lessonId));
    });

/// Màn hình Giới thiệu bài học (Screen 1 chuẩn UI/UX Pro Max)
/// Tóm tắt nội dung lịch sử, chỉ số thời lượng, số hoạt động, phần thưởng XP,
/// và tranh minh hoạ di sản hào hùng.
class LessonEntryScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonEntryScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonEntryScreen> createState() => _LessonEntryScreenState();
}

class _LessonEntryScreenState extends ConsumerState<LessonEntryScreen> {
  bool _starting = false;
  String? _startError;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _startError = null;
    });
    try {
      final AttemptRepository repo = ref.read(attemptRepositoryProvider);
      final started = ApiConfig.useMock
          ? await repo.startOrResume(widget.lessonId)
          : await ref
                .read(authRepositoryProvider)
                .withAuth(() => repo.startOrResume(widget.lessonId));
      if (!mounted) return;
      context.pushReplacement('/learning/attempt/${started.attemptId}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = e.error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = 'Không mở được bài học. Thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LessonMetadataDto> metaAsync = ref.watch(
      _lessonMetadataProvider(widget.lessonId),
    );
    final AsyncValue<MyProgressDto> progressAsync = ref.watch(
      myProgressProvider,
    );
    final AttemptSummaryDto? resume = progressAsync.maybeWhen(
      data: (p) {
        for (final a in p.inProgress) {
          if (a.lessonId == widget.lessonId) return a;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: const Color(0xFF1F2421),
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Bài học',
          style: DauVietTypography.headlineMedium.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2421),
          ),
        ),
        centerTitle: true,
        actions: [
          // Huy hiệu ngọn lửa Streak 🔥 12
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 15,
                      color: Color(0xFFE65100),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '12',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: const Color(0xFFE65100),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: metaAsync.when(
          loading: () => AsyncStateView.loading(message: 'Đang mở sử liệu bài học...'),
          error: (error, _) => AsyncStateView.error(
            error: error,
            onRetry: () =>
                ref.invalidate(_lessonMetadataProvider(widget.lessonId)),
          ),
          data: (meta) {
            // Xác định ảnh hero bài học
            final isHungVuong = meta.title.toLowerCase().contains('hùng') ||
                meta.title.toLowerCase().contains('dân tộc') ||
                meta.title.toLowerCase().contains('văn lang');
            final heroAsset = isHungVuong
                ? 'assets/images/lesson_hero_lac_long_quan_au_co.jpg'
                : 'assets/images/bach_dang_938.jpg';

            return Stack(
              children: [
                // Dải tranh phong cảnh chân trang
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.25,
                    child: Image.asset(
                      'assets/images/ancient_village_footer.png',
                      height: 120,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Nội dung chính cuộn dọc
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Tranh minh hoạ di sản mở bài khổ lớn
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD8C8B0),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B4513).withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.asset(
                              heroAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFEFE8DA),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  size: 48,
                                  color: DauVietColors.heritageGreen,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Huy hiệu Chương học
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFCC80), width: 1),
                          ),
                          child: Text(
                            'Chương 1 • Buổi đầu dựng nước',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 3. Tiêu đề bài học
                      Text(
                        meta.title,
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1F2421),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 4. Đoạn mô tả / Câu hỏi trung tâm
                      Text(
                        (meta.centralQuestion != null && meta.centralQuestion!.isNotEmpty)
                            ? meta.centralQuestion!
                            : 'Tìm hiểu truyền thuyết Lạc Long Quân - Âu Cơ, sự ra đời của người Việt và những nét văn hóa đầu tiên của dân tộc.',
                        style: DauVietTypography.bodyMedium.copyWith(
                          fontSize: 13,
                          color: const Color(0xFF5E6963),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Ba thẻ thống kê trực quan hàng ngang chuẩn UI Pro Max
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.timer_outlined,
                              iconColor: const Color(0xFFB45309),
                              value: '15 phút',
                              label: 'thời lượng',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.menu_book_rounded,
                              iconColor: const Color(0xFF2D6A4F),
                              value: '4 hoạt động',
                              label: 'trong bài',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.stars_rounded,
                              iconColor: const Color(0xFFD97706),
                              value: '+50 XP',
                              label: 'phần thưởng',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Trạng thái Resume (nếu có bài đang học dở)
                      if (resume != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA5D6A7), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đang học dở — đã hoàn thành '
                                  '${resume.progress.completedRequired}/'
                                  '${resume.progress.totalRequired} hoạt động',
                                  style: DauVietTypography.bodySmall.copyWith(
                                    color: const Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Báo lỗi (nếu có)
                      if (_startError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: DauVietColors.cinnabarRed, width: 1),
                          ),
                          child: Text(
                            _startError!,
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.cinnabarRed,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 6. Nút hành động Bắt đầu học nổi khối 3D (Heritage Green)
                      DongSonButton(
                        label: _starting
                            ? 'ĐANG MỞ BÀI HỌC...'
                            : (resume != null
                                  ? 'TIẾP TỤC HỌC ›'
                                  : 'BẮT ĐẦU HỌC ›'),
                        icon: Icons.arrow_forward_rounded,
                        variant: DongSonButtonVariant.natureGreen,
                        height: 52,
                        isLoading: _starting,
                        onPressed: _starting ? null : _start,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5DAC6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: DauVietTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: const Color(0xFF1F2421),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: const Color(0xFF75807A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
