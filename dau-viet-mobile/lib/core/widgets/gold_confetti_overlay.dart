import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hiệu ứng pháo hoa ánh vàng & cánh sen bay (Gold Confetti / Particle Overlay)
/// Dùng để ăn mừng khi người học vượt qua câu đố khó hoặc mở rộng Đảo Di Sản.
class GoldConfettiOverlay extends StatefulWidget {
  final bool trigger;
  final int triggerCount;
  final Widget child;

  const GoldConfettiOverlay({
    super.key,
    required this.trigger,
    this.triggerCount = 0,
    required this.child,
  });

  @override
  State<GoldConfettiOverlay> createState() => _GoldConfettiOverlayState();
}

class _GoldConfettiOverlayState extends State<GoldConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (widget.trigger || widget.triggerCount > 0) {
      _startConfetti();
    }
  }

  @override
  void didUpdateWidget(covariant GoldConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final triggeredByBool = widget.trigger && !oldWidget.trigger;
    final triggeredByCount = widget.triggerCount > oldWidget.triggerCount;
    if (triggeredByBool || triggeredByCount) {
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduceMotion) {
        _startConfetti();
      }
    }
  }

  void _startConfetti() {
    _particles.clear();
    for (int i = 0; i < 50; i++) {
      _particles.add(_Particle.random(_random));
    }
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating &&
                (_controller.value == 0.0 || _controller.value == 1.0)) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _controller.value,
                    particles: _particles,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

enum _ParticleType { coin, petal, sparkle }

class _Particle {
  final double startX;
  final double startY;
  final double vx;
  final double vy;
  final double size;
  final double rotationSpeed;
  final Color color;
  final _ParticleType type;

  _Particle({
    required this.startX,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotationSpeed,
    required this.color,
    required this.type,
  });

  factory _Particle.random(math.Random random) {
    final colors = [
      const Color(0xFFE7B451),
      const Color(0xFFFFD572),
      const Color(0xFFA51F18),
      const Color(0xFFE28D78),
      const Color(0xFFD4AF37),
    ];

    final type =
        _ParticleType.values[random.nextInt(_ParticleType.values.length)];

    return _Particle(
      startX: 0.2 + (random.nextDouble() * 0.6),
      startY: 0.35 + (random.nextDouble() * 0.2),
      vx: (random.nextDouble() - 0.5) * 450,
      vy: -220 - (random.nextDouble() * 320),
      size: 6.0 + (random.nextDouble() * 7.0),
      rotationSpeed: (random.nextDouble() - 0.5) * 12.0,
      color: colors[random.nextInt(colors.length)],
      type: type,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0 || progress == 1.0) return;

    final t = progress;
    final gravity = 700.0 * t * t;
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = (p.startX * size.width) + (p.vx * t);
      final y = (p.startY * size.height) + (p.vy * t) + gravity;
      final rotation = p.rotationSpeed * t * math.pi;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      switch (p.type) {
        case _ParticleType.coin:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case _ParticleType.petal:
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.5,
              height: p.size * 0.7,
            ),
            paint,
          );
          break;
        case _ParticleType.sparkle:
          final path = Path()
            ..moveTo(0, -p.size)
            ..lineTo(p.size * 0.3, -p.size * 0.3)
            ..lineTo(p.size, 0)
            ..lineTo(p.size * 0.3, p.size * 0.3)
            ..lineTo(0, p.size)
            ..lineTo(-p.size * 0.3, p.size * 0.3)
            ..lineTo(-p.size, 0)
            ..lineTo(-p.size * 0.3, -p.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
