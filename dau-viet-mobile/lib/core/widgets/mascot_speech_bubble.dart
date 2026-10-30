import 'package:flutter/material.dart';

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
        padding: const EdgeInsets.fromLTRB(14, 2, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Linh vật Rùa Kabi đội nón lá cầm sách lịch sử (khớp ảnh mẫu #3, #4, #5, #6)
            SizedBox(
              width: avatarSize + 8,
              height: avatarSize,
              child: KabiMascotWidget(
                mood: mood,
                width: avatarSize + 8,
                height: avatarSize,
                headOnly: true,
                enableSound: false,
              ),
            ),
            const SizedBox(width: 8),

            // Bong bóng thoại giấy kem viền vàng ấm chỉ về phía Mascot
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFDEC8A2),
                        width: 1.3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x145D4024),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: DauVietTypography.headlineSmall.copyWith(
                        color: const Color(0xFF2B1F17),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        height: 1.38,
                      ),
                    ),
                  ),

                  // Mũi nhọn bong bóng thoại (Speech bubble tail)
                  Positioned(
                    left: -7,
                    top: 16,
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
      ..color = const Color(0xFFFFFDF8)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFDEC8A2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
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
