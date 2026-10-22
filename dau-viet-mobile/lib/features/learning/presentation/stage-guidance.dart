import 'package:flutter/material.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';

/// Nhãn + gợi ý ngắn cho từng StageType của backend (P1-04).
/// Chip này hiện trên đầu mỗi activity để người học hiểu mình đang
/// ở bước nào của phương pháp điều tra — CER/Verification/Reflection.
abstract final class StageGuidance {
  /// (label, hint, icon) theo StageType enum backend.
  static const Map<String, ({String label, String hint, IconData icon})>
  _map = {
    'CONTEXT': (
      label: 'Bối cảnh',
      hint: 'Đọc kỹ tư liệu để nắm hoàn cảnh trước khi trả lời.',
      icon: Icons.menu_book_rounded,
    ),
    'DISCOVERY': (
      label: 'Khám phá',
      hint: 'Tự quan sát và ghi nhận điều bạn thấy trong tư liệu.',
      icon: Icons.travel_explore_rounded,
    ),
    'EVIDENCE': (
      label: 'Bằng chứng',
      hint:
          'Chọn bằng chứng lịch sử phù hợp — bằng chứng đúng mới mở khoá sưu tập.',
      icon: Icons.inventory_2_rounded,
    ),
    'REASONING': (
      label: 'Lập luận',
      hint: 'Ghép bằng chứng với nhận định — lập luận cần chứng cứ.',
      icon: Icons.psychology_alt_rounded,
    ),
    'HYPOTHESIS': (
      label: 'Giả thuyết',
      hint: 'Đưa ra giả thuyết của riêng bạn trước khi kiểm chứng.',
      icon: Icons.lightbulb_outline_rounded,
    ),
    'RECONSTRUCTION': (
      label: 'Tái dựng',
      hint: 'Sắp xếp lại diễn biến sự kiện theo đúng trình tự.',
      icon: Icons.timeline_rounded,
    ),
    'VERIFICATION': (
      label: 'Kiểm chứng',
      hint: 'Đối chiếu giả thuyết với bằng chứng — sai thì thử lại ngay.',
      icon: Icons.fact_check_rounded,
    ),
    'CONCLUSION': (
      label: 'Kết luận',
      hint: 'Viết lập luận CER: Claim — Evidence — Reasoning.',
      icon: Icons.draw_rounded,
    ),
    'REFLECTION': (
      label: 'Suy ngẫm',
      hint: 'Suy ngẫm ý nghĩa sự kiện — không có đáp án đúng/sai ở đây.',
      icon: Icons.self_improvement_rounded,
    ),
  };

  static ({String label, String hint, IconData icon})? forType(String? type) =>
      type == null ? null : _map[type];
}

/// Chip nhỏ hiển thị "giai đoạn: label + gợi ý" trên đầu activity.
class StageGuidanceChip extends StatelessWidget {
  final String? stageType;
  const StageGuidanceChip({super.key, required this.stageType});

  @override
  Widget build(BuildContext context) {
    final g = StageGuidance.forType(stageType);
    if (g == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(g.icon, size: 18, color: DauVietColors.cinnabarRed),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.label.toUpperCase(),
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  g.hint,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
