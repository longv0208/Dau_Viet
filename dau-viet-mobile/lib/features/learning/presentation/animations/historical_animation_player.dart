import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../renderers/learning_asset_image.dart' show fetchLearningAssetBytes;
import 'historical_animation_controls.dart';
import 'historical_animation_definition.dart';
import 'runtime/animation_audio_controller.dart';
import 'runtime/animation_manifest_dto.dart';
import 'runtime/cinematic_state.dart';
import 'scenes/historical_map_scene.dart';
import 'widgets/location_info_panel.dart';
import 'widgets/manifest_asset_layers.dart';
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
class HistoricalAnimationPlayer extends ConsumerStatefulWidget {
  final HistoricalAnimationDefinition definition;

  /// v2 — manifest nguồn (khi có) chứa camera/tracks/effects/audio.
  /// Null = scene v1/legacy → player render y nguyên, không cinematic.
  final AnimationManifestDto? manifest;

  /// Frame cinematic hiện tại — ManifestAssetLayers lắng nghe để áp
  /// camera transform + object visual state. Expose ra ngoài để wrapper
  /// không phải tự tính timeline.
  final ValueNotifier<CinematicFrame>? cinematicFrame;

  const HistoricalAnimationPlayer({
    super.key,
    required this.definition,
    this.manifest,
    this.cinematicFrame,
  });

  @override
  ConsumerState<HistoricalAnimationPlayer> createState() =>
      _HistoricalAnimationPlayerState();
}

class _HistoricalAnimationPlayerState
    extends ConsumerState<HistoricalAnimationPlayer>
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

  /// P0 — khối dự đoán hiển thị tại đúng bước checkpoint: bước khai
  /// báo allowedInteractions ["PREDICTION"], hoặc prediction.stepIndex
  /// của scene v1 (parity hành vi). null → không bước nào hiển thị.
  int? get _predictionStepIndex {
    final pred = widget.definition.prediction;
    if (pred == null) return null;
    for (var i = 0; i < widget.definition.steps.length; i++) {
      if (widget.definition.steps[i].allowedInteractions.contains(
        'PREDICTION',
      )) {
        return i;
      }
    }
    return pred.stepIndex;
  }

  bool get _predictionVisibleAtCurrentStep =>
      _predictionStepIndex == _stepIndex;

  // Địa điểm đang chọn trên map (ANIM-02) — local UI state.
  String? _selectedLocationId;

  /// Curve áp cho tween hiện tại — mỗi bước có thể chọn easing riêng.
  Curve _stepCurve = Curves.easeInOut;

  /// v2 — evaluator cinematic (camera + tracks) lấy từ manifest; null
  /// khi scene v1/legacy (không cinematic key nào).
  CinematicEvaluator? get _cinematic => widget.manifest?.cinematic;

  bool get _hasCinematic =>
      _cinematic != null &&
      (_cinematic!.cameraSteps.isNotEmpty ||
          _cinematic!.tracks.isNotEmpty ||
          _cinematic!.effects.isNotEmpty);

  /// v2 — audio cues controller, lazy-init khi manifest có audio[] và
  /// auth session sẵn sàng. null → không cue nào chạy (v1/muted).
  AnimationAudioController? _audio;

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
    // P0 §3 — manifest có background asset → painter không phủ opaque
    // nền, để layer ảnh nền (dưới painter trong ManifestAssetLayers)
    // thực sự hiển thị. Painter vẫn vẽ terrain/water/markers bình
    // thường (chúng không opaque full-canvas).
    final m = widget.manifest;
    if (m != null && m.hasBackgroundAsset) {
      _painter.suppressBaseBackground = true;
    }
    _applyStep(0, animate: false);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _audio?.dispose();
    _controller.dispose();
    _painter.dispose(); // ChangeNotifier — giải phóng listener.
    super.dispose();
  }

  /// step.id trong manifest — player chỉ biết index; audio cue match
  /// theo manifest stepIds (index-trusted vì validator bắt buộc id
  /// unique theo thứ tự). Fallback: '' khi manifest thiếu.
  String _stepIdAt(int index) {
    final ids = _cinematic?.stepIds;
    if (ids == null || index >= ids.length) return '';
    return ids[index];
  }

  /// v2 — lazy-init audio controller khi manifest có audio[] + player
  /// đã có ref (ConsumerState). Idempotent — gọi lại an toàn.
  void _ensureAudio() {
    if (_audio != null) return;
    final m = widget.manifest;
    if (m == null || m.audioCues.isEmpty) return;
    // Resolve assetRef (manifest key) → assetId (uuid backend) cho role
    // AUDIO — controller không tự parse manifest.
    final audioIds = <String, String>{
      for (final a in m.assetRefs)
        if (a.role == 'AUDIO') a.id: a.assetId,
    };
    _audio = AnimationAudioController(
      fetchBytes: (id) async {
        try {
          return await fetchLearningAssetBytes(ref, id);
        } catch (_) {
          return null;
        }
      },
      audioAssetIds: audioIds,
      cues: m.audioCues,
    );
  }

  void _onTick() {
    final t = _stepCurve.transform(_controller.value);
    setState(() => _applyCurrent(t));
    _emitFrame(t, _controller.value);
  }

  /// v2 — phát CinematicFrame hiện tại (camera lerp theo easedT, object
  /// tracks theo tMs toàn cục) cho wrapper ngoài. Không setState — frame
  /// đi qua ValueNotifier để ManifestAssetLayers tự rebuild.
  void _emitFrame(double easedT, double rawProgress) {
    final ev = _cinematic;
    final sink = widget.cinematicFrame;
    if (ev == null || sink == null || !_hasCinematic) return;
    sink.value = ev.frameAt(_stepIndex, easedT, rawProgress);
  }

  /// v2 — nhảy thẳng tới frame cuối bước (reduced-motion/skip/init).
  void _emitFrameEnd() {
    final ev = _cinematic;
    final sink = widget.cinematicFrame;
    if (ev == null || sink == null || !_hasCinematic) return;
    sink.value = ev.frameEndAt(_stepIndex);
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
  /// v2 — fire audio cues: EXIT của step trước, ENTER của step mới.
  void _applyStep(int index, {bool animate = true, int? previousIndex}) {
    _ensureAudio();
    if (previousIndex != null && previousIndex != index) {
      _audio?.onStepExit(_stepIdAt(previousIndex));
    }
    final step = widget.definition.steps[index];
    _audio?.onStepEnter(_stepIdAt(index));
    if (step.target != null) {
      _current = step.target;
      // Chụp trạng thái ĐANG HIỂN THỊ (kể cả tween cũ đang dở) làm gốc —
      // chuyển bước giữa chừng không nhảy, mượt từ vị trí hiện tại.
      _tweenFrom = _current!.captured(_painter);
    } else {
      // Bước cinematic-only (không targetState): xoá _tweenFrom để
      // _applyCurrent không lerp giữa snapshot cũ và target cũ —
      // tránh "rewind" khi learner chen giữa tween trước.
      _tweenFrom = null;
    }
    // Easing của tween tới bước này — whitelist manifest, bước thiếu
    // giữ curve mặc định. Map: manifest key → Flutter curve.
    _stepCurve = _curveOf(step.easing);
    // Bước có tween khi có targetState HOẶC payload cinematic bất kỳ —
    // bước chỉ-camera/tracks/effects vẫn cần controller chạy để
    // _onTick/_emitFrame phát frame (tracks theo globalTMs, effects
    // theo progress). Không chỉ gioi hạn cameraSteps: step thiếu
    // camera.steps[i] nhưng có tracks/effects cũng phải tween.
    final hasTween = step.target != null || _hasCinematic;
    // P1 §5 — controller duration khớp step.durationMs khi cinematic:
    // tracks/effects dùng `globalTMs` tính theo stepDurationsMs; nếu
    // controller chạy 900ms nhưng step 1100ms → object chạy hết quỹ đạo
    // rồi đứng. Gán duration theo step (fallback transitionDuration).
    final stepDur = step.durationMs != null && step.durationMs! > 0
        ? Duration(milliseconds: step.durationMs!)
        : widget.definition.transitionDuration;
    _controller.duration = stepDur;
    if (animate && !_reduceMotion && hasTween) {
      _controller
        ..stop()
        ..reset()
        ..forward();
    } else {
      _controller.stop();
      _applyCurrent(1);
      _emitFrameEnd();
    }
  }

  static const Map<String, Curve> _easingMap = {
    'linear': Curves.linear,
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'easeInOut': Curves.easeInOut,
    'easeInOutCubic': Curves.easeInOutCubic,
  };

  static Curve _curveOf(String easing) =>
      _easingMap[easing] ?? Curves.easeInOut;

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    if (!_playing) return;
    // Chế độ STEPPED/INTERACTIVE: không auto-advance — học viên tự bấm
    // (STEPPED) hoặc khám phá tương tác (INTERACTIVE). AUTO mới đặt timer.
    if (widget.definition.playbackMode != 'AUTO') return;
    final step = widget.definition.steps[_stepIndex];
    // P0 — checkpoint dự đoán: AUTO KHÔNG được lướt qua bước khi learner
    // chưa chọn + xem kết quả. Dừng ở checkpoint (UI về PHÁT — learner
    // bấm PHÁT để tiếp tục sau khi đã reveal). Bỏ qua ≠ trả lời: skip
    // vẫn được phép nhưng không tính là đã giải checkpoint.
    if (_predictionVisibleAtCurrentStep && !_predictionRevealed) {
      setState(() => _playing = false);
      return;
    }
    // durationMs (manifest) = TỔNG thời gian ở bước (transition + hold).
    // Mặc định: transitionDuration + 2.2s hold cho đọc narration.
    final total = step.durationMs != null
        ? Duration(milliseconds: step.durationMs!)
        : widget.definition.transitionDuration +
              const Duration(milliseconds: 2200);
    // P1 §10 — AUTO không được chuyển sớm hơn narration đọc xong:
    // floor = transitionDuration + hold tối thiểu theo độ dài chữ
    // (~14ms/ký tự, clamp 2.5s..12s). Manifest durationMs lớn hơn vẫn
    // thắng — floor chỉ là đáy an toàn.
    final narration = step.narration;
    final holdMs = narration.isEmpty
        ? 2500
        : (narration.length * 14).clamp(2500, 12000);
    final floor =
        widget.definition.transitionDuration + Duration(milliseconds: holdMs);
    final delay = _reduceMotion
        ? const Duration(seconds: 4) // cho đọc khi không có motion
        : (total < floor ? floor : total);
    _advanceTimer = Timer(delay, () {
      if (!mounted || !_playing) return;
      if (_stepIndex < widget.definition.steps.length - 1) {
        setState(() {
          final prev = _stepIndex;
          _stepIndex++;
          // P1 §7 — AUTO advance cũng phải fire EXIT cue của step trước
          // (fade LOOP, one-shot EXIT). Trước đây thiếu previousIndex →
          // LOOP của step N kéo dài sang N+1.
          _applyStep(_stepIndex, previousIndex: prev);
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
      _audio?.onPause();
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
      _audio?.onResume();
      _scheduleAdvance();
    } else {
      // Đang ở bước cuối và bấm PHÁT → tua lại rồi phát tiếp.
      setState(() {
        _playing = true;
        _skipped = false;
      });
      _audio?.onResume();
      _replay();
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.definition.steps.length) return;
    _advanceTimer?.cancel();
    final prev = _stepIndex;
    setState(() {
      _stepIndex = index;
      _skipped = false;
      _tweenPaused = false; // tween mới, không phải pause
      _selectedLocationId = null; // panel cũ không sống qua bước mới
      _applyStep(index, previousIndex: prev);
    });
    _scheduleAdvance();
  }

  void _replay() {
    _advanceTimer?.cancel();
    final prev = _stepIndex;
    setState(() {
      _stepIndex = 0;
      _skipped = false;
      _tweenPaused = false;
      // Reset scene + xóa mọi state tương tác — replay là "xem lại từ
      // đầu", không giữ lựa chọn/reveal/marker cũ.
      _chosenOption = null;
      _predictionRevealed = false;
      _selectedLocationId = null;
      _applyStep(0, animate: false, previousIndex: prev);
    });
    _scheduleAdvance();
  }

  void _skip() {
    _advanceTimer?.cancel();
    _audio?.onSkip(); // dừng mọi cue ngay, không fire EXIT
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
    _audio?.onPause(); // learner tương tác = pause ambient loop
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
    _audio?.onPause();
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
            aspectRatio: def.aspectRatio,
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

        // --- Điều khiển nước (river scenes) — chỉ khi bước hiện tại
        // cho phép (allowedInteractions WATER_LEVEL_CONTROL) hoặc bước
        // không khai báo danh sách → giữ hành vi v1 (definition-level).
        if (def.hasWaterControl &&
            !_skipped &&
            (_step.allowedInteractions.isEmpty ||
                _step.allowedInteractions.contains('WATER_LEVEL_CONTROL'))) ...[
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

        // --- Panel thông tin địa điểm (map scenes) — cùng quy tắc
        // gate bước như water control (TAP_TO_EXPLORE).
        if (def.hasLocationExplorer &&
            !_skipped &&
            (_step.allowedInteractions.isEmpty ||
                _step.allowedInteractions.contains('TAP_TO_EXPLORE'))) ...[
          const SizedBox(height: 8),
          LocationInfoPanel(
            painter: _painter,
            selectedId: _selectedLocationId,
            onClose: () => _selectLocation(null),
          ),
        ],

        // --- Dự đoán khám phá — chỉ tại bước checkpoint (P0). Scene v1
        // giữ parity qua prediction.stepIndex; manifest v2 bind qua
        // allowedInteractions PREDICTION của bước.
        if (pred != null && !_skipped && _predictionVisibleAtCurrentStep) ...[
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
    Widget canvas = paint;
    if (def.hasLocationExplorer && painter is MapScenePainter) {
      final mp = painter;
      canvas = LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              paint,
              // Mount overlay theo TARGET của bước (deterministic), không
              // theo visibility đang tween — tránh phụ thuộc frame kết
              // cuối và marker vẫn tấp được khi đang fade-in.
              // Overlay tấp theo gate bước: bước không khai báo
              // TAP_TO_EXPLORE (khi manifest có danh sách cho bước đó)
              // → không mount vùng chạm (giữ hit-test sạch, khớp admin
              // preview `allowTap`).
              for (final loc in mp.locations)
                if (_locationActive(mp, loc.id) &&
                    (_step.allowedInteractions.isEmpty ||
                        _step.allowedInteractions.contains('TAP_TO_EXPLORE')))
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
    // v2 — bọc scene canvas trong ManifestAssetLayers: camera transform
    // chỉ áp lên vùng bounded (AspectRatio parent), UI điều khiển bên
    // dưới KHÔNG bị transform. Đây là fix P0 layout §2.
    final manifest = widget.manifest;
    if (manifest == null) return canvas;
    return ManifestAssetLayers(
      manifest: manifest,
      aspectRatio: def.aspectRatio,
      frameListenable: widget.cinematicFrame,
      child: canvas,
    );
  }
}
