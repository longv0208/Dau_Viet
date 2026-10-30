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

/// Biển hiệu sơn son thếp vàng (Imperial Scroll Plaque) — dùng cho các tiêu đề
/// cuộn thư như `THÔNG SỐ CHIẾN DỊCH SỬ KÝ`, `CỔ THƯ • ĐỌC KỸ`,
/// `THU THẬP DẤU VẾT`, `DÒNG THỜI GIAN • SẮP XẾP`, `ĐÚC KẾT • LẬP LUẬN CER`,
/// `ÔN LẠI BÀI HỌC`.
class ImperialScrollPlaque extends StatelessWidget {
  final String text;
  final String? hiddenTestText;
  final bool centered;
  final bool pillStyle;
  final EdgeInsetsGeometry? padding;
  final double fontSize;
  final bool uppercase;

  const ImperialScrollPlaque(
    this.text, {
    super.key,
    this.hiddenTestText,
    this.centered = false,
    this.pillStyle = false,
    this.padding,
    this.fontSize = 11.5,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    if (pillStyle) {
      return Container(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA5231C), Color(0xFF7D1510)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5B869), width: 1.3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x284A150E),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GoldDiamondDot(),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFFFFF4DC),
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const _GoldDiamondDot(),
          ],
        ),
      );
    }

    final String displayedText = uppercase ? text.toUpperCase() : text;
    return Stack(
      clipBehavior: Clip.none,
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      children: [
        if (hiddenTestText != null && hiddenTestText != displayedText)
          Opacity(
            opacity: 0.0,
            child: SizedBox(height: 0, width: 0, child: Text(hiddenTestText!)),
          ),
        Container(
          padding:
              padding ??
              EdgeInsets.fromLTRB(centered ? 18 : 22, 5.5, 16, 5.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF9E1F19), Color(0xFF72120E)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4B869), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x334A150E),
                blurRadius: 6,
                offset: Offset(0, 2.5),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: const Color(0xFFF6D992).withValues(alpha: 0.42),
                width: 0.8,
              ),
            ),
            child: Text(
              displayedText,
              textAlign: centered ? TextAlign.center : TextAlign.left,
              style: DauVietTypography.headlineSmall.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.55,
                color: const Color(0xFFFFF4DC),
                height: 1.2,
              ),
            ),
          ),
        ),
        // Vân mây vàng trang trí đầu trái biển hiệu
        const Positioned(
          left: -5,
          bottom: -2,
          child: IgnorePointer(
            child: SizedBox(
              width: 26,
              height: 22,
              child: CustomPaint(painter: _ImperialCloudCurlPainter()),
            ),
          ),
        ),
        if (centered)
          Positioned(
            right: -5,
            bottom: -2,
            child: IgnorePointer(
              child: Transform.flip(
                flipX: true,
                child: const SizedBox(
                  width: 26,
                  height: 22,
                  child: CustomPaint(painter: _ImperialCloudCurlPainter()),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoldDiamondDot extends StatelessWidget {
  const _GoldDiamondDot();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 4.5,
        height: 4.5,
        decoration: const BoxDecoration(color: Color(0xFFF3CF85)),
      ),
    );
  }
}

class _ImperialCloudCurlPainter extends CustomPainter {
  const _ImperialCloudCurlPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF6D78E), Color(0xFFC98A35)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final stroke = Paint()
      ..color = const Color(0xFF7D1510)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Path union = Path();
    for (final (cx, cy, r) in const <(double, double, double)>[
      (7.0, 14.0, 5.2),
      (13.5, 11.5, 6.2),
      (19.5, 15.0, 4.8),
      (11.0, 16.5, 4.5),
    ]) {
      union = Path.combine(
        PathOperation.union,
        union,
        Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }
    canvas.drawPath(union, fill);
    canvas.drawPath(union, stroke);

    final spiral = Path()
      ..moveTo(9, 14.5)
      ..cubicTo(10.5, 11, 15, 11, 15.5, 14)
      ..cubicTo(16, 16, 13, 16.8, 12, 15);
    canvas.drawPath(
      spiral,
      Paint()
        ..color = const Color(0xFF8A2218)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Khung cuộn thư giấy dó cổ điển (Imperial Scroll Frame) — có đầu trục cuộn
/// sơn son hai góc trên, vân núi non + trúc mờ ở đáy và biển hiệu sơn son thếp vàng.
class ImperialScrollFrame extends StatelessWidget {
  final Widget child;
  final String? plaqueTitle;
  final String? hiddenPlaqueTestText;
  final bool centerPlaque;
  final Widget? topRightBadge;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const ImperialScrollFrame({
    super.key,
    required this.child,
    this.plaqueTitle,
    this.hiddenPlaqueTestText,
    this.centerPlaque = false,
    this.topRightBadge,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 18),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorder = borderColor ?? const Color(0xFFDEC69A);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCF7EB), Color(0xFFF7ECD6)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: resolvedBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x185D4024),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Vân núi mờ + cành trúc ở đáy cuộn thư
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 82,
            child: IgnorePointer(
              child: CustomPaint(painter: _ScrollBottomLandscapePainter()),
            ),
          ),
          // Góc cuộn thư sơn son bên trái & phải đỉnh thẻ
          const Positioned(
            top: 0,
            left: 0,
            width: 28,
            height: 28,
            child: IgnorePointer(
              child: CustomPaint(painter: _ScrollCornerCapPainter(isLeft: true)),
            ),
          ),
          const Positioned(
            top: 0,
            right: 0,
            width: 28,
            height: 28,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScrollCornerCapPainter(isLeft: false),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (plaqueTitle != null) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      right: topRightBadge != null ? 54 : 0,
                      bottom: 12,
                    ),
                    child: Align(
                      alignment: centerPlaque
                          ? Alignment.center
                          : Alignment.centerLeft,
                      child: ImperialScrollPlaque(
                        plaqueTitle!,
                        hiddenTestText: hiddenPlaqueTestText,
                        centered: centerPlaque,
                      ),
                    ),
                  ),
                ],
                child,
              ],
            ),
          ),
          if (topRightBadge != null)
            Positioned(top: 10, right: 12, child: topRightBadge!),
        ],
      ),
    );
  }
}

class _ScrollCornerCapPainter extends CustomPainter {
  final bool isLeft;
  const _ScrollCornerCapPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isLeft) {
      path.moveTo(0, 22);
      path.quadraticBezierTo(0, 0, 22, 0);
      path.lineTo(14, 0);
      path.quadraticBezierTo(4, 4, 0, 14);
      path.close();
    } else {
      path.moveTo(size.width, 22);
      path.quadraticBezierTo(size.width, 0, size.width - 22, 0);
      path.lineTo(size.width - 14, 0);
      path.quadraticBezierTo(size.width - 4, 4, size.width, 14);
      path.close();
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF9C221B));
  }

  @override
  bool shouldRepaint(covariant _ScrollCornerCapPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft;
}

class _ScrollBottomLandscapePainter extends CustomPainter {
  const _ScrollBottomLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Dải núi mờ xa
    final farHills = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.14, h * 0.25, w * 0.28, h * 0.56)
      ..quadraticBezierTo(w * 0.42, h * 0.72, w * 0.58, h * 0.44)
      ..quadraticBezierTo(w * 0.76, h * 0.18, w, h * 0.52)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      farHills,
      Paint()..color = const Color(0xFFD9C7A7).withValues(alpha: 0.26),
    );

    // Dải núi gần
    final nearHills = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.76)
      ..quadraticBezierTo(w * 0.20, h * 0.48, w * 0.42, h * 0.78)
      ..quadraticBezierTo(w * 0.68, h * 0.52, w, h * 0.72)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      nearHills,
      Paint()..color = const Color(0xFFCDB894).withValues(alpha: 0.24),
    );

    // Khóm trúc mảnh góc dưới phải
    final bambooPaint = Paint()
      ..color = const Color(0xFF8C7B65).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w - 18, h), Offset(w - 30, h * 0.18), bambooPaint);
    canvas.drawLine(Offset(w - 8, h), Offset(w - 16, h * 0.32), bambooPaint);

    final leafPaint = Paint()
      ..color = const Color(0xFF8C7B65).withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    for (final (lx, ly, dx, dy) in <(double, double, double, double)>[
      (w - 28, h * 0.30, -14, -5),
      (w - 27, h * 0.42, -16, 4),
      (w - 24, h * 0.25, 12, -7),
      (w - 15, h * 0.44, -12, -4),
    ]) {
      final leaf = Path()
        ..moveTo(lx, ly)
        ..quadraticBezierTo(lx + dx * 0.5, ly + dy - 4, lx + dx, ly + dy)
        ..quadraticBezierTo(lx + dx * 0.5, ly + dy + 3, lx, ly)
        ..close();
      canvas.drawPath(leaf, leafPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Con dấu tròn sách đỏ `ĐỌC` góc trên phải của màn Đọc Tư Liệu (khớp ảnh mẫu #6).
class ImperialBookSealBadge extends StatelessWidget {
  final String label;
  const ImperialBookSealBadge({super.key, this.label = 'ĐỌC'});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 tia nhấn nhỏ bên trái con dấu
          SizedBox(
            width: 10,
            height: 28,
            child: CustomPaint(painter: _SealRaysPainter()),
          ),
          const SizedBox(width: 2),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB5261E), Color(0xFF821510)],
              ),
              border: Border.all(color: const Color(0xFFE5B869), width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x294A150E),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFF3D6).withValues(alpha: 0.65),
                  width: 0.9,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: Color(0xFFFFF6E5),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: DauVietTypography.labelSmall.copyWith(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF6E5),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SealRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC85A32).withValues(alpha: 0.65)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(2, 5), const Offset(8, 9), paint);
    canvas.drawLine(const Offset(0, 14), const Offset(7, 14), paint);
    canvas.drawLine(const Offset(2, 23), const Offset(8, 19), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Huy hiệu vòng tròn kép (Double Ring Medallion) cho số thứ tự bài học / bước
/// hoặc chữ cái C-E-R (khớp ảnh mẫu #1, #3, #5).
class ImperialDoubleCircleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final bool filled;

  const ImperialDoubleCircleBadge(
    this.label, {
    super.key,
    required this.color,
    this.size = 40,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : const Color(0xFFFAF5E8),
        border: Border.all(
          color: filled ? const Color(0xFFE2BE78) : color,
          width: filled ? 1.5 : 2.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F3A2818),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: filled
                ? const Color(0xFFFFF4DC).withValues(alpha: 0.65)
                : color.withValues(alpha: 0.45),
            width: 1.0,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: DauVietTypography.headlineSmall.copyWith(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  color: filled ? const Color(0xFFFFF8EB) : color,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
