import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/audio/dau_viet_audio_service.dart';
import 'animation_manifest_dto.dart';

/// v2 — Controller phát `audio[]` cue theo vòng đời step của player.
/// Không phải service mới — mượn [DauVietAudioService] cho mute/volume
/// và [audioplayers] cho phát bytes (BytesSource).
///
/// Lifecycle-safe:
/// - Muted (`isSoundEnabled=false`) → không fetch, không play.
/// - Missing assetRef/assetId/bytes → no-op, scene vẫn chạy.
/// - Dispose → stop + release mọi player.
/// - Skip → stop mọi cue.
/// - Pause → pause LOOP; resume → resume LOOP.
///
/// Chỉ MỘT LOOP player tại một thời điểm — LOOP mới thay LOOP cũ.
class AnimationAudioController {
  /// Fetch bytes của một assetId — inject bởi caller (Player dùng
  /// `fetchLearningAssetBytes(ref, id)`). Trả null khi lỗi/missing.
  final Future<List<int>?> Function(String assetId) fetchBytes;

  /// assetRef → assetId resolution (manifest.assets[] role AUDIO).
  final Map<String, String> audioAssetIds;

  /// Cues grouped theo stepId (step đích của cue).
  final Map<String, List<AudioCueDto>> cuesByStep;

  /// Cache bytes per assetId — fetch MỘT lần per player session.
  final Map<String, Future<List<int>?>> _byteCache = {};

  /// Players one-shot (ENTER/EXIT) — key = assetId+cue để dispose riêng.
  final Map<String, AudioPlayer> _oneShotPlayers = {};

  /// LOOP player đơn — chỉ một tại một thời điểm.
  AudioPlayer? _loopPlayer;
  String? _loopStepId;

  bool _disposed = false;
  bool _paused = false;

  AnimationAudioController({
    required this.fetchBytes,
    required this.audioAssetIds,
    required List<AudioCueDto> cues,
  }) : cuesByStep = _groupByStep(cues);

  static Map<String, List<AudioCueDto>> _groupByStep(
    List<AudioCueDto> cues,
  ) {
    final grouped = <String, List<AudioCueDto>>{};
    for (final c in cues) {
      (grouped[c.stepId] ??= []).add(c);
    }
    return grouped;
  }

  bool get _soundEnabled => DauVietAudioService.instance.isSoundEnabled;
  bool get _isTest => DauVietAudioService.isTestEnvironment;

  /// Bytes của assetId — cache lần đầu; null khi không resolve được
  /// hoặc fetch lỗi/rỗng.
  Future<List<int>?> _bytesOf(String assetRef) {
    final assetId = audioAssetIds[assetRef];
    if (assetId == null || assetId.isEmpty) {
      return Future.value(null);
    }
    return _byteCache.putIfAbsent(
      assetId,
      () => fetchBytes(assetId).catchError((_) => null),
    );
  }

  /// Phát một cue — ENTER: play once; EXIT: play once (hiếm); LOOP:
  /// chuyển thành loop player. Không throw — mọi lỗi nuốt vào debugPrint.
  Future<void> _fire(AudioCueDto cue) async {
    if (_disposed || !_soundEnabled || _isTest) return;
    try {
      final bytes = await _bytesOf(cue.assetRef);
      if (_disposed || bytes == null || bytes.isEmpty) return;
      if (cue.cue == 'LOOP') {
        await _startLoop(cue, bytes);
      } else {
        await _playOnce(cue, bytes);
      }
    } catch (e) {
      debugPrint('AnimationAudioController cue error: $e');
    }
  }

  Future<void> _playOnce(AudioCueDto cue, List<int> bytes) async {
    final key = '${cue.assetRef}:${cue.cue}';
    final player = _oneShotPlayers[key] ??= AudioPlayer();
    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(cue.volume);
    await player.play(BytesSource(Uint8List.fromList(bytes)));
  }

  Future<void> _startLoop(AudioCueDto cue, List<int> bytes) async {
    // LOOP mới thay LOOP cũ — dừng cái đang chạy trước.
    await _stopLoop();
    final p = _loopPlayer = AudioPlayer();
    _loopStepId = cue.stepId;
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setVolume(cue.volume);
    if (_paused) return; // learner đang pause → không start
    await p.play(BytesSource(Uint8List.fromList(bytes)));
  }

  Future<void> _stopLoop() async {
    _loopStepId = null;
    try {
      await _loopPlayer?.stop();
      await _loopPlayer?.dispose();
    } catch (_) {}
    _loopPlayer = null;
  }

  /// Player vào step — fire ENTER cues + LOOP cues gắn stepId này.
  /// Idempotent khi gọi lại cùng step (replay an toàn).
  void onStepEnter(String stepId) {
    if (_disposed || !_soundEnabled) return;
    final cues = cuesByStep[stepId];
    if (cues == null) return;
    for (final c in cues) {
      if (c.cue == 'EXIT') continue; // EXIT fire khi rời, không vào
      _fire(c);
    }
  }

  /// Player rời step — fire EXIT cues, dừng LOOP nếu LOOP gắn step này.
  void onStepExit(String stepId) {
    if (_disposed || !_soundEnabled) return;
    final cues = cuesByStep[stepId];
    if (cues != null) {
      for (final c in cues) {
        if (c.cue == 'EXIT') _fire(c);
      }
    }
    if (_loopStepId == stepId) _stopLoop();
  }

  /// Learner pause — LOOP pause theo; one-shot để nguyên (ngắn).
  void onPause() {
    _paused = true;
    try {
      _loopPlayer?.pause();
    } catch (_) {}
  }

  /// Learner resume — LOOP tiếp tục nếu còn active.
  void onResume() {
    _paused = false;
    try {
      _loopPlayer?.resume();
    } catch (_) {}
  }

  /// Skip — dừng mọi cue ngay (không fire EXIT).
  void onSkip() {
    if (_disposed) return;
    _stopLoop();
    for (final p in _oneShotPlayers.values) {
      try {
        p.stop();
      } catch (_) {}
    }
  }

  /// Dispose player — stop + release mọi player.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopLoop();
    for (final p in _oneShotPlayers.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _oneShotPlayers.clear();
  }
}
