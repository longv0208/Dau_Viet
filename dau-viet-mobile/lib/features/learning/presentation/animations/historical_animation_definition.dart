import 'package:flutter/material.dart';

/// ANIM-01/02 — Định nghĩa typed, immutable cho một cảnh hoạt họa lịch sử
/// tương tác. Engine chung KHÔNG chứa logic riêng của từng sự kiện — mọi
/// dữ liệu scene-specific nằm trong [SceneTransition] của từng bước.
class HistoricalAnimationStep {
  /// Nhãn ngắn của bước (hiển thị trong progress).
  final String label;

  /// Lời dẫn chính của bước — đọc được độc lập với motion.
  final String narration;

  /// Gợi ý ngữ cảnh tuỳ chọn (hint nhỏ, có thể ẩn).
  final String? hint;

  /// Trạng thái đích typed của scene cuối bước — null = giữ nguyên trạng
  /// thái hiện tại. Mỗi scene tự định nghĩa subclass (RiverSceneState,
  /// MapSceneState); player chỉ biết [SceneTransition.lerp].
  final SceneTransition? target;

  /// Tổng thời gian ở lại bước này khi AUTO (transition + hold) — ms.
  /// Bước không khai báo → definition.transitionDuration + hold mặc định.
  final int? durationMs;

  /// Easing của transition vào bước này — whitelist manifest
  /// {linear, easeIn, easeOut, easeInOut, easeInOutCubic}.
  final String easing;

  const HistoricalAnimationStep({
    required this.label,
    required this.narration,
    this.hint,
    this.target,
    this.durationMs,
    this.easing = 'easeInOut',
  });
}

/// Câu hỏi dự đoán khám phá — KHÔNG chấm điểm, không gửi server.
class AnimationPrediction {
  final String question;
  final List<String> options;

  /// Index đáp án khớp cơ chế minh họa — dùng để giải thích, không phải
  /// "điểm".
  final int explainedOptionIndex;
  final String explanation;

  /// Hint hiển thị khi learner chọn phương án chưa khớp cơ chế.
  final String retryHint;

  /// Hiệu ứng scene khi reveal — ví dụ MapScene hiển thị marker liên
  /// quan; river scene tự xử qua nước rút. null = không đổi trạng thái.
  final SceneTransition? revealSceneEffect;

  const AnimationPrediction({
    required this.question,
    required this.options,
    required this.explainedOptionIndex,
    required this.explanation,
    required this.retryHint,
    this.revealSceneEffect,
  });
}

/// Trạng thái đích typed của một bước — "điểm mở rộng nhỏ nhất" cho
/// ANIM-02: mỗi scene khai báo state riêng (nước/thuyền cho river,
/// marker/route cho map) thay vì tái dùng trường của scene khác.
///
/// `t` = tiến độ transition 0..1 (đã qua easing). `from` là snapshot
/// `captured()` lúc bắt đầu bước; scene tự quyết lerp hay apply-tức-thì.
abstract class SceneTransition {
  const SceneTransition();

  /// Áp trạng thái NỘI SUY giữa snapshot [from] (đóng băng MỘT lần lúc
  /// bắt đầu bước) và trạng thái đích này, ở tiến độ [t] 0..1 đã eased.
  /// Kết quả chỉ phụ thuộc (from, t) — độc lập số frame đã render trước.
  void applyFrom(
    HistoricalScenePainter painter,
    SceneTransition from,
    double t,
  );

  /// Snapshot trạng thái hiển thị hiện tại của painter thành một
  /// SceneTransition tương đương — làm `from` cho bước kế tiếp.
  SceneTransition captured(HistoricalScenePainter painter);
}

/// Scene painter trừu tượng — mỗi cảnh lịch sử tự vẽ bằng CustomPainter.
///
/// Player giữ MỘT painter instance suốt vòng đời widget, nên setters phải
/// [notifyListeners] — nếu không, RenderCustomPaint thấy cùng instance và
/// bỏ qua repaint (scene "đứng hình" dù state đã đổi).
///
/// Các setter waterLevel/boatProgress/boatsObstructed/highlightStakes là
/// no-op ở base class để giữ tương thích RiverScene — scene mới (map)
/// KHÔNG tái dùng chúng làm biến tiến độ bản đồ.
abstract class HistoricalScenePainter extends CustomPainter
    with ChangeNotifier {
  // --- Trạng thái riêng của river scene (no-op ở base, override ở
  // RiverScenePainter). Map scene dùng setter typed riêng của nó. ---
  double get waterLevel => 0.5;
  set waterLevel(double value) {}

  double get boatProgress => 0.0;
  set boatProgress(double value) {}

  bool get boatsObstructed => false;
  set boatsObstructed(bool value) {}

  /// Tô sáng điểm nhấn scene (bãi cọc / marker liên quan) sau khi
  /// reveal đáp án dự đoán.
  bool get highlightStakes => false;
  set highlightStakes(bool value) {}
}

/// Định nghĩa một hoạt họa lịch sử tương tác.
class HistoricalAnimationDefinition {
  /// Key ổn định có version — khớp `config.animationKey` trên server.
  final String key;
  final String title;
  final String learningObjective;
  final List<HistoricalAnimationStep> steps;
  final AnimationPrediction? prediction;

  /// Disclaimer lịch sử bắt buộc hiển thị.
  final String disclaimer;

  /// Nguồn tham khảo (tên + URL hiển thị dạng text).
  final String sourceReference;
  final Duration transitionDuration;

  /// Factory tạo painter riêng của scene.
  final HistoricalScenePainter Function() createPainter;

  /// Scene có slider mức nước không (chỉ river scene).
  final bool hasWaterControl;

  /// Cho phép chạm vào marker/địa điểm để mở panel giải thích (map
  /// scene). Player render overlay tương tác thay vì canvas thuần.
  final bool hasLocationExplorer;

  /// canvas.aspectRatio từ manifest — KHÔNG hard-code 16/10 ở player.
  final double aspectRatio;

  /// Chế độ phát khai báo trong READ config: AUTO (tự chạy hết),
  /// STEPPED (học viên tự bấm từng bước), INTERACTIVE (giữ các control
  /// tương tác như TAP_TO_EXPLORE / WATER_LEVEL_CONTROL).
  final String playbackMode;

  const HistoricalAnimationDefinition({
    required this.key,
    required this.title,
    required this.learningObjective,
    required this.steps,
    required this.disclaimer,
    required this.sourceReference,
    required this.createPainter,
    this.prediction,
    this.transitionDuration = const Duration(milliseconds: 900),
    this.hasWaterControl = false,
    this.hasLocationExplorer = false,
    this.aspectRatio = 16 / 10,
    this.playbackMode = 'AUTO',
  });
}
