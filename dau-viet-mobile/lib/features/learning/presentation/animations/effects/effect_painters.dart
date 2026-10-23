import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';

/// v2 — CustomPainter cho scene-level `effects[]` (typed overlay).
/// Mỗi painter là thuần hàm của progress/intensity/center — manifest chỉ
/// truyền param đã validate, không eventId, không code path riêng.
///
/// Z-order: các painter này nằm TRÊN painter canvas + object images
/// (layer +inf) nhưng DƯỚI caption/UI — bọc bởi [EffectOverlay] widget.

/// WATER_RIPPLE — vòng tròn mở rộng + mờ dần tại `center` (chuẩn hóa).
/// `progress` 0..1: 0 = chưa bắt đầu, 1 = vòng lớn nhất & gần trong suốt.
class WaterRipplePainter extends CustomPainter {
  final Offset center; // normalized 0..1
  final double progress; // 0..1
  final Color color;

  const WaterRipplePainter({
    required this.center,
    required this.progress,
    this.color = const Color(0xFF7BA7BC),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final p = Offset(center.dx * size.width, center.dy * size.height);
    // Bán kính tỉ lệ cạnh ngắn hơn của canvas — ripple nhỏ, không bao phủ.
    final maxR = size.shortestSide * 0.28;
    // Ba vòng lệch pha tạo cảm giác lan tỏa.
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final r = phase * maxR;
      final opacity = (1 - phase) * 0.55;
      if (r <= 0) continue;
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 + phase * 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(WaterRipplePainter old) =>
      old.progress != progress || old.center != center;
}

/// MIST — gradient sương mờ phủ cạnh trên + dưới canvas. `intensity`
/// 0..1 (default 0.5 — đủ bầu không khí, không che nội dung).
class MistPainter extends CustomPainter {
  final double intensity;

  const MistPainter({this.intensity = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final a = intensity.clamp(0.0, 1.0);
    if (a <= 0) return;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          DauVietColors.parchmentHigh.withValues(alpha: a * 0.85),
          DauVietColors.parchmentHigh.withValues(alpha: a * 0.15),
          Colors.transparent,
          DauVietColors.parchmentHigh.withValues(alpha: a * 0.5),
        ],
        stops: const [0.0, 0.28, 0.62, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(MistPainter old) => old.intensity != intensity;
}

/// GLOW — vệt sáng ấm quanh `center` (hoặc object resolved trước đó).
/// `intensity` 0..1; bán kính theo cạnh ngắn hơn canvas.
class GlowPainter extends CustomPainter {
  final Offset center;
  final double intensity;
  final Color color;

  const GlowPainter({
    required this.center,
    this.intensity = 0.5,
    this.color = const Color(0xFFE8B86D),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final a = intensity.clamp(0.0, 1.0);
    if (a <= 0) return;
    final p = Offset(center.dx * size.width, center.dy * size.height);
    final r = size.shortestSide * (0.22 + a * 0.18);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a * 0.5),
            color.withValues(alpha: a * 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
  }

  @override
  bool shouldRepaint(GlowPainter old) =>
      old.intensity != intensity || old.center != center;
}

/// FADE_IN / FADE_OUT — lớp phủ đen/parchment đơn giản. `opacity` đã
/// resolve theo chiều (FADE_IN: 1→0, FADE_OUT: 0→1) — painter chỉ vẽ.
class FadePainter extends CustomPainter {
  final double opacity;
  final Color color;

  const FadePainter({
    required this.opacity,
    this.color = DauVietColors.inkText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(FadePainter old) => old.opacity != opacity;
}

/// Một effect instance đã resolve sẵn painter + progress hiện tại —
/// player build list này mỗi tick và đưa cho [EffectOverlay].
class ResolvedEffect {
  final CustomPainter painter;

  const ResolvedEffect(this.painter);
}

/// EffectOverlay — Stack bọc quanh canvas painter + object layers: đặt
/// một [CustomPaint] per resolved effect ở lớp trên cùng của vùng scene
/// (vẫn trong camera transform, dưới caption/UI). Repaint theo
/// [repaint] listenable (master controller) — KHÔNG setState per frame.
class EffectOverlay extends StatelessWidget {
  final List<ResolvedEffect> effects;
  final Listenable repaint;
  final Widget child;

  const EffectOverlay({
    super.key,
    required this.effects,
    required this.repaint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (effects.isEmpty) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        for (final e in effects)
          RepaintBoundary(
            child: CustomPaint(
              painter: e.painter,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
}

/// Ripple oscillator — phase 0..1 lặp vô hạn với chu kỳ [periodMs];
/// player tick qua master controller thay vì Timer riêng.
double ripplePhase(double rawProgress, int periodMs, int stepDurationMs) {
  if (stepDurationMs <= 0) return rawProgress;
  final elapsed = rawProgress * stepDurationMs;
  final cycles = elapsed / math.max(1, periodMs);
  return cycles % 1.0;
}
