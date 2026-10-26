import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_typography.dart';
import '../../../streak/data/streak_providers.dart';

/// Thanh tiêu đề và tiến độ bài học chuẩn UI/UX Pro Max
/// Hiển thị nút quay lại, tiêu đề, thanh tiến độ xanh mượt, huy hiệu streak lửa và số câu.
/// STREAK-01: ngọn lửa đọc số thật từ streakProvider (placeholder '—' khi
/// loading/error), không còn hard-code.
class LessonHeaderTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final double progress;
  final int currentStep;
  final int totalSteps;

  const LessonHeaderTopBar({
    super.key,
    required this.onBack,
    required this.title,
    required this.progress,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE5DAC6).withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: const Color(0xFF1F2421),
                tooltip: 'Thoát bài học',
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2421),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Huy hiệu ngọn lửa chuỗi học — số thật từ streakProvider.
              const _StreakFlameBadge(),
              const SizedBox(width: 8),

              // Chỉ số bước 1/4
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE8DA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD8C8B0), width: 1),
                ),
                child: Text(
                  '$currentStep/$totalSteps',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: const Color(0xFF5E6963),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Thanh tiến độ bài học xanh ngọc vuốt mượt
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    // Đường nền xám nhạt
                    Container(color: const Color(0xFFE8DEC8)),
                    // Đoạn tiến độ xanh ngọc
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: clampedProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF2D6A4F,
                              ).withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
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
        ],
      ),
    );
  }
}

/// Huy hiệu ngọn lửa chuỗi ngày học — đọc số thật từ streakProvider,
/// hiển thị '—' khi loading/error thay vì số hard-code.
class _StreakFlameBadge extends ConsumerWidget {
  const _StreakFlameBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final String value = streakAsync.when(
      data: (s) => '${s.currentStreak}',
      loading: () => '—',
      error: (_, _) => '—',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
            size: 14,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: DauVietTypography.labelSmall.copyWith(
              color: const Color(0xFFE65100),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
