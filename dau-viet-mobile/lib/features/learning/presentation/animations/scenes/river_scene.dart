import 'package:flutter/material.dart';

import '../../../../../core/theme/dau_viet_colors.dart';
import '../historical_animation_definition.dart';
import 'river_sequence_summary.dart';

/// ANIM-01 — Trạng thái đích typed của river scene: mực nước + tiến độ
/// thuyền + cờ mắc cọc. Scene khác (map) KHÔNG tái dùng class này làm
/// biến tiến độ — đúng nguyên tắc mở rộng của ANIM-02.
///
/// POLISH-BD-01 bổ sung 3 trường OPTIONAL với default an toàn — mọi
/// state cũ (không khai báo) vẫn render đúng: `decoyProgress` chỉ báo
/// dụ địch sơ đồ chiến thuật, `counterattackProgress` phản công phối
/// hợp, `showSequenceSummary` đổi canvas sang sơ đồ chuỗi 5 giai đoạn.
class RiverSceneState extends SceneTransition {
  final double waterLevel; // 0 = rút (đáy), 1 = dâng
  final double boatProgress; // 0..1 dọc đường đi
  final bool boatsObstructed;
  final bool highlightStakes;

  /// Tiến độ hiển thị của phần tử "dụ địch" 0..1 — thuyền phòng thủ
  /// đi TRƯỚC đoàn địch dẫn vào bãi cọc. Đây là chỉ báo sơ đồ chiến
  /// thuật, KHÔNG phải lộ trình được sử liệu ghi nhận. 0 = ẩn.
  final double decoyProgress;

  /// Tiến độ phản công phối hợp 0..1 — thuyền/mũi phòng thủ tiến vào
  /// khi thuyền địch mắc cọc. Chỉ minh họa hướng phối hợp, không phải
  /// đội hình hay vị trí thật. 0 = ẩn.
  final double counterattackProgress;

  /// Bước tổng kết: painter vẽ sơ đồ chuỗi 5 giai đoạn (Chuẩn bị →
  /// Nước dâng → Dụ địch → Mắc cọc → Phản công) thay cho cảnh sông.
  final bool showSequenceSummary;

  const RiverSceneState({
    required this.waterLevel,
    required this.boatProgress,
    this.boatsObstructed = false,
    this.highlightStakes = false,
    this.decoyProgress = 0,
    this.counterattackProgress = 0,
    this.showSequenceSummary = false,
  });

  @override
  void applyFrom(
    HistoricalScenePainter painter,
    SceneTransition from,
    double t,
  ) {
    if (painter is! RiverScenePainter) return;
    // Lerp từ snapshot ĐÓNG BĂNG — không phải painter hiện tại, nên kết
    // quả tại t độc lập với số frame đã render trước đó.
    final f = from is RiverSceneState ? from : null;
    painter
      ..waterLevel = _lerp(f?.waterLevel ?? painter.waterLevel, waterLevel, t)
      ..boatProgress = _lerp(
        f?.boatProgress ?? painter.boatProgress,
        boatProgress,
        t,
      )
      ..decoyProgress = _lerp(
        f?.decoyProgress ?? painter.decoyProgress,
        decoyProgress,
        t,
      )
      ..counterattackProgress = _lerp(
        f?.counterattackProgress ?? painter.counterattackProgress,
        counterattackProgress,
        t,
      )
      ..boatsObstructed = boatsObstructed
      ..highlightStakes = highlightStakes
      ..showSequenceSummary = showSequenceSummary;
  }

  @override
  SceneTransition captured(HistoricalScenePainter painter) {
    if (painter is! RiverScenePainter) return this;
    return RiverSceneState(
      waterLevel: painter.waterLevel,
      boatProgress: painter.boatProgress,
      boatsObstructed: painter.boatsObstructed,
      highlightStakes: painter.highlightStakes,
      decoyProgress: painter.decoyProgress,
      counterattackProgress: painter.counterattackProgress,
      showSequenceSummary: painter.showSequenceSummary,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

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

  /// Bãi cọc schematic override theo manifest (ANIM-03) — mỗi phần tử là
  /// (x, chiều dài theo h). null → dùng [_stakeField] mặc định, giữ
  /// nguyên hành vi scene hard-code cũ. KHÔNG phải bố trí khảo cổ thật.
  final List<Offset>? stakes;
  final List<bool>? stakeVisibility;

  RiverScenePainter({this.stakes, this.stakeVisibility});

  List<Offset> get _field => stakes ?? _stakeField;

  // --- Trạng thái tương tác — override setter của base class để
  // notifyListeners; map scene không dùng các trường này. ---
  double _waterLevel = 0.3;
  double _boatProgress = 0.0;
  bool _boatsObstructed = false;
  bool _highlightStakes = false;
  // POLISH-BD-01 — trạng thái tương tác mở rộng, chỉ RiverScenePainter
  // dùng (không đẩy lên base class để map scene không đụng vào).
  double _decoyProgress = 0.0;
  double _counterattackProgress = 0.0;
  bool _showSequenceSummary = false;

  @override
  double get waterLevel => _waterLevel;
  @override
  set waterLevel(double value) {
    if (value == _waterLevel) return;
    _waterLevel = value;
    notifyListeners();
  }

  @override
  double get boatProgress => _boatProgress;
  @override
  set boatProgress(double value) {
    if (value == _boatProgress) return;
    _boatProgress = value;
    notifyListeners();
  }

  @override
  bool get boatsObstructed => _boatsObstructed;
  @override
  set boatsObstructed(bool value) {
    if (value == _boatsObstructed) return;
    _boatsObstructed = value;
    notifyListeners();
  }

  @override
  bool get highlightStakes => _highlightStakes;
  @override
  set highlightStakes(bool value) {
    if (value == _highlightStakes) return;
    _highlightStakes = value;
    notifyListeners();
  }

  /// Tiến độ phần tử dụ địch hiện đang vẽ (0..1).
  double get decoyProgress => _decoyProgress;
  set decoyProgress(double value) {
    if (value == _decoyProgress) return;
    _decoyProgress = value;
    notifyListeners();
  }

  /// Tiến độ phản công phối hợp hiện đang vẽ (0..1).
  double get counterattackProgress => _counterattackProgress;
  set counterattackProgress(double value) {
    if (value == _counterattackProgress) return;
    _counterattackProgress = value;
    notifyListeners();
  }

  /// Đang vẽ sơ đồ chuỗi tổng kết thay cảnh sông.
  bool get showSequenceSummary => _showSequenceSummary;
  set showSequenceSummary(bool value) {
    if (value == _showSequenceSummary) return;
    _showSequenceSummary = value;
    notifyListeners();
  }

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

  /// Ngọn cọc i (px, x/y). `field` override từ manifest — null = mặc định.
  static Offset stakeTipFor(Size size, int index, [List<Offset>? field]) {
    final s = (field ?? _stakeField)[index];
    final baseY = bedTopFor(size.height);
    return Offset(s.dx * size.width, baseY - s.dy * size.height);
  }

  /// Base cọc i — luôn nằm trên đáy sông.
  static Offset stakeBaseFor(Size size, int index, [List<Offset>? field]) =>
      Offset(
        (field ?? _stakeField)[index].dx * size.width,
        bedTopFor(size.height),
      );

  /// Ngọn cọc có NHÔ khỏi mặt nước không. Canvas y tăng xuống → ngọn
  /// nằm TRÊN mặt nước khi tipY < surfaceY.
  static bool stakeTipExposed(double tipY, double surfaceY) => tipY < surfaceY;

  /// Đếm số ngọn cọc lộ trên mặt nước ở mức nước cho trước.
  static int exposedTipCount(
    Size size,
    double waterLevel, [
    List<Offset>? field,
  ]) {
    final f = field ?? _stakeField;
    final surfaceY = waterSurfaceYFor(size.height, waterLevel);
    var count = 0;
    for (var i = 0; i < f.length; i++) {
      if (stakeTipExposed(stakeTipFor(size, i, f).dy, surfaceY)) count++;
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

  /// POLISH-BD-01 — X của thuyền dụ địch (px). Trượt vào từ NGOÀI mép
  /// phải (1.10w) về phía trong (0.34w): đi trước đoàn địch, vượt qua
  /// bãi cọc (0.42w+) nhờ luồng an toàn. Thuần hàm của progress → không
  /// teleport; sơ đồ chiến thuật, không phải lộ trình sử liệu.
  static double decoyXFor(double width, double progress) {
    final p = progress.clamp(0.0, 1.0);
    return width * (1.10 - p * 0.76);
  }

  /// POLISH-BD-01 — X của thuyền phản công phòng thủ (px). Từ ngoài
  /// mép trái (-0.08w) tiến vào và DỪNG trước mép bãi cọc (0.42w) —
  /// quân phòng thủ không đâm vào bãi của chính mình. Hai lane lệch
  /// nhịp cho hiệu ứng "phối hợp"; thuần hàm của progress.
  static double counterattackXFor(
    double width,
    double progress,
    int laneIndex,
  ) {
    const lanes = [0.0, 0.25];
    final lane = lanes[laneIndex.clamp(0, lanes.length - 1)];
    final p = (progress - lane).clamp(0.0, 1.0);
    return width * (-0.08 + p * 0.40);
  }

  // ------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    // POLISH-BD-01: bước tổng kết vẽ sơ đồ chuỗi 5 giai đoạn thay cảnh
    // sông — cờ này áp tức thì (không lerp), giống semantics các cờ khác.
    if (_showSequenceSummary) {
      RiverSequenceSummary.paint(canvas, size);
      return;
    }

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

    // --- Phần tử dụ địch: vệt đường dẫn nét đứt NẰM TRÊN MẶT NƯỚC, vẽ
    // trước thuyền địch để thân thuyền địch đè lên vệt nếu chồng lấn.
    _paintDecoy(canvas, size, surfaceY);

    // --- Thuyền địch (stylized, KHÔNG phải mô hình lịch sử chính xác) ---
    _paintBoats(canvas, size, surfaceY);

    // --- Phản công phối hợp của quân phòng thủ (lớp trên cùng).
    _paintCounterattack(canvas, size, surfaceY);

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

    for (var i = 0; i < _field.length; i++) {
      if (stakeVisibility != null &&
          i < stakeVisibility!.length &&
          !stakeVisibility![i]) {
        continue; // manifest ẩn cọc này
      }
      final base = stakeBaseFor(size, i, _field);
      final top = stakeTipFor(size, i, _field);
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

    // Thuyền dụ địch — nhận diện bằng MÀU BUỒM xanh lục + vệt đường dẫn
    // nét đứt trên mặt nước, không chỉ phụ thuộc màu thân.
    if (decoyProgress > 0) {
      _paintSmallBoat(
        canvas,
        size,
        decoyXFor(w, decoyProgress),
        surfaceY - h * 0.014,
        sailColor: DauVietColors.natureGreen,
      );
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

  /// Thuyền nhỏ dùng chung (dụ địch / phản công): thân đậm, buồm theo
  /// phe — đỏ chu sa = địch, xanh lục = phòng thủ. Hình dạng stylized
  /// thống nhất với thuyền địch để rõ "cùng là thuyền, khác phe".
  void _paintSmallBoat(
    Canvas canvas,
    Size size,
    double x,
    double y, {
    required Color sailColor,
    double sailAlpha = 0.9,
  }) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(x, y);
    final hull = Path()
      ..moveTo(-w * 0.032, 0)
      ..lineTo(w * 0.032, 0)
      ..lineTo(w * 0.022, h * 0.018)
      ..lineTo(-w * 0.022, h * 0.018)
      ..close();
    canvas.drawPath(
      hull,
      Paint()
        ..color = const Color(0xFF4A3226)
        ..style = PaintingStyle.fill,
    );
    final sail = Path()
      ..moveTo(0, -h * 0.008)
      ..lineTo(0, -h * 0.042)
      ..lineTo(w * 0.020, -h * 0.008)
      ..close();
    canvas.drawPath(
      sail,
      Paint()
        ..color = sailColor.withValues(alpha: sailAlpha)
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  /// POLISH-BD-01 — Phần tử "dụ địch": vệt đường dẫn NÉT ĐỨT kéo từ
  /// thuyền dụ hiện tại về phía đoàn địch (bên phải), cùng nhãn 'Dụ
  /// địch'. Sơ đồ chiến thuật — không phải lộ trình được sử liệu ghi.
  void _paintDecoy(Canvas canvas, Size size, double surfaceY) {
    final w = size.width;
    final h = size.height;
    final p = decoyProgress.clamp(0.0, 1.0);
    if (p <= 0.01) return;

    // Vệt đường dẫn đứt nét từ thuyền dụ ra sau lưng (hướng địch tới).
    final dx = decoyXFor(w, p);
    final trailY = surfaceY - h * 0.004;
    final trail = Paint()
      ..color = DauVietColors.natureGreen.withValues(alpha: 0.75)
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Mỗi nét ~0.018w, hở 0.018w — nét đứt phân biệt hình với mũi tên
    // địch (liền nét).
    var seg = dx + w * 0.045; // bắt đầu ngay sau đuôi thuyền dụ
    while (seg < w * 0.98) {
      canvas.drawLine(
        Offset(seg, trailY),
        Offset((seg + w * 0.018).clamp(0, w), trailY),
        trail,
      );
      seg += w * 0.036;
    }

    // Nhãn chức năng — chữ thuộc lớp painter vì là phần của sơ đồ.
    _paintLabel(
      canvas,
      'Dụ địch',
      Offset(dx, surfaceY - h * 0.075),
      DauVietColors.natureGreen,
    );
  }

  /// POLISH-BD-01 — Phản công phối hợp: 2 thuyền phòng thủ tiến vào từ
  /// mép trái (lệch nhịp, không teleport) + mũi tên phối hợp hướng về
  /// thuyền địch đang mắc cọc. Dừng trước mép bãi cọc — quân phòng thủ
  /// đánh từ ngoài bãi, không tự đâm vào bẫy của mình.
  void _paintCounterattack(Canvas canvas, Size size, double surfaceY) {
    final w = size.width;
    final h = size.height;
    final p = counterattackProgress.clamp(0.0, 1.0);
    if (p <= 0.01) return;

    for (var i = 0; i < 2; i++) {
      final prog = (p - (i == 0 ? 0.0 : 0.25)).clamp(0.0, 1.0);
      if (prog <= 0) continue;
      // Hai tàu hai luồng: cùng nổi trên mặt nước, lệch nhẹ nhau dọc
      // để đọc rõ "phối hợp nhiều phần tử".
      final y = surfaceY - h * (i == 0 ? 0.030 : 0.012);
      _paintSmallBoat(
        canvas,
        size,
        counterattackXFor(w, p, i),
        y,
        sailColor: DauVietColors.natureGreen,
      );
    }

    // Mũi tên phối hợp phía trên bãi: hướng về bãi cọc/thuyền mắc —
    // nhấn mạnh "cùng đánh vào một điểm", không phải quay lui.
    final leadX = counterattackXFor(w, p, 0);
    if (leadX > w * 0.02) {
      final arrow = Paint()
        ..color = DauVietColors.cinnabarRedDark.withValues(alpha: 0.8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final ay = surfaceY - h * 0.105;
      final ax = (leadX + w * 0.05).clamp(0.0, w * 0.38);
      canvas.drawLine(Offset(ax, ay), Offset(ax + w * 0.07, ay), arrow);
      canvas.drawLine(
        Offset(ax + w * 0.07, ay),
        Offset(ax + w * 0.05, ay - h * 0.014),
        arrow,
      );
      canvas.drawLine(
        Offset(ax + w * 0.07, ay),
        Offset(ax + w * 0.05, ay + h * 0.014),
        arrow,
      );
    }

    _paintLabel(
      canvas,
      'Phản công',
      Offset(w * 0.16, surfaceY - h * 0.135),
      DauVietColors.cinnabarRedDark,
    );
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
  bool shouldRepaint(RiverScenePainter old) => false; // ChangeNotifier
  // điều khiển repaint — shouldRepaint luôn false vì player giữ cùng
  // instance và setters đã notifyListeners.
}
