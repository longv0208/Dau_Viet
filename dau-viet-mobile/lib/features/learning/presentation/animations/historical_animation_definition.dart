import 'package:flutter/material.dart';

/// ANIM-01 — Định nghĩa typed, immutable cho một cảnh hoạt họa lịch sử
/// tương tác. Engine chung KHÔNG chứa logic riêng của Bạch Đằng — mọi
/// dữ liệu scene-specific nằm trong subclass [HistoricalScene].
class HistoricalAnimationStep {
  /// Nhãn ngắn của bước (hiển thị trong progress).
  final String label;

  /// Lời dẫn chính của bước — đọc được độc lập với motion.
  final String narration;

  /// Gợi ý ngữ cảnh tuỳ chọn (hint nhỏ, có thể ẩn).
  final String? hint;

  /// Mức nước schematic (0..1) mà scene hướng tới cuối bước — scene
  /// river dùng để animate water level theo bước; scene khác bỏ qua.
  final double? targetWaterLevel;

  /// Thuyền tiến vào (0..1 progress dọc bãi cọc) cuối bước — null = giữ.
  final double? targetBoatProgress;

  /// Thuyền bị cản (tilt) cuối bước.
  final bool? boatsObstructed;

  const HistoricalAnimationStep({
    required this.label,
    required this.narration,
    this.hint,
    this.targetWaterLevel,
    this.targetBoatProgress,
    this.boatsObstructed,
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

  const AnimationPrediction({
    required this.question,
    required this.options,
    required this.explainedOptionIndex,
    required this.explanation,
    required this.retryHint,
  });
}

/// Scene painter trừu tượng — mỗi cảnh lịch sử tự vẽ bằng CustomPainter.
/// Nhận progress + state tương tác (waterLevel cho river scene).
///
/// Player giữ MỘT painter instance suốt vòng đời widget, nên setters phải
/// [notifyListeners] — nếu không, RenderCustomPaint thấy cùng instance và
/// bỏ qua repaint (scene "đứng hình" dù state đã đổi).
abstract class HistoricalScenePainter extends CustomPainter
    with ChangeNotifier {
  /// Trạng thái tương tác hiện tại — player cập nhật trước mỗi repaint.
  double _waterLevel = 0.5;
  double _boatProgress = 0.0;
  bool _boatsObstructed = false;
  bool _highlightStakes = false;

  double get waterLevel => _waterLevel;
  set waterLevel(double value) {
    if (value == _waterLevel) return;
    _waterLevel = value;
    notifyListeners();
  }

  double get boatProgress => _boatProgress;
  set boatProgress(double value) {
    if (value == _boatProgress) return;
    _boatProgress = value;
    notifyListeners();
  }

  bool get boatsObstructed => _boatsObstructed;
  set boatsObstructed(bool value) {
    if (value == _boatsObstructed) return;
    _boatsObstructed = value;
    notifyListeners();
  }

  /// Tô sáng bãi cọc (sau khi reveal đáp án dự đoán).
  bool get highlightStakes => _highlightStakes;
  set highlightStakes(bool value) {
    if (value == _highlightStakes) return;
    _highlightStakes = value;
    notifyListeners();
  }
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

  /// Scene có slider mức nước không.
  final bool hasWaterControl;

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
  });
}
