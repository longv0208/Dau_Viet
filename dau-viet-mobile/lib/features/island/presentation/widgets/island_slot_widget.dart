import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/island_dto.dart';

/// Widget biểu diễn một ô (slot) và vật phẩm đặt trên Đảo Di Sản 2.5D.
/// Tối ưu hiệu năng (ISLAND-06 Part C & E):
/// - Chỉ chạy AnimationController khi `isSelected == true`.
/// - Phân biệt rõ: ô khóa (mờ nhẹ), ô trống (thềm cỏ/đá mời đặt), và ô đã có
///   vật phẩm (vật phẩm là thành phần chính của cảnh quan, không đóng khung card).
class IslandSlotWidget extends StatefulWidget {
  final IslandSlotDto slot;
  final bool isSelected;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const IslandSlotWidget({
    super.key,
    required this.slot,
    required this.isSelected,
    this.onTap,
    this.width = 100.0,
    this.height = 110.0,
  });

  @override
  State<IslandSlotWidget> createState() => _IslandSlotWidgetState();
}

class _IslandSlotWidgetState extends State<IslandSlotWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) {
      _ensurePulseRunning();
    }
  }

  @override
  void didUpdateWidget(covariant IslandSlotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _ensurePulseRunning();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _pulseController?.stop();
      _pulseController?.value = 0.0;
    }
  }

  void _ensurePulseRunning() {
    final controller = _pulseController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation ??= Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final isSelected = widget.isSelected;

    Widget content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: _buildSlotStack(slot, isSelected),
    );

    if (isSelected && _pulseAnimation != null) {
      content = AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) =>
            Transform.scale(scale: _pulseAnimation!.value, child: child),
        child: content,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildSlotStack(IslandSlotDto slot, bool isSelected) {
    if (slot.isLocked) {
      return _buildLockedSlot(slot, isSelected);
    }
    if (slot.isEmpty) {
      return _buildEmptySlot(slot, isSelected);
    }
    return _buildOccupiedSlot(slot, isSelected);
  }

  /// Trạng thái 1: Slot đang bị khóa theo Tier — hiển thị cột mốc đá mờ nhẹ,
  /// không che cảnh quan và không lặp lại quá nhiều chữ.
  Widget _buildLockedSlot(IslandSlotDto slot, bool isSelected) {
    final baseW = (widget.width * 0.56).clamp(42.0, 68.0);
    final baseH = (baseW * 0.52).clamp(22.0, 36.0);

    return Opacity(
      opacity: isSelected ? 0.85 : 0.42,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 10,
            child: Container(
              width: baseW,
              height: baseH,
              decoration: BoxDecoration(
                color: const Color(0x55334155),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(baseW, baseH),
                ),
                border: Border.all(
                  color: isSelected
                      ? DauVietColors.imperialGold
                      : const Color(0x8894A3B8),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xAA1E293B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: DauVietColors.imperialGoldLight.withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: DauVietColors.imperialGoldLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trạng thái 2: Slot đã mở nhưng đang trống — thềm cỏ/đá tự nhiên mời đặt vật phẩm.
  Widget _buildEmptySlot(IslandSlotDto slot, bool isSelected) {
    final baseW = (widget.width * 0.76).clamp(58.0, 96.0);
    final baseH = (baseW * 0.50).clamp(28.0, 48.0);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Đế thềm đá/cỏ isometric mềm mại
        Positioned(
          bottom: 10,
          child: Container(
            width: baseW,
            height: baseH,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0x99E9DFC4), Color(0x668C704B)],
              ),
              borderRadius: BorderRadius.all(Radius.elliptical(baseW, baseH)),
              border: Border.all(
                color: isSelected
                    ? DauVietColors.imperialGold
                    : const Color(0xAA6B8E4E),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? DauVietColors.imperialGold.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.16),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),

        // Nút cộng nhỏ hài hòa với nền đất
        Positioned(
          bottom: 10 + (baseH * 0.28),
          child: Container(
            width: isSelected ? 34 : 30,
            height: isSelected ? 34 : 30,
            decoration: BoxDecoration(
              color: isSelected
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.heritageGreen.withValues(alpha: 0.88),
              shape: BoxShape.circle,
              border: Border.all(
                color: DauVietColors.parchmentSurface,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        if (isSelected)
          Positioned(
            bottom: -4,
            child: _buildCompactTag('Chạm để đặt di sản', isHighlighted: true),
          ),
      ],
    );
  }

  /// Trạng thái 3: Đã đặt vật phẩm — vật phẩm hòa vào cảnh quan 2.5D với bóng đổ tự nhiên.
  Widget _buildOccupiedSlot(IslandSlotDto slot, bool isSelected) {
    final placement = slot.placement!;
    final asset = placement.assetPath;
    final baseW = (widget.width * 0.82).clamp(64.0, 118.0);
    final baseH = (baseW * 0.46).clamp(28.0, 54.0);
    final artW = (widget.width * 0.88).clamp(68.0, 136.0);
    final artH = (widget.height * 0.82).clamp(68.0, 136.0);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. Bóng đổ mềm trên mặt đất và vòng sáng khi được chọn
        Positioned(
          bottom: 8,
          child: Container(
            width: baseW,
            height: baseH,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: isSelected
                    ? [
                        DauVietColors.imperialGold.withValues(alpha: 0.45),
                        const Color(0x334A3520),
                      ]
                    : [
                        const Color(0x553E2F1C),
                        const Color(0x003E2F1C),
                      ],
              ),
              borderRadius: BorderRadius.all(Radius.elliptical(baseW, baseH)),
              border: isSelected
                  ? Border.all(color: DauVietColors.imperialGold, width: 2.2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: DauVietColors.imperialGold.withValues(
                          alpha: 0.5,
                        ),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
        ),

        // 2. Công trình / vật phẩm trang trí 2.5D neo chân xuống mặt đất
        Positioned(
          bottom: 14,
          child: SizedBox(
            width: artW,
            height: artH,
            child: asset != null
                ? Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildHeritageDioramaPiece(placement, artW, artH),
                  )
                : _buildHeritageDioramaPiece(placement, artW, artH),
          ),
        ),

        // 3. Nhãn tên chỉ nổi rõ khi đang chọn (hoặc pill siêu gọn)
        if (isSelected)
          Positioned(
            bottom: -6,
            child: _buildCompactTag(placement.name, isHighlighted: true),
          ),
      ],
    );
  }

  /// Minh họa diorama 2.5D trung tính theo chủ đề văn hóa Việt khi vật phẩm
  /// chưa có file PNG riêng trong bundle — tuyệt đối không dùng nhầm ảnh nhà tranh.
  Widget _buildHeritageDioramaPiece(
    IslandPlacementDto placement,
    double width,
    double height,
  ) {
    return CustomPaint(
      size: Size(width, height),
      painter: _HeritageMiniaturePainter(
        keyToken: (placement.renderKey ?? placement.code).toLowerCase(),
      ),
    );
  }

  Widget _buildCompactTag(String text, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      constraints: const BoxConstraints(maxWidth: 118),
      decoration: BoxDecoration(
        color: isHighlighted
            ? DauVietColors.woodBrown.withValues(alpha: 0.94)
            : DauVietColors.parchmentContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? DauVietColors.imperialGold
              : DauVietColors.outlineVariant,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: DauVietTypography.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isHighlighted ? Colors.white : DauVietColors.woodBrown,
        ),
      ),
    );
  }
}

/// Vẽ mô hình kiến trúc / cảnh quan di sản Việt Nam 2.5D (diorama) cho các vật phẩm
/// mới trong catalog chưa có PNG cục bộ, giúp mỗi loại vật phẩm có hình dáng đặc trưng.
class _HeritageMiniaturePainter extends CustomPainter {
  final String keyToken;

  const _HeritageMiniaturePainter({required this.keyToken});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final bottom = size.height * 0.92;

    // Thềm đá ong / thảm cỏ chân công trình
    final plinthRect = Rect.fromCenter(
      center: Offset(cx, bottom - 6),
      width: size.width * 0.72,
      height: size.height * 0.22,
    );
    canvas.drawOval(
      plinthRect,
      Paint()..color = const Color(0xFF8B6F47),
    );
    canvas.drawOval(
      plinthRect.deflate(2.5),
      Paint()..color = const Color(0xFFA3B86C),
    );

    if (keyToken.contains('bui_tre') || keyToken.contains('cay')) {
      _paintBambooGrove(canvas, cx, bottom - 10, size);
    } else if (keyToken.contains('gieng') || keyToken.contains('sen')) {
      _paintAncientWell(canvas, cx, bottom - 8, size);
    } else if (keyToken.contains('thuyen')) {
      _paintDragonBoat(canvas, cx, bottom - 8, size);
    } else if (keyToken.contains('den_long')) {
      _paintLanternPavilion(canvas, cx, bottom - 10, size);
    } else if (keyToken.contains('thap_but')) {
      _paintStoneTower(canvas, cx, bottom - 10, size);
    } else {
      // Đình làng / Khuê Văn Các / Cổng làng mái đao truyền thống
      _paintHeritagePavilion(canvas, cx, bottom - 10, size);
    }
  }

  void _paintBambooGrove(Canvas canvas, double cx, double baseY, Size size) {
    final stalkPaint = Paint()
      ..color = const Color(0xFF3E7B3B)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (final dx in [-8.0, 0.0, 7.0]) {
      canvas.drawLine(
        Offset(cx + dx, baseY),
        Offset(cx + dx * 1.4, baseY - size.height * 0.52),
        stalkPaint,
      );
    }
    final canopyPaint = Paint()..color = const Color(0xFF4D9144);
    final highlightPaint = Paint()..color = const Color(0xFF7BB661);
    canvas.drawCircle(
      Offset(cx - 10, baseY - size.height * 0.46),
      size.width * 0.19,
      canopyPaint,
    );
    canvas.drawCircle(
      Offset(cx + 10, baseY - size.height * 0.44),
      size.width * 0.18,
      canopyPaint,
    );
    canvas.drawCircle(
      Offset(cx, baseY - size.height * 0.56),
      size.width * 0.22,
      highlightPaint,
    );
  }

  void _paintAncientWell(Canvas canvas, double cx, double baseY, Size size) {
    final outer = Rect.fromCenter(
      center: Offset(cx, baseY - 10),
      width: size.width * 0.54,
      height: size.height * 0.26,
    );
    canvas.drawOval(outer, Paint()..color = const Color(0xFF6E7B7B));
    canvas.drawOval(
      outer.translate(0, -5),
      Paint()..color = const Color(0xFF94A3A3),
    );
    canvas.drawOval(
      outer.deflate(6).translate(0, -5),
      Paint()..color = const Color(0xFF3B82A6),
    );
  }

  void _paintDragonBoat(Canvas canvas, double cx, double baseY, Size size) {
    final hull = Path()
      ..moveTo(cx - size.width * 0.34, baseY - 14)
      ..quadraticBezierTo(cx, baseY + 4, cx + size.width * 0.34, baseY - 14)
      ..lineTo(cx + size.width * 0.24, baseY - 4)
      ..lineTo(cx - size.width * 0.24, baseY - 4)
      ..close();
    canvas.drawPath(hull, Paint()..color = const Color(0xFF8C3B2B));
    final cabin = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, baseY - 18),
        width: size.width * 0.28,
        height: 12,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(cabin, Paint()..color = const Color(0xFFD99B26));
  }

  void _paintLanternPavilion(Canvas canvas, double cx, double baseY, Size size) {
    final polePaint = Paint()
      ..color = const Color(0xFF5C3A21)
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(cx, baseY),
      Offset(cx, baseY - size.height * 0.56),
      polePaint,
    );
    canvas.drawLine(
      Offset(cx - 16, baseY - size.height * 0.46),
      Offset(cx + 16, baseY - size.height * 0.46),
      polePaint,
    );
    for (final dx in [-14.0, 0.0, 14.0]) {
      final dy = dx == 0 ? baseY - size.height * 0.54 : baseY - size.height * 0.40;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + dx, dy), width: 12, height: 15),
        Paint()..color = const Color(0xFFD9381E),
      );
      canvas.drawCircle(
        Offset(cx + dx, dy),
        3,
        Paint()..color = const Color(0xFFFFE082),
      );
    }
  }

  void _paintStoneTower(Canvas canvas, double cx, double baseY, Size size) {
    for (int i = 0; i < 4; i++) {
      final w = size.width * (0.36 - i * 0.06);
      final y = baseY - (i * 11.0) - 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: w, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = i.isEven ? const Color(0xFF78716C) : const Color(0xFF9CA3AF),
      );
    }
    final tip = Path()
      ..moveTo(cx, baseY - 58)
      ..lineTo(cx - 6, baseY - 44)
      ..lineTo(cx + 6, baseY - 44)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFD97706));
  }

  void _paintHeritagePavilion(
    Canvas canvas,
    double cx,
    double baseY,
    Size size,
  ) {
    // Thân gỗ & cột đình
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, baseY - 14),
      width: size.width * 0.44,
      height: 22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF8B4513),
    );
    canvas.drawCircle(
      Offset(cx, baseY - 14),
      6,
      Paint()..color = const Color(0xFFEAB308),
    );

    // Mái đao cong truyền thống
    final roof = Path()
      ..moveTo(cx - size.width * 0.36, baseY - 22)
      ..quadraticBezierTo(
        cx - size.width * 0.18,
        baseY - 44,
        cx,
        baseY - 48,
      )
      ..quadraticBezierTo(
        cx + size.width * 0.18,
        baseY - 44,
        cx + size.width * 0.36,
        baseY - 22,
      )
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB91C1C));
    canvas.drawPath(
      roof,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _HeritageMiniaturePainter oldDelegate) {
    return oldDelegate.keyToken != keyToken;
  }
}
