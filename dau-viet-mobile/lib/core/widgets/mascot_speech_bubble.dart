import 'package:flutter/material.dart';

import '../theme/dau_viet_colors.dart';
import '../theme/dau_viet_typography.dart';
import 'kabi_mascot_widget.dart';

/// Khung thoại khích lệ và hướng dẫn của linh vật Rùa Kabi đội nón lá
/// Chuẩn UI/UX Pro Max cho ứng dụng lịch sử Dấu Việt.
class MascotSpeechBubble extends StatelessWidget {
  final String message;
  final KabiMood mood;
  final double avatarSize;
  final bool animate;

  const MascotSpeechBubble({
    super.key,
    required this.message,
    this.mood = KabiMood.guiding,
    this.avatarSize = 54.0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Hướng dẫn từ Kabi: $message',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Linh vật Kabi đội nón lá
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DauVietColors.parchmentSurface,
                border: Border.all(
                  color: DauVietColors.outlineVariant,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: KabiMascotWidget(
                  mood: mood,
                  width: avatarSize,
                  height: avatarSize,
                  headOnly: true,
                  enableSound: false,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Bong bóng thoại chỉ về phía Mascot
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DauVietColors.outlineVariant,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF8B4513,
                          ).withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.0,
                        height: 1.45,
                      ),
                    ),
                  ),

                  // Mũi nhọn bong bóng thoại (Speech bubble tail)
                  Positioned(
                    left: -6,
                    top: 14,
                    child: CustomPaint(
                      size: const Size(8, 12),
                      painter: _SpeechTailPainter(),
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
}

class _SpeechTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFE5DAC6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height / 2),
      borderPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
