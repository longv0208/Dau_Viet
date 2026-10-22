import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import 'historical_animation_controls.dart';
import 'historical_animation_definition.dart';
import 'widgets/prediction_block.dart';
import 'widgets/skipped_scene.dart';
import 'widgets/water_level_control.dart';

/// ANIM-01 — Player tái dùng cho mọi scene đã đăng ký. State cục bộ
/// (waterLevel, boatProgress, obstructed, step, prediction) — không
/// chia sẻ giữa các instance; dispose() dừng timer + controller an
/// toàn. Reduced-motion: bỏ qua tween, hiển thị trạng thái tĩnh ngay.
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

  // Trạng thái scene hiển thị ngay lập tức (không qua tween khi user
  // kéo slider hoặc reduced-motion).
  double _waterLevel = 0.3;
  double _boatProgress = 0.0;
  bool _boatsObstructed = false;
  bool _highlightStakes = false;

  // Mốc bắt đầu tween hiện tại.
  double _waterFrom = 0.3;
  double _boatFrom = 0.0;

  int _stepIndex = 0;
  bool _playing = false;
  bool _skipped = false;
  Timer? _advanceTimer;

  // Dự đoán khám phá — state cục bộ, không gửi server.
  int? _chosenOption;
  bool _predictionRevealed = false;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  HistoricalAnimationStep get _step => widget.definition.steps[_stepIndex];

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
    setState(() {
      _waterLevel = _lerp(_waterFrom, _step.targetWaterLevel ?? _waterFrom, t);
      _boatProgress = _lerp(
        _boatFrom,
        _step.targetBoatProgress ?? _boatFrom,
        t,
      );
      _syncPainter();
    });
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Áp trạng thái đích của bước: tween mượt nếu motion bật, nhảy tĩnh
  /// nếu reduced-motion. `animate=false` cho khởi tạo/replay nhanh.
  void _applyStep(int index, {bool animate = true}) {
    final step = widget.definition.steps[index];
    _waterFrom = _waterLevel;
    _boatFrom = _boatProgress;
    _boatsObstructed = step.boatsObstructed ?? _boatsObstructed;
    _highlightStakes = _predictionRevealed;
    if (animate && !_reduceMotion) {
      _controller
        ..stop()
        ..reset()
        ..forward();
    } else {
      _waterLevel = step.targetWaterLevel ?? _waterLevel;
      _boatProgress = step.targetBoatProgress ?? _boatProgress;
      _controller.stop();
    }
    _syncPainter();
  }

  void _syncPainter() {
    _painter
      ..waterLevel = _waterLevel
      ..boatProgress = _boatProgress
      ..boatsObstructed = _boatsObstructed
      ..highlightStakes = _highlightStakes;
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
    if (_playing || _stepIndex < widget.definition.steps.length - 1) {
      setState(() {
        _playing = !_playing;
        _skipped = false;
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
      _applyStep(index);
    });
    _scheduleAdvance();
  }

  void _replay() {
    _advanceTimer?.cancel();
    setState(() {
      _stepIndex = 0;
      _skipped = false;
      _highlightStakes = _predictionRevealed;
      _waterLevel = 0.3;
      _boatProgress = 0;
      _boatsObstructed = false;
      _applyStep(0, animate: false);
    });
    _scheduleAdvance();
  }

  void _skip() {
    _advanceTimer?.cancel();
    setState(() {
      _playing = false;
      _skipped = true;
      _stepIndex = widget.definition.steps.length - 1;
      _applyStep(_stepIndex, animate: false);
    });
  }

  void _setWater(double v) {
    _advanceTimer?.cancel();
    setState(() {
      _playing = false; // thao tác tay → không auto-advance
      _controller.stop(); // thao tác tay thắng tween đang chạy
      _waterLevel = v.clamp(0.0, 1.0);
      _waterFrom = _waterLevel;
      _syncPainter();
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
      _highlightStakes = true;
      // Đưa scene về trạng thái nước rút để minh họa cơ chế.
      _waterFrom = _waterLevel;
      _waterLevel = 0.22;
      _boatsObstructed = _boatProgress > 0;
      _syncPainter();
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
                child: _skipped
                    ? const SkippedScene()
                    : CustomPaint(painter: _painter),
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
}
