import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../historical_animation_definition.dart';

/// ANIM-01 — Painter sông + bãi cọc schematic dùng chung cho scene dạng
/// "thủy triều / vật cản ngầm" (Bạch Đằng 938 là scene đầu tiên). Vẽ
/// vector bằng CustomPainter, tọa độ chuẩn hóa 0..1 — không phụ thuộc
/// asset ngoài, không pixel art, không ảnh khảo cổ.
///
/// Trục Y của canvas tăng XUỐNG: tip.dy < waterSurfaceY nghĩa là ngọn
/// cọc NHÔ lên khỏi mặt nước (exposed). Mực nước: 0 = rút (mặt nước ở
/// đáy 0.80h), 1 = dâng (mặt nước lên 0.20h).
///
/// Thuyền đi trên MỘT đường duy nhất theo boatProgress; boatsObstructed
/// chỉ đổi cách trình bày (nghiêng thân + ẩn mũi tên hướng đi), KHÔNG
/// đổi X → không teleport khi mắc cọc. Điểm dừng cuối nằm giữa bãi cọc
/// nên thuyền trực quan "vướng cọc" thay vì bị chặn ngoài mép.
class RiverScenePainter extends HistoricalScenePainter {
  /// Cao độ đáy sông (chuẩn hóa theo chiều cao canvas).
  static const double bedTopRatio = 0.80;

  /// Nhóm cọc schematic — KHÔNG phải bố trí khảo cổ thật. Mỗi phần tử:
  /// (x, chiều dài cọc tính theo h). Base luôn neo ở đáy sông; ngọn cao
  /// hơn/thấp hơn nhẹ để một số cọc lộ khi nước rút, tất cả chìm khi
  /// nước dâng cao.
  ///
  /// Điều kiện lộ ngọn: tip.dy < surfaceY ⇔ length > 0.80 - (0.80 - 0.60*wl)
  /// = 0.60*wl → ngọn lộ khi length > 0.60*waterLevel. Dải 0.16–0.24 cho
  /// ~6 ngọn lộ ở nước rút 0.30 và 0 ngọn lộ ở nước dâng 0.90.
  static const List<Offset> _stakeField = [
    Offset(0.42, 0.20),
    Offset(0.47, 0.22),
    Offset(0.52, 0.17),
    Offset(0.57, 0.24),
    Offset(0.62, 0.19),
    Offset(0.45, 0.16),
    Offset(0.55, 0.21),
    Offset(0.65, 0.23),
    Offset(0.60, 0.18),
  ];

  /// X-đích tối đa của thuyền khi đi hết đường (chuẩn hóa, từ phải qua).
  /// Đặt ~giữa bãi cọc (field chạy 0.42–0.65) để progress cuối của chuỗi
  /// kịch bản đưa thuyền NẰM TRONG bãi — đúng hình ảnh "mắc cọc".
  static const double _boatEndX = 0.50;

  // ------------------------------------------------------------------
  // Geometry helpers — tách ra static để widget test kiểm trực tiếp
  // hành vi vật lý schematic mà không cần đo pixel canvas.
  // ------------------------------------------------------------------

  /// Y mặt nước (px) theo chiều cao canvas và mức nước chuẩn hóa 0..1.
  static double waterSurfaceYFor(double height, double waterLevel) =>
      height * (bedTopRatio - 0.60 * waterLevel.clamp(0.0, 1.0));

  /// Y đáy sông (px).
  static double bedTopFor(double height) => height * bedTopRatio;

  /// Ngọn cọc i (px, x/y).
  static Offset stakeTipFor(Size size, int index) {
    final s = _stakeField[index];
    final baseY = bedTopFor(size.height);
    return Offset(s.dx * size.width, baseY - s.dy * size.height);
  }

  /// Base cọc i — luôn nằm trên đáy sông.
  static Offset stakeBaseFor(Size size, int index) =>
      Offset(_stakeField[index].dx * size.width, bedTopFor(size.height));

  /// Ngọn cọc có NHÔ khỏi mặt nước không. Canvas y tăng xuống → ngọn
  /// nằm TRÊN mặt nước khi tipY < surfaceY.
  static bool stakeTipExposed(double tipY, double surfaceY) => tipY < surfaceY;

  /// Đếm số ngọn cọc lộ trên mặt nước ở mức nước cho trước.
  static int exposedTipCount(Size size, double waterLevel) {
    final surfaceY = waterSurfaceYFor(size.height, waterLevel);
    var count = 0;
    for (var i = 0; i < _stakeField.length; i++) {
      if (stakeTipExposed(stakeTipFor(size, i).dy, surfaceY)) count++;
    }
    return count;
  }

  /// Vị trí X thuyền (px) — MỘT công thức duy nhất cho mọi trạng thái.
  /// lane = độ trễ của từng thuyền (0..0.36); progress clamp về [0,1].
  /// boatsObstructed KHÔNG nằm trong công thức này — cờ đó chỉ đổi cách
  /// trình bày (nghiêng/dừng auto-advance), nên bật/tắt không bao giờ
  /// teleport ngang.
  static double boatXFor(double width, double progress, int laneIndex) {
    const lanes = [0.0, 0.18, 0.36];
    final lane = lanes[laneIndex.clamp(0, lanes.length - 1)];
    final prog = (progress - lane).clamp(0.0, 1.0);
    // Đường duy nhất: x từ 1.05w (ngoài khơi) tới _boatEndX (giữa bãi).
    return width * (1.05 - prog * (1.05 - _boatEndX));
  }

  /// Mép TIẾN VÀO của bãi cọc (phía thuyền tới đến trước) — mốc để test
  /// kiểm thuyền đã "tới gần bãi" khi obstruction bật, KHÔNG phải giới
  /// hạn cứng vì hard-clamp trên đường đi sẽ teleport ngược khi thuyền
  /// đã vào sâu.
  static double stakeFieldEdgeX(double width) => width * 0.65;

  /// X hiển thị thực tế — đồng nhất với đường đi: obstruction không đổi
  /// vị trí ngang, nên display X = path X ở mọi cờ. Tham số giữ nguyên
  /// để call-site/test nhận diện rõ ý định "không đổi X khi mắc cọc".
  static double boatDisplayXFor(
    double width,
    double progress,
    int laneIndex,
    bool boatsObstructed,
  ) => boatXFor(width, progress, laneIndex);

  // ------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // --- Đáy sông (riverbed) ---
    paint.color = const Color(0xFF7A5A3E);
    final bedTop = bedTopFor(h);
    canvas.drawRect(Rect.fromLTRB(0, bedTop, w, h), paint);
    // Vân đất nhẹ ngay dưới mép đáy.
    paint.color = const Color(0x22613B28);
    canvas.drawRect(
      Rect.fromLTRB(0, bedTop, w, (bedTop + h * 0.02).clamp(0, h)),
      paint,
    );

    final surfaceY = waterSurfaceYFor(h, waterLevel);

    // --- Bãi cọc: vẽ TRƯỚC nước để nước che phần chìm ---
    _paintStakes(canvas, size, surfaceY);

    // --- Lớp nước ---
    final waterPaint = Paint()
      ..color = DauVietColors.riverBlue.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, surfaceY, w, bedTop), waterPaint);
    // Mặt nước — sóng nhẹ.
    final wavePaint = Paint()
      ..color = DauVietColors.riverBlue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final wave = Path()..moveTo(0, surfaceY);
    final waveAmp = h * 0.008;
    final waveLen = w / 10;
    for (var i = 0; i < 10; i++) {
      wave.quadraticBezierTo(
        waveLen * (i + 0.5),
        surfaceY + (i.isEven ? waveAmp : -waveAmp),
        waveLen * (i + 1),
        surfaceY,
      );
    }
    canvas.drawPath(wave, wavePaint);

    // --- Thuyền địch (stylized, KHÔNG phải mô hình lịch sử chính xác) ---
    _paintBoats(canvas, size, surfaceY);

    // --- Nhãn vùng (a11y — không chỉ dựa vào màu) ---
    _paintLabel(
      canvas,
      'Bãi cọc',
      Offset(w * 0.54, h * 0.86),
      DauVietColors.inkText,
    );
    _paintLabel(
      canvas,
      waterLevel > 0.55 ? 'Nước dâng' : 'Nước rút',
      Offset(w * 0.10, (surfaceY - h * 0.03).clamp(0.0, h)),
      DauVietColors.riverBlue,
    );
  }

  void _paintStakes(Canvas canvas, Size size, double surfaceY) {
    final w = size.width;
    final basePaint = Paint()
      ..color = DauVietColors.woodBrown
      ..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = DauVietColors.cinnabarRed
      ..style = PaintingStyle.fill;
    final submergedPaint = Paint()
      // Cọc chìm: mờ hơn + mảnh hơn — phân biệt bằng độ đậm/hình, không
      // chỉ bằng màu.
      ..color = DauVietColors.woodBrown.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final stakeW = w * 0.016;

    for (var i = 0; i < _stakeField.length; i++) {
      final base = stakeBaseFor(size, i);
      final top = stakeTipFor(size, i);
      final exposed = stakeTipExposed(top.dy, surfaceY);
      final p = exposed
          ? (highlightStakes ? highlightPaint : basePaint)
          : submergedPaint;
      // Thân cọc: từ đáy lên ngọn — base luôn neo vào riverbed.
      canvas.drawRect(
        Rect.fromLTWH(base.dx - stakeW / 2, top.dy, stakeW, base.dy - top.dy),
        p,
      );
      // Ngọn nhọn — chỉ vẽ rõ khi cọc còn lộ; cọc chìm vẫn có ngọn
      // nhưng đã mờ cùng thân.
      final tip = Path()
        ..moveTo(base.dx - stakeW / 2, top.dy)
        ..lineTo(base.dx, top.dy - stakeW * 1.6)
        ..lineTo(base.dx + stakeW / 2, top.dy)
        ..close();
      canvas.drawPath(tip, p);
      // Ngọn lộ → vệt trắng đánh dấu điểm nhô (không chỉ dùng màu).
      if (exposed) {
        final markPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(base.dx - stakeW * 0.6, top.dy - stakeW * 0.9),
          Offset(base.dx + stakeW * 0.6, top.dy - stakeW * 0.9),
          markPaint,
        );
        // Vành highlight quanh ngọn khi prediction reveal.
        if (highlightStakes) {
          final ringPaint = Paint()
            ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.55)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(
            top - Offset(0, stakeW * 0.8),
            stakeW * 1.4,
            ringPaint,
          );
        }
      }
    }
  }

  void _paintBoats(Canvas canvas, Size size, double surfaceY) {
    // Ba thuyền địch stylized tiến từ phải sang trái trên MỘT đường đi.
    // boatProgress 0 = ngoài khơi, 1 = đã đi hết đường qua bãi cọc.
    final w = size.width;
    final h = size.height;
    final boatPaint = Paint()
      ..color = const Color(0xFF4A3226)
      ..style = PaintingStyle.fill;
    final sailPaint = Paint()
      ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    const lanes = [0.0, 0.18, 0.36];
    for (var i = 0; i < lanes.length; i++) {
      final prog = (boatProgress - lanes[i]).clamp(0.0, 1.0);
      if (prog <= 0) continue;
      final x = boatDisplayXFor(w, boatProgress, i, boatsObstructed);
      // Thuyền nổi trên mặt nước — y theo surfaceY hiện tại, đổi mực
      // nước chỉ nhấc/hạ thuyền, KHÔNG dịch chuyển ngang.
      final y = surfaceY - h * 0.012;
      final tilt = boatsObstructed ? 0.10 : 0.0;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tilt);
      // Thân thuyền stylized.
      final hull = Path()
        ..moveTo(-w * 0.045, 0)
        ..lineTo(w * 0.045, 0)
        ..lineTo(w * 0.030, h * 0.022)
        ..lineTo(-w * 0.030, h * 0.022)
        ..close();
      canvas.drawPath(hull, boatPaint);
      // Buồm tam giác đơn giản.
      final sail = Path()
        ..moveTo(0, -h * 0.010)
        ..lineTo(0, -h * 0.055)
        ..lineTo(w * 0.028, -h * 0.010)
        ..close();
      canvas.drawPath(sail, sailPaint);
      canvas.restore();
    }

    // Mũi tên hướng tiến (educational, chỉ khi thuyền đang đi).
    if (boatProgress > 0 && boatProgress < 1 && !boatsObstructed) {
      final arrow = Paint()
        ..color = DauVietColors.cinnabarRed.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final ax = w * 0.80;
      final ay = surfaceY - h * 0.10;
      canvas.drawLine(Offset(ax + w * 0.08, ay), Offset(ax, ay), arrow);
      canvas.drawLine(
        Offset(ax + w * 0.02, ay - h * 0.015),
        Offset(ax, ay),
        arrow,
      );
      canvas.drawLine(
        Offset(ax + w * 0.02, ay + h * 0.015),
        Offset(ax, ay),
        arrow,
      );
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(RiverScenePainter old) =>
      old.waterLevel != waterLevel ||
      old.boatProgress != boatProgress ||
      old.boatsObstructed != boatsObstructed ||
      old.highlightStakes != highlightStakes;
}
