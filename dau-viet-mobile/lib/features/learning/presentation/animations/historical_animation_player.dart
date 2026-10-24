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

/// P0 playback stabilization — trạng thái logic của player. Nguồn sự
/// thật DUY NHẤT về "đang ở đâu trong vòng đời scene", tách khỏi
/// `controller.value` (chỉ là tiến độ tween) và `_stepIndex` (chỉ là
/// vị trí bước). Không suy ra status từ index hay progress.
enum PlaybackStatus {
  /// Scene đã mount, đứng ở ĐẦU beat 0, chưa phát. Không audio/tween.
  idle,

  /// Timeline đang chạy (tween + timer auto-advance theo mode).
  playing,

  /// Learner chủ động tạm dừng — có thể resume nối tiếp. Tween đang
  /// chạy bị đóng băng giữa chừng với ý định forward tiếp khi resume.
  paused,

  /// Playback tạm dừng do learner TƯƠNG TÁC (kéo nước, chạm marker,
  /// reveal prediction) — tween đã bị HỦY có chủ đích, KHÔNG được
  /// resume/settle khi Play. Khác với paused: không forward tween cũ.
  interactionHold,

  /// Đang ở checkpoint prediction chưa reveal — AUTO đã dừng chờ. Play
  /// trước reveal không vượt checkpoint; sau reveal về interactionHold.
  awaitingPrediction,

  /// Scene đã thật sự chạy hết timeline cuối (AUTO timer cuối expire).
  /// Play → replay từ đầu. Khác với "đang ở bước cuối chưa xong".
  finished,

  /// Learner bấm Bỏ qua — hiển thị static summary, không controls.
  skipped,
}

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

  /// Nguồn sự thật duy nhất về trạng thái playback (thay `_playing` +
  /// `_skipped` + `_initialIdle` rời). `_playing` getter map sang để UI
  /// controls không đổi.
  PlaybackStatus _status = PlaybackStatus.idle;

  /// `true` khi trạng thái là [PlaybackStatus.paused] VÀ tween đang bị
  /// đóng băng giữa chừng với ý định resume nối tiếp — phân biệt
  /// pause-giữa-tween (forward tiếp) với pause-sau-tween-xong (không
  /// forward). Interaction-hold KHÔNG set cờ này — tween bị hủy, không
  /// phải pause.
  bool _resumeTween = false;

  bool get _playing => _status == PlaybackStatus.playing;
  bool get _skipped => _status == PlaybackStatus.skipped;
  bool get _initialIdle => _status == PlaybackStatus.idle;

  Timer? _advanceTimer;

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

  /// Gate tương tác theo bước (FIX-02):
  /// - Manifest v2 (manifestV2=true): `allowedInteractions` là whitelist
  ///   thuần — interaction chỉ bật khi bước khai báo nó; danh sách rỗng
  ///   = bước không có tương tác bổ sung (khớp admin ScenePreview).
  /// - Legacy/v1 (manifestV2=false): giữ semantics cũ — danh sách rỗng
  ///   nghĩa là "không giới hạn", tương tác definition-level áp dụng mọi
  ///   bước. Không nhìn eventId/slug — phân biệt qua `manifestV2`.
  bool _interactionAllowedAtCurrentStep(String interaction) {
    final allowed = _step.allowedInteractions;
    if (widget.definition.manifestV2) {
      return allowed.contains(interaction);
    }
    return allowed.isEmpty || allowed.contains(interaction);
  }

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
    // FIX-01/02 — idle semantics: mount KHÔNG fire audio cue và đứng ở
    // ĐẦU beat 0 — frame t=0 với scene-state từ initialState, camera đúng
    // pose đầu. PHÁT lần đầu mới chạy transition + ENTER narration.
    // (Reduced-motion: build() xử lý end-state — không check MediaQuery
    // ở đây vì initState không được phép dependOnInheritedWidget.)
    _seekStepStart(0);
    if (_hasCinematic) {
      widget.cinematicFrame?.value = _cinematic!.frameAt(0, 0.0, 0.0);
    }
  }

  /// Reduced-motion correction chạy ở didChangeDependencies — initState
  /// KHÔNG được đọc MediaQuery (dependOnInheritedWidget throw). Nếu
  /// disableAnimations bật: idle-mount đã áp start-pose t=0 → nhảy ngay
  /// tới END-state beat 0 (không tween), khớp contract reduced-motion
  /// "hiển thị end-state ngay".
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialIdle && _reduceMotion && _stepIndex == 0) {
      _controller.stop();
      if (_current != null) _applyCurrent(1);
      _emitFrameEnd();
    }
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

  /// Đưa painter về trạng thái BAN ĐẦU của scene (initialState đã-seed)
  /// — replay/seek-về-đầu khôi phục painter thay vì giữ trạng thái cuối
  /// trận. Tạo instance seeded tạm qua `createPainter()` rồi copy state
  /// sang `_painter` (giữ listener); seeded tạm không dispose vì nó
  /// chưa từng attach listener ngoài.
  void _resetPainterToInitial() {
    final seeded = widget.definition.createPainter();
    _painter.restoreFrom(seeded);
  }

  /// SEEK đầu bước (không phát): painter về initialState nếu index==0,
  /// `_current` = target bước, `_tweenFrom` snapshot, controller ở 0,
  /// frame t=0. Dùng cho idle-mount + replay-seek — KHÔNG fire audio,
  /// KHÔNG đặt timer, KHÔNG chạy tween.
  void _seekStepStart(int index) {
    if (index == 0) _resetPainterToInitial();
    _prepareStep(index);
    _controller.stop();
    _controller.value = 0;
    if (_current != null) _applyCurrent(0);
    _emitFrame(0.0, 0.0);
  }

  /// SEEK cuối bước (không phát, nhảy tĩnh): settle end-state của bước
  /// — reduced-motion, skip, navigation tĩnh. KHÔNG fire audio khi
  /// `fireAudio=false`.
  void _applyStepEnd(int index, {int? previousIndex, bool fireAudio = true}) {
    _transitionAudio(index, previousIndex, fireAudio);
    _prepareStep(index);
    _controller.stop();
    _applyCurrent(1);
    _emitFrameEnd();
  }

  /// Bắt đầu PHÁT bước — tween animate (trừ reduced-motion) + fire
  /// ENTER cue hợp lệ + caller tự `_scheduleAdvance`. Đây là điểm DUY
  /// NHẤT audio ENTER được phép cháy.
  void _startStepPlayback(int index, {int? previousIndex}) {
    _transitionAudio(index, previousIndex, true);
    _prepareStep(index);
    final step = widget.definition.steps[index];
    final hasTween = step.target != null || _hasCinematic;
    if (!_reduceMotion && hasTween) {
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

  /// Setup chung cho một bước — `_current`/`_tweenFrom`/curve/duration.
  /// Tách ra để seek-start/end/playback dùng chung phần chuẩn bị mà
  /// không lặp logic.
  void _prepareStep(int index) {
    final step = widget.definition.steps[index];
    if (step.target != null) {
      _current = step.target;
      // Chụp trạng thái ĐANG HIỂN THỊ làm gốc lerp — chuyển bước giữa
      // chừng không nhảy, mượt từ vị trí hiện tại.
      _tweenFrom = _current!.captured(_painter);
    } else {
      // Bước cinematic-only (không targetState): xoá _tweenFrom để
      // _applyCurrent không lerp giữa snapshot cũ và target cũ —
      // tránh "rewind" khi learner chen giữa tween trước.
      _tweenFrom = null;
    }
    _stepCurve = _curveOf(step.easing);
    // P1 §5 — controller duration khớp step.durationMs khi cinematic:
    // tracks/effects dùng `globalTMs` tính theo stepDurationsMs; nếu
    // controller chạy 900ms nhưng step 1100ms → object chạy hết quỹ đạo
    // rồi đứng. Gán duration theo step (fallback transitionDuration).
    final stepDur = step.durationMs != null && step.durationMs! > 0
        ? Duration(milliseconds: step.durationMs!)
        : widget.definition.transitionDuration;
    _controller.duration = stepDur;
  }

  /// Fire EXIT của bước trước + ENTER của bước đích — CHỈ khi
  /// `fireAudio` (playback thật). Silent seek/navigation/replay-seek/
  /// skip truyền false → không đánh cue nào (đặc biệt không fire EXIT
  /// của bước cũ — silent seek không phải "rời bước tự nhiên").
  void _transitionAudio(int index, int? previousIndex, bool fireAudio) {
    if (!fireAudio) return;
    _ensureAudio();
    if (previousIndex != null && previousIndex != index) {
      _audio?.onStepExit(_stepIdAt(previousIndex));
    }
    _audio?.onStepEnter(_stepIdAt(index));
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
      setState(() => _status = PlaybackStatus.awaitingPrediction);
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
          // AUTO advance = step transition tự nhiên — fire EXIT của
          // step trước + ENTER của step mới (playback đang chạy thật).
          _startStepPlayback(_stepIndex, previousIndex: prev);
        });
        _scheduleAdvance();
      } else {
        // Đã hết timeline cuối — FINISHED là trạng thái riêng, không
        // phải "đang ở bước cuối". Play sau đây sẽ replay từ đầu.
        setState(() => _status = PlaybackStatus.finished);
      }
    });
  }

  void _togglePlay() {
    switch (_status) {
      case PlaybackStatus.playing:
        // PAUSE: đóng băng ngay cả tween đang chạy — không chỉ hủy
        // timer. Đánh dấu resumeTween nếu controller đang dở để Play sau
        // forward nối tiếp (khác với interaction-hold: tween bị HỦY).
        _advanceTimer?.cancel();
        _audio?.onPause();
        setState(() {
          _status = PlaybackStatus.paused;
          _resumeTween = _controller.value > 0 && _controller.value < 1;
          _controller.stop();
        });
      case PlaybackStatus.paused:
        // RESUME: nối tiếp tween đã đóng băng (nếu có) + audio + timer.
        final resumeTween = _resumeTween;
        setState(() {
          _status = PlaybackStatus.playing;
          _resumeTween = false;
          if (resumeTween) _controller.forward();
        });
        _audio?.onResume();
        _scheduleAdvance();
      case PlaybackStatus.idle:
        // Initial PHÁT — animate beat hiện tại từ đầu + fire ENTER.
        setState(() {
          _status = PlaybackStatus.playing;
          _startStepPlayback(_stepIndex);
        });
        _scheduleAdvance();
      case PlaybackStatus.interactionHold:
        // Play sau thao tác tay — GIỮ giá trị learner đã chọn, KHÔNG
        // resume/settle tween đã hủy. Chỉ bật playing + audio + timer;
        // painter giữ nguyên (không _prepareStep lại, không forward).
        setState(() => _status = PlaybackStatus.playing);
        _audio?.onResume();
        _scheduleAdvance();
      case PlaybackStatus.awaitingPrediction:
        // Play trước reveal = không vượt checkpoint — vẫn chờ learner.
        // Sau reveal `_revealPrediction` chuyển về interactionHold nên
        // nhánh này chỉ chạy khi learner chưa reveal; no-op về scene,
        // nhưng vẫn giữ status (không advance timer).
        if (_predictionRevealed) {
          setState(() => _status = PlaybackStatus.playing);
          _audio?.onResume();
          _scheduleAdvance();
        }
      case PlaybackStatus.finished:
      case PlaybackStatus.skipped:
        // Play sau finish/skip = replay từ đầu + bắt đầu playback.
        _replay(startPlayback: true);
    }
  }

  /// Chạy transition của bước MỘT lần rồi dừng — dùng cho navigation
  /// (Next/Prev) khi KHÔNG playing: người học vẫn thấy scene chuyển động
  /// tới trạng thái bước mới nhưng autoplay không resume, audio không
  /// fire (silent seek). Giữ nguyên `_status` — idle/paused/hold vẫn là
  /// trạng thái chờ-PHÁT sau khi tween xong.
  void _animateStepTransition(int index) {
    _prepareStep(index);
    final step = widget.definition.steps[index];
    final hasTween = step.target != null || _hasCinematic;
    if (!_reduceMotion && hasTween) {
      _controller
        ..stop()
        ..reset()
        ..forward(); // chạy 1 lần — không _scheduleAdvance vì !_playing
    } else {
      _controller.stop();
      _applyCurrent(1);
      _emitFrameEnd();
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.definition.steps.length) return;
    _advanceTimer?.cancel();
    final prev = _stepIndex;
    setState(() {
      _stepIndex = index;
      // Thoát trạng thái kết thúc: điều hướng sau finished/skipped đưa
      // player về idle (chờ PHÁT) thay vì mắc kẹt ở terminal state.
      if (_skipped || _status == PlaybackStatus.finished) {
        _status = PlaybackStatus.idle;
      }
      _resumeTween = false;
      _selectedLocationId = null; // panel cũ không sống qua bước mới
      if (_playing) {
        // Navigation trong lúc playing = step transition thật: animate
        // + fire EXIT/ENTER + đặt lại timer qua _scheduleAdvance dưới.
        _startStepPlayback(index, previousIndex: prev);
      } else {
        // Navigation lúc chờ = silent seek CÓ animate tween một lần
        // (scene chuyển động tới bước mới), không audio, không autoplay.
        _animateStepTransition(index);
      }
    });
    _scheduleAdvance();
  }

  /// Replay — reset scene về đầu beat 0. `startPlayback=true` (Play sau
  /// finish/skip, hoặc nút Tua-lại khi đang playing) thì phát luôn beat
  /// 0 + ENTER; `false` (replay lúc paused/idle) chỉ seek tĩnh — learner
  /// bấm PHÁT sau mới chạy. Contract: replay KHÔNG giữ trạng thái cuối
  /// trận (painter reset về initialState qua _seekStepStart).
  void _replay({bool startPlayback = false}) {
    _advanceTimer?.cancel();
    final prev = _stepIndex;
    // Replay trong lúc playing → giữ playing và startPlayback. Nút
    // Tua-lại khi playing cũng là startPlayback (xem lại từ đầu ngay).
    final playAfter = startPlayback || _playing;
    setState(() {
      _stepIndex = 0;
      _status = playAfter ? PlaybackStatus.playing : PlaybackStatus.idle;
      _resumeTween = false;
      // Reset scene + xóa mọi state tương tác — replay là "xem lại từ
      // đầu", không giữ lựa chọn/reveal/marker cũ.
      _chosenOption = null;
      _predictionRevealed = false;
      _selectedLocationId = null;
      if (playAfter) {
        // Phát lại beat 0: audio session cũ dọn rồi fire ENTER một lần.
        _audio?.onSkip();
        _startStepPlayback(0, previousIndex: prev);
      } else {
        // Seek tĩnh về đầu — painter reset, frame t=0, không audio.
        _seekStepStart(0);
      }
    });
    _scheduleAdvance();
  }

  void _skip() {
    _advanceTimer?.cancel();
    _audio?.onSkip(); // dừng mọi cue ngay, không fire EXIT
    setState(() {
      _status = PlaybackStatus.skipped;
      _resumeTween = false;
      _stepIndex = widget.definition.steps.length - 1;
      // Skip = seek tĩnh cuối scene: không fire ENTER/EXIT của bước cuối.
      _applyStepEnd(_stepIndex, fireAudio: false);
    });
  }

  /// Chỉ river scene dùng — map painter có setter no-op nên không ảnh
  /// hưởng; giữ hành vi ANIM-01 (kéo tay thắng tween).
  void _setWater(double v) {
    _advanceTimer?.cancel();
    _audio?.onPause(); // learner tương tác = pause ambient loop
    setState(() {
      // INTERACTION_HOLD — learner giữ giá trị tay; tween bị HỦY có chủ
      // đích (không resume khi Play), playback về chờ-tiếp-tục.
      _status = PlaybackStatus.interactionHold;
      _resumeTween = false;
      _controller.stop();
      _painter.waterLevel = v.clamp(0.0, 1.0);
      // Snapshot lại gốc để transition kế tiếp lerp từ giá trị tay.
      _tweenFrom = _current?.captured(_painter);
    });
  }

  void _selectLocation(String? id) {
    _advanceTimer?.cancel();
    _audio?.onPause();
    setState(() {
      // Chạm marker = INTERACTION_HOLD khám phá: settle scene về trạng
      // thái đích của bước hiện tại (deterministic), không timer mới.
      // Tween bị hủy KHÔNG được resume — không phải pause-để-tiếp-tục.
      _status = PlaybackStatus.interactionHold;
      _resumeTween = false;
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
      // Reveal = giải checkpoint → về interactionHold (không phải
      // paused) — Play sau đó tiếp tục theo contract, không resume
      // tween đã hủy.
      _status = PlaybackStatus.interactionHold;
      _predictionRevealed = true;
      _resumeTween = false;
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
            _interactionAllowedAtCurrentStep('WATER_LEVEL_CONTROL')) ...[
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
            _interactionAllowedAtCurrentStep('TAP_TO_EXPLORE')) ...[
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
                    _interactionAllowedAtCurrentStep('TAP_TO_EXPLORE'))
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
