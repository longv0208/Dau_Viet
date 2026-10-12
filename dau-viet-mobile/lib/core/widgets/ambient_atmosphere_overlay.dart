import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';

enum AtmosphereMode {
  goldEmbers, // Bụi vàng / Tàn đóm lửa bập bùng (Doanh trại, Thư phòng)
  riverMist,  // Làn sương mờ trên mặt nước sông (Bến sông Bạch Đằng)
}

/// Lớp nền động môi trường (Ambient Atmosphere Overlay)
/// Mang lại bầu không khí lịch sử sống động với bụi vàng lấp lánh hoặc sương mờ sông nước,
/// tối ưu hiệu năng 60fps và an toàn 100% với môi trường kiểm thử tự động.
class AmbientAtmosphereOverlay extends StatefulWidget {
  final Widget child;
  final AtmosphereMode mode;
  final String? backgroundImage;
  final double backgroundOpacity;
  final bool enableAnimation;

  const AmbientAtmosphereOverlay({
    super.key,
    required this.child,
    this.mode = AtmosphereMode.goldEmbers,
    this.backgroundImage,
    this.backgroundOpacity = 0.22,
    this.enableAnimation = true,
  });

  @override
  State<AmbientAtmosphereOverlay> createState() => _AmbientAtmosphereOverlayState();
}

class _AmbientAtmosphereOverlayState extends State<AmbientAtmosphereOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    // Trong môi trường test tự động, không lặp vô tận để pumpAndSettle settle tức thì
    if (widget.enableAnimation && !DauVietAudioService.isTestEnvironment) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Ảnh nền bối cảnh lịch sử (nếu có)
        if (widget.backgroundImage != null)
          Positioned.fill(
            child: Opacity(
              opacity: widget.backgroundOpacity,
              child: Image.asset(
                widget.backgroundImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

        // 2. Lớp phủ Vignette chuyển sắc giữ độ tương phản cho văn bản
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DauVietColors.parchmentSurface.withValues(alpha: 0.88),
                  DauVietColors.parchmentSurface.withValues(alpha: 0.94),
                  const Color(0xFFFAF2E4).withValues(alpha: 0.97),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 3. Hiệu ứng hạt bụi vàng hoặc sóng sương mờ môi trường
        if (_controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AtmospherePainter(
                      progress: _controller!.value,
                      mode: widget.mode,
                    ),
                  );
                },
              ),
            ),
          ),

        // 4. Nội dung UI tương tác chính của màn hình
        widget.child,
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final double progress;
  final AtmosphereMode mode;

  _AtmospherePainter({
    required this.progress,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (mode == AtmosphereMode.goldEmbers) {
      _paintGoldEmbers(canvas, size);
    } else {
      _paintRiverMist(canvas, size);
    }
  }

  void _paintGoldEmbers(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const emberCount = 16;

    for (int i = 0; i < emberCount; i++) {
      final seed = (i * 0.173);
      final phase = (progress + seed) % 1.0;

      // Hạt bay nhẹ từ dưới lên và đung đưa qua lại
      final y = size.height * (1.0 - phase);
      final xOffset = math.sin((phase * 2 * math.pi) + (i * 1.5)) * 24.0;
      final x = ((i / emberCount) * size.width + xOffset) % size.width;

      final radius = 1.2 + (i % 3) * 0.8;
      final alpha = math.sin(phase * math.pi) * 0.35; // Mờ dần ở 2 đầu

      paint.color = DauVietColors.imperialGold.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintRiverMist(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.045);

    final path = Path();
    final yBase = size.height * 0.72;

    path.moveTo(0, size.height);
    path.lineTo(0, yBase);

    for (double x = 0; x <= size.width; x += 30) {
      final wave = math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi)) * 14.0;
      path.lineTo(x, yBase + wave);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.mode != mode;
  }
}
