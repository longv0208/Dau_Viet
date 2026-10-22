import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import 'historical_animation_controls.dart';
import 'historical_animation_definition.dart';
import 'scenes/historical_map_scene.dart';
import 'widgets/location_info_panel.dart';
import 'widgets/map_marker_overlay.dart';
import 'widgets/prediction_block.dart';
import 'widgets/skipped_scene.dart';
import 'widgets/water_level_control.dart';

/// ANIM-01/02 — Player tái dùng cho mọi scene đã đăng ký. State cục bộ
/// (step, transition hiện tại, prediction, marker selection) — không
/// chia sẻ giữa các instance; dispose() dừng timer + controller an
/// toàn. Reduced-motion: bỏ qua tween, hiển thị trạng thái tĩnh ngay.
///
/// ANIM-02 mở rộng qua [SceneTransition]: mỗi bước mang target typed,
/// player chỉ snapshot + lerp — không biết field cụ thể của scene.
class HistoricalAnimationPlayer extends StatefulWidget {
  final HistoricalAnimationDefinition definition;

  const HistoricalAnimationPlayer({super.key, required this.definition});

  @override
  State<HistoricalAnimationPlayer> createState() =>
      _HistoricalAnimationPlayerState();
}

class _HistoricalAnimationPlayerState extends State<HistoricalAnimationPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final HistoricalScenePainter _painter;

  // Transition đang hiển thị — target typed của bước hiện tại.
  SceneTransition? _current;

  // Snapshot ĐÓNG BĂNG của trạng thái painter lúc transition bắt đầu —
  // lerp luôn tính từ đây, KHÔNG từ painter hiện tại, nên kết quả tại
  // tiến độ t độc lập với số frame đã render.
  SceneTransition? _tweenFrom;

  int _stepIndex = 0;
  bool _playing = false;
  bool _skipped = false;
  Timer? _advanceTimer;

  // true chỉ khi learner bấm TẠM DỪNG giữa một tween đang chạy — nghĩa là
  // controller.value dở dang VÀ learner muốn nối tiếp nó khi bấm PHÁT.
  // Các hàm hủy tween (_setWater/_revealPrediction/_selectLocation…) phải
  // xóa cờ này.
  bool _tweenPaused = false;

  // Dự đoán khám phá — state cục bộ, không gửi server.
  int? _chosenOption;
  bool _predictionRevealed = false;

  // Địa điểm đang chọn trên map (ANIM-02) — local UI state.
  String? _selectedLocationId;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  HistoricalAnimationStep get _step => widget.definition.steps[_stepIndex];

  // --- Thuộc tính river để widget + test đọc/kéo — map scene bỏ qua vì
  // painter không override các setter này. ---
  double get _waterLevel => _painter.waterLevel;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.definition.transitionDuration,
    )..addListener(_onTick);
    _painter = widget.definition.createPainter();
    _applyStep(0, animate: false);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _controller.dispose();
    _painter.dispose(); // ChangeNotifier — giải phóng listener.
    super.dispose();
  }

  void _onTick() {
    final t = Curves.easeInOut.transform(_controller.value);
    setState(() => _applyCurrent(t));
  }

  /// Áp transition đích ở tiến độ t — lerp từ snapshot đóng băng
  /// [_tweenFrom]. from == null nghĩa là t = 1 áp thẳng.
  void _applyCurrent(double t) {
    final target = _current;
    if (target == null) return;
    if (t >= 1 || _tweenFrom == null) {
      _tweenFrom = null;
      target.applyFrom(_painter, target, 1);
    } else {
      target.applyFrom(_painter, _tweenFrom!, t);
    }
  }

  /// Áp trạng thái đích của bước: tween mượt nếu motion bật, nhảy tĩnh
  /// nếu reduced-motion. `animate=false` cho khởi tạo/replay nhanh.
  /// Bước có `target == null` giữ nguyên trạng thái hiện tại.
  void _applyStep(int index, {bool animate = true}) {
    final step = widget.definition.steps[index];
    if (step.target != null) {
      _current = step.target;
      // Chụp trạng thái ĐANG HIỂN THỊ (kể cả tween cũ đang dở) làm gốc —
      // chuyển bước giữa chừng không nhảy, mượt từ vị trí hiện tại.
      _tweenFrom = _current!.captured(_painter);
    }
    if (animate && !_reduceMotion && step.target != null) {
      _controller
        ..stop()
        ..reset()
        ..forward();
    } else {
      _controller.stop();
      _applyCurrent(1);
    }
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    if (!_playing) return;
    final delay = _reduceMotion
        ? const Duration(seconds: 4) // cho đọc khi không có motion
        : widget.definition.transitionDuration +
              const Duration(milliseconds: 2200);
    _advanceTimer = Timer(delay, () {
      if (!mounted || !_playing) return;
      if (_stepIndex < widget.definition.steps.length - 1) {
        setState(() {
          _stepIndex++;
          _applyStep(_stepIndex);
        });
        _scheduleAdvance();
      } else {
        setState(() => _playing = false);
      }
    });
  }

  void _togglePlay() {
    if (_playing) {
      // PAUSE: đóng băng ngay cả tween đang chạy — không chỉ hủy timer.
      // Đánh dấu đây là PAUSE chủ động để resume nối tiếp đúng tween này.
      _advanceTimer?.cancel();
      setState(() {
        _playing = false;
        _tweenPaused = _controller.value > 0 && _controller.value < 1;
        _controller.stop();
      });
    } else if (_stepIndex < widget.definition.steps.length - 1) {
      // RESUME: chỉ nối tiếp tween khi learner đã PAUSE nó chủ động.
      // Tween bị thao tác tay/reveal hủy giữa chừng cũng để lại value dở
      // dang — KHÔNG được forward, nếu không nó ghi đè lựa chọn của
      // learner.
      final resumeTween = _tweenPaused;
      setState(() {
        _playing = true;
        _skipped = false;
        _tweenPaused = false;
        if (resumeTween) _controller.forward();
      });
      _scheduleAdvance();
    } else {
      // Đang ở bước cuối và bấm PHÁT → tua lại rồi phát tiếp.
      setState(() {
        _playing = true;
        _skipped = false;
      });
      _replay();
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.definition.steps.length) return;
    _advanceTimer?.cancel();
    setState(() {
      _stepIndex = index;
      _skipped = false;
      _tweenPaused = false; // tween mới, không phải pause
      _selectedLocationId = null; // panel cũ không sống qua bước mới
      _applyStep(index);
    });
    _scheduleAdvance();
  }

  void _replay() {
    _advanceTimer?.cancel();
    setState(() {
      _stepIndex = 0;
      _skipped = false;
      _tweenPaused = false;
      // Reset scene + xóa mọi state tương tác — replay là "xem lại từ
      // đầu", không giữ lựa chọn/reveal/marker cũ.
      _chosenOption = null;
      _predictionRevealed = false;
      _selectedLocationId = null;
      _applyStep(0, animate: false);
    });
    _scheduleAdvance();
  }

  void _skip() {
    _advanceTimer?.cancel();
    setState(() {
      _playing = false;
      _skipped = true;
      _tweenPaused = false;
      _stepIndex = widget.definition.steps.length - 1;
      _applyStep(_stepIndex, animate: false);
    });
  }

  /// Chỉ river scene dùng — map painter có setter no-op nên không ảnh
  /// hưởng; giữ hành vi ANIM-01 (kéo tay thắng tween).
  void _setWater(double v) {
    _advanceTimer?.cancel();
    setState(() {
      _playing = false; // thao tác tay → không auto-advance
      _tweenPaused = false; // HỦY tween, không phải pause
      _controller.stop(); // thao tác tay thắng tween đang chạy
      _painter.waterLevel = v.clamp(0.0, 1.0);
      // Snapshot lại gốc để transition kế tiếp lerp từ giá trị tay.
      _tweenFrom = _current?.captured(_painter);
    });
  }

  void _selectLocation(String? id) {
    _advanceTimer?.cancel();
    setState(() {
      // Chạm marker = TẠM DỪNG khám phá: settle scene về trạng thái đích
      // của bước hiện tại (deterministic), UI về PHÁT, không timer mới.
      // Tween bị hủy KHÔNG được resume — không phải pause-để-tiếp-tục.
      _playing = false;
      _tweenPaused = false;
      _controller.stop();
      _selectedLocationId = id == _selectedLocationId ? null : id;
      _applyCurrent(1); // chốt bước hiện tại về trạng thái ổn định
    });
  }

  void _choosePrediction(int i) {
    setState(() => _chosenOption = i);
  }

  void _revealPrediction() {
    if (_chosenOption == null) return;
    _advanceTimer?.cancel();
    setState(() {
      _playing = false;
      _predictionRevealed = true;
      _tweenPaused = false; // HỦY tween, không phải pause
      // Dừng tween đang chạy NGAY — nếu không nó sẽ ghi đè trạng thái
      // reveal.
      _controller.stop();
      // Hiệu ứng reveal: scene tự quyết (map → highlight marker; river →
      // ép nước rút + highlight cọc qua highlightStakes).
      final effect = widget.definition.prediction?.revealSceneEffect;
      if (effect != null) {
        _current = effect;
        _tweenFrom = null;
        _applyCurrent(1); // áp thẳng — tween cũ không ghi đè được
      } else {
        // River scene fallback: đưa về nước rút + đánh dấu cọc.
        _painter
          ..waterLevel = 0.22
          ..boatsObstructed = _painter.boatProgress > 0
          ..highlightStakes = true;
        _tweenFrom = _current?.captured(_painter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.definition;
    final pred = def.prediction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Khung hình ---
        Semantics(
          label:
              'Sơ đồ minh họa ${def.title}. Bước ${_stepIndex + 1}: '
              '${_step.label}',
          image: true,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: DauVietColors.parchmentHigh,
                child: _skipped ? const SkippedScene() : _buildSceneCanvas(def),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // --- Lời dẫn + disclaimer + nguồn ---
        Text(
          _step.label.toUpperCase(),
          style: DauVietTypography.labelSmall.copyWith(
            color: DauVietColors.cinnabarRed,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _step.narration,
          style: DauVietTypography.bodyMedium.copyWith(
            color: DauVietColors.inkText,
            height: 1.55,
            fontSize: 14,
          ),
        ),
        if (_step.hint != null && !_predictionRevealed) ...[
          const SizedBox(height: 4),
          Text(
            '💡 ${_step.hint}',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          def.disclaimer,
          style: DauVietTypography.bodySmall.copyWith(
            color: DauVietColors.inkMuted,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
        Text(
          'Nguồn: ${def.sourceReference}',
          style: DauVietTypography.bodySmall.copyWith(
            color: DauVietColors.inkMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),

        // --- Điều khiển nước (river scenes) ---
        if (def.hasWaterControl && !_skipped) ...[
          WaterLevelControl(value: _waterLevel, onChanged: _setWater),
          const SizedBox(height: 8),
        ],

        // --- Điều khiển phát ---
        HistoricalAnimationControls(
          playing: _playing,
          canPrev: _stepIndex > 0,
          canNext: _stepIndex < def.steps.length - 1,
          stepIndex: _stepIndex,
          stepCount: def.steps.length,
          onPlayPause: _togglePlay,
          onPrev: () => _goTo(_stepIndex - 1),
          onNext: () => _goTo(_stepIndex + 1),
          onReplay: _replay,
          onSkip: _skip,
        ),

        // --- Panel thông tin địa điểm (map scenes) ---
        if (def.hasLocationExplorer && !_skipped) ...[
          const SizedBox(height: 8),
          LocationInfoPanel(
            painter: _painter,
            selectedId: _selectedLocationId,
            onClose: () => _selectLocation(null),
          ),
        ],

        // --- Dự đoán khám phá ---
        if (pred != null && !_skipped) ...[
          const SizedBox(height: 10),
          PredictionBlock(
            prediction: pred,
            chosen: _chosenOption,
            revealed: _predictionRevealed,
            onChoose: _choosePrediction,
            onReveal: _revealPrediction,
          ),
        ],
      ],
    );
  }

  /// Marker được coi là "active" khi bước hiện tại (hoặc hiệu ứng
  /// reveal) muốn nó hiện — dựa trên target transition, KHÔNG dựa trên
  /// giá trị đang nội suy của painter, nên overlay mount ổn định ngay
  /// cả khi tween mới bắt đầu.
  bool _locationActive(MapScenePainter mp, String id) {
    final t = _current;
    if (t is MapSceneState && (t.markerVisibility[id] ?? 0) > 0.02) {
      return true;
    }
    // Fallback: tween đã hủy/settle — giữ overlay nếu marker đang hiện.
    return (mp.markerVisibility[id] ?? 0) > 0.02;
  }

  Widget _buildSceneCanvas(HistoricalAnimationDefinition def) {
    final paint = CustomPaint(painter: _painter);
    // Map scene: overlay marker TẤP được trên canvas — touch target ≥
    // 44px, semantics tiếng Việt, không dùng raw canvas hit-testing.
    final painter = _painter;
    if (def.hasLocationExplorer && painter is MapScenePainter) {
      final mp = painter;
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              paint,
              // Mount overlay theo TARGET của bước (deterministic), không
              // theo visibility đang tween — tránh phụ thuộc frame kết
              // cuối và marker vẫn tấp được khi đang fade-in.
              for (final loc in mp.locations)
                if (_locationActive(mp, loc.id))
                  MapMarkerOverlay(
                    location: loc,
                    canvasSize: size,
                    selected: _selectedLocationId == loc.id,
                    onTap: () => _selectLocation(loc.id),
                  ),
            ],
          );
        },
      );
    }
    return paint;
  }
}
