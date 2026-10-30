import 'package:flutter/material.dart';

import '../../features/learning_path/data/learning_path_dto.dart';
import '../../features/learning_path/presentation/path_status_badge.dart';
import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'heritage_ornaments.dart';

/// Alias chuẩn Design System C2 cho huy hiệu trạng thái học tập.
typedef LearningStatusBadge = PathStatusBadge;

/// Heritage Card — Thẻ nền giấy kem chuẩn Vietnamese Heritage Modern (Phần C2).
/// Bo tròn mềm, viền mảnh vàng đồng / giấy cổ, đổ bóng nhẹ và họa tiết góc dưới tùy chọn.
class HeritageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final bool showCornerMotif;
  final bool showTopAccentLine;
  final Color? topAccentColor;
  final VoidCallback? onTap;

  const HeritageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor = DauVietColors.paperCard,
    this.borderColor = const Color(0xFFD8BA73),
    this.borderWidth = 1.1,
    this.borderRadius = 16,
    this.showCornerMotif = true,
    this.showTopAccentLine = false,
    this.topAccentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14613B28),
            offset: Offset(0, 3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Stack(
            children: [
              if (showTopAccentLine)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          topAccentColor ?? DauVietColors.imperialGold,
                          (topAccentColor ?? DauVietColors.imperialGold)
                              .withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                ),
              if (showCornerMotif)
                const Positioned(
                  right: 6,
                  bottom: 6,
                  child: HeritageCornerMotif(size: 22),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section Header chuẩn Vietnamese Heritage Modern (Phần C2).
class HeritageSectionHeader extends StatelessWidget {
  final String title;
  final String? periodLabel;
  final IconData icon;
  final Color accentColor;

  const HeritageSectionHeader({
    super.key,
    required this.title,
    this.periodLabel,
    this.icon = Icons.timeline_rounded,
    this.accentColor = DauVietColors.heritageGreen,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: DauVietColors.paperCardHi,
          border: Border(
            left: BorderSide(color: accentColor, width: 3.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: DauVietTypography.labelLarge.copyWith(
                  color: DauVietColors.heritageGreenDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (periodLabel != null && periodLabel!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  periodLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress Indicator chuẩn Vietnamese Heritage Modern (Phần C2 & D2).
class HeritageProgressIndicator extends StatelessWidget {
  final String label;
  final int percent;
  final Color progressColor;

  const HeritageProgressIndicator({
    super.key,
    required this.label,
    required this.percent,
    this.progressColor = DauVietColors.heritageGreen,
  });

  @override
  Widget build(BuildContext context) {
    final clampedPercent = percent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 11.5,
                  color: DauVietColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$clampedPercent%',
              style: DauVietTypography.labelSmall.copyWith(
                color: progressColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: clampedPercent / 100.0,
              backgroundColor: DauVietColors.paperDim,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Timeline Node & đường nối dọc liền mạch (Phần C2 & D3).
///
/// Sử dụng `Column` + `Expanded` bên trong `IntrinsicHeight` của hàng timeline,
/// nối chính xác giữa các node dù card sự kiện cao thấp khác nhau, tuyệt đối
/// không dùng chiều cao hardcode.
class HeritageTimelineNode extends StatelessWidget {
  final LearnerPathStatus status;
  final bool isFirst;
  final bool isLast;
  final bool isCurrentTarget;

  const HeritageTimelineNode({
    super.key,
    required this.status,
    this.isFirst = false,
    required this.isLast,
    this.isCurrentTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    final _TimelineNodeStyle nodeStyle = _TimelineNodeStyle.resolve(
      status: status,
      isCurrentTarget: isCurrentTarget,
    );

    final Color lineColor = status.isDone
        ? DauVietColors.heritageGreen.withValues(alpha: 0.55)
        : DauVietColors.outlineVariant;

    return SizedBox(
      width: 36,
      child: Column(
        children: [
          // Đoạn nối phía trên (tạo khoảng đệm cân đối với đầu card)
          SizedBox(
            height: 14,
            child: isFirst
                ? const SizedBox.shrink()
                : Center(
                    child: Container(
                      width: 2,
                      color: DauVietColors.outlineVariant,
                    ),
                  ),
          ),
          // Node trạng thái
          Container(
            width: isCurrentTarget ? 32 : 28,
            height: isCurrentTarget ? 32 : 28,
            decoration: BoxDecoration(
              color: nodeStyle.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: nodeStyle.borderColor,
                width: isCurrentTarget ? 2.0 : 1.5,
              ),
              boxShadow: isCurrentTarget
                  ? [
                      BoxShadow(
                        color: nodeStyle.borderColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              nodeStyle.icon,
              size: isCurrentTarget ? 16 : 15,
              color: nodeStyle.iconColor,
            ),
          ),
          // Đường nối dọc xuống node tiếp theo (co giãn tự động theo chiều cao card)
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                color: lineColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineNodeStyle {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  const _TimelineNodeStyle({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  static _TimelineNodeStyle resolve({
    required LearnerPathStatus status,
    required bool isCurrentTarget,
  }) {
    switch (status) {
      case LearnerPathStatus.mastered:
      case LearnerPathStatus.completed:
        // Node đã hoàn thành: dấu kiểm + xanh cổ / vàng đồng
        return _TimelineNodeStyle(
          icon: Icons.check_rounded,
          iconColor: Colors.white,
          backgroundColor: DauVietColors.heritageGreen,
          borderColor: status == LearnerPathStatus.mastered
              ? DauVietColors.imperialGold
              : DauVietColors.heritageGreen,
        );
      case LearnerPathStatus.inProgress:
      case LearnerPathStatus.available:
        // Node đang học / sẵn sàng học: màu xanh cổ hoặc điểm nhấn mốc tiếp theo
        return _TimelineNodeStyle(
          icon: status == LearnerPathStatus.inProgress
              ? Icons.play_arrow_rounded
              : Icons.radio_button_checked_rounded,
          iconColor: isCurrentTarget
              ? Colors.white
              : DauVietColors.heritageGreen,
          backgroundColor: isCurrentTarget
              ? DauVietColors.heritageGreen
              : DauVietColors.heritageGreenSurface,
          borderColor: isCurrentTarget
              ? DauVietColors.imperialGold
              : DauVietColors.heritageGreen,
        );
      case LearnerPathStatus.locked:
      case LearnerPathStatus.notReady:
        // Node đang khóa: icon khóa và màu trung tính
        return _TimelineNodeStyle(
          icon: status == LearnerPathStatus.notReady
              ? Icons.hourglass_empty_rounded
              : Icons.lock_rounded,
          iconColor: DauVietColors.inkMuted,
          backgroundColor: DauVietColors.paperDim,
          borderColor: DauVietColors.outlineVariant,
        );
    }
  }
}
