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
/// - Pause → pause LOOP + one-shot narration dài; resume → resume cả
///   hai (one-shot tạm dừng, không replay từ đầu).
/// - fadeMs của LOOP cue → fade-in khi start, fade-out khi exit step.
/// - Generation token: pending fetchBytes của step cũ không phát âm
///   khi learner đã chuyển step / skip / dispose.
///
/// Chỉ MỘT LOOP player tại một thời điểm — LOOP mới thay LOOP cũ.
/// API tối thiểu của một cue-player: chỉ phần controller cần gọi.
/// `AudioPlayer` của audioplayers implement trực tiếp qua extension
/// `CueAudioPlayerImpl`; test inject `FakeCueAudioPlayer` để quan sát
/// lệnh play/stop mà không đụng plugin (ctor AudioPlayer gọi platform
/// channel ngay khi khởi tạo → không dùng được trong flutter test).
abstract interface class CueAudioPlayer {
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
  Future<void> setReleaseMode(ReleaseMode mode);
  Future<void> setVolume(double v);
  Future<void> play(Source source);
}

/// Production impl — bọc `AudioPlayer` thật.
class _PluginCueAudioPlayer implements CueAudioPlayer {
  _PluginCueAudioPlayer(this._p);
  final AudioPlayer _p;
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> resume() => _p.resume();
  @override
  Future<void> dispose() => _p.dispose();
  @override
  Future<void> setReleaseMode(ReleaseMode m) => _p.setReleaseMode(m);
  @override
  Future<void> setVolume(double v) => _p.setVolume(v);
  @override
  Future<void> play(Source s) => _p.play(s);
}

/// Tạo player — seam để test thay bằng fake (audioplayers không chạy
/// trong `flutter test`). Mặc định wrap `AudioPlayer`.
typedef CueAudioPlayerFactory = CueAudioPlayer Function();

/// @visibleForTesting — khi true (chỉ test set) `_isTest` trả false để
/// `_playOnce`/`_startLoop` chạy qua fake `playerFactory` thay vì bail.
/// Production không bao giờ set — an toàn mặc định.
bool audioTestBypassPlugin = false;

class AnimationAudioController {
  /// Fetch bytes của một assetId — inject bởi caller (Player dùng
  /// `fetchLearningAssetBytes(ref, id)`). Trả null khi lỗi/missing.
  final Future<List<int>?> Function(String assetId) fetchBytes;

  /// Factory tạo cue-player — test override bằng `FakeCueAudioPlayer`
  /// để kiểm soát delay/thứ tự play/stop mà không cần plugin thật.
  final CueAudioPlayerFactory _playerFactory;

  /// assetRef → assetId resolution (manifest.assets[] role AUDIO).
  final Map<String, String> audioAssetIds;

  /// Cues grouped theo stepId (step đích của cue).
  final Map<String, List<AudioCueDto>> cuesByStep;

  /// Cache bytes per assetId — fetch MỘT lần per player session.
  final Map<String, Future<List<int>?>> _byteCache = {};

  /// Players one-shot (ENTER/EXIT) — key = assetId+cue để dispose riêng.
  final Map<String, CueAudioPlayer> _oneShotPlayers = {};

  /// LOOP player đơn — chỉ một tại một thời điểm.
  CueAudioPlayer? _loopPlayer;
  String? _loopStepId;

  /// fadeMs + volume của LOOP đang chạy — dùng khi fade-out lúc exit.
  int _loopFadeMs = 0;
  double _loopVolume = 1.0;

  /// Bytes của LOOP player đang pending start (learner pause ngay lúc
  /// LOOP fire). `onResume` dùng để `play` thay vì `resume` — resume
  /// trên player chưa start là no-op trong audioplayers.
  List<int>? _loopPendingBytes;
  bool _loopStarted = false;

  /// One-shot cues bị chặn bởi Pause (bytes đã về nhưng chưa được
  /// `play`). `onResume` phát lại đúng MỘT lần qua `_playOnce` — không
  /// refetch (bytes giữ sẵn), không duplicate (list clear trước khi
  /// phát). `stale` re-check generation/exitEpoch lúc resume: learner
  /// chuyển step/skip trong lúc pause → pending của step cũ bị drop.
  final List<({AudioCueDto cue, List<int> bytes, bool Function() stale})>
  _pendingOneShots = [];

  bool _disposed = false;
  bool _paused = false;

  /// P1 §7 — Generation token chống race: pending `fetchBytes` của step
  /// cũ không được phát âm khi learner đã chuyển step. Mỗi onStepEnter/
  /// onStepExit/onSkip/ dispose tăng generation; `_fire` chụp gen tại
  /// thời điểm fire và abort nếu gen đổi trước khi bytes về.
  int _generation = 0;

  /// FIX-04 — epoch chụp lúc `onStepExit`: EXIT cue chạy trên epoch
  /// riêng để `onStepEnter` step kế không abort nó giữa fetch. onSkip/
  /// dispose reset `_exitEpoch = -1` → `_fireExit` abort đúng.
  int _exitEpoch = -1;

  /// Default factory — tên riêng để `_playerFactoryIsDefault` so sánh.
  static CueAudioPlayer _defaultFactory() =>
      _PluginCueAudioPlayer(AudioPlayer());

  AnimationAudioController({
    required this.fetchBytes,
    required this.audioAssetIds,
    required List<AudioCueDto> cues,
    CueAudioPlayerFactory? playerFactory,
  }) : _playerFactory = playerFactory ?? _defaultFactory,
       cuesByStep = _groupByStep(cues);

  static Map<String, List<AudioCueDto>> _groupByStep(List<AudioCueDto> cues) {
    final grouped = <String, List<AudioCueDto>>{};
    for (final c in cues) {
      (grouped[c.stepId] ??= []).add(c);
    }
    return grouped;
  }

  bool get _soundEnabled => DauVietAudioService.instance.isSoundEnabled;

  /// Test seam — `_isTest` guard chỉ chặn lệnh `play`/`setReleaseMode`
  /// xuống plugin audioplayers (không chạy trong `flutter test`); logic
  /// routing, generation, byte-cache, abort vẫn chạy → race-condition
  /// test được bằng `CueAudioPlayer` fake inject qua `playerFactory`.
  /// Khi test inject `playerFactory` (fake trả `FakeCueAudioPlayer`),
  /// `_isTest` trả false để `_playOnce`/`_startLoop` đi qua như
  /// production — fake ghi nhận lệnh gọi mà không cần plugin thật.
  bool get _isTest =>
      !audioTestBypassPlugin && DauVietAudioService.isTestEnvironment;

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

  /// Phát một cue — ENTER: play once; LOOP: chuyển thành loop player.
  /// Chụp [_generation] trước await: nếu gen đổi (learner đã chuyển
  /// step / skip / dispose) trong lúc fetch bytes thì abort.
  /// `_paused` sau await = giữ cue pending (bytes đã cache), KHÔNG play
  /// — onResume sẽ phát lại đúng 1 lần thay vì drop mất.
  Future<void> _fire(AudioCueDto cue) async {
    if (_disposed || !_soundEnabled) return;
    final gen = _generation;
    try {
      final bytes = await _bytesOf(cue.assetRef);
      if (_disposed || gen != _generation || bytes == null || bytes.isEmpty) {
        return;
      }
      if (cue.cue == 'LOOP') {
        await _startLoop(cue, bytes, gen);
      } else {
        await _playOnce(cue, bytes, () => gen != _generation);
      }
    } catch (e) {
      debugPrint('AnimationAudioController cue error: $e');
    }
  }

  /// FIX-04 — phát EXIT cue ngoài generation-token của `_fire`. EXIT
  /// phát KHI rời step — `_generation` của step mới (onStepEnter kế)
  /// không được kill nó; chỉ skip/dispose (bump `_exitEpoch`) mới abort.
  /// LOOP cue không qua đây — EXIT luôn one-shot.
  Future<void> _fireExit(AudioCueDto cue) async {
    if (_disposed || !_soundEnabled) return;
    final epoch = _exitEpoch;
    try {
      final bytes = await _bytesOf(cue.assetRef);
      if (_disposed || epoch != _exitEpoch || bytes == null || bytes.isEmpty) {
        return;
      }
      await _playOnce(cue, bytes, () => epoch != _exitEpoch);
    } catch (e) {
      debugPrint('AnimationAudioController exit cue error: $e');
    }
  }

  /// Phát one-shot (ENTER/EXIT). [stale] = closure kiểm tra generation/
  /// epoch của caller — sau MỖI await phải re-check, vì `onPause`,
  /// `onStepEnter`, `onSkip` có thể xen giữa chuỗi config; nếu cứ `play`
  /// sau khi learner đã pause/chuyển step thì âm vẫn nổ lệch hình
  /// (spec: pending fetch + Pause → don't play). Khi phát hiện paused
  /// giữa config → queue vào `_pendingOneShots` để `onResume` phát đúng
  /// một lần (không refetch, không duplicate).
  Future<void> _playOnce(
    AudioCueDto cue,
    List<int> bytes,
    bool Function() stale,
  ) async {
    if (_isTest) return; // plugin không chạy trong flutter test
    final key = '${cue.assetRef}:${cue.cue}';
    final player = _oneShotPlayers[key] ??= _playerFactory();
    await player.stop();
    if (_disposed || stale()) return;
    await player.setReleaseMode(ReleaseMode.stop);
    if (_disposed || stale()) return;
    await player.setVolume(cue.volume);
    if (_disposed || stale()) return;
    if (_paused) {
      _pendingOneShots.add((cue: cue, bytes: bytes, stale: stale));
      return;
    }
    await player.play(BytesSource(Uint8List.fromList(bytes)));
  }

  /// [gen] = generation chụp từ `_fire` — sau MỖI await phải kiểm tra
  /// lại, vì `_fire` của step mới có thể interleave và `_stopLoop` của
  /// nó sẽ dispose player nửa-configured của call này; nếu tiếp tục
  /// gán `_loopPlayer = p` sẽ overwrite con trỏ của call sau → player
  /// mồ côi vẫn phát (leak + âm chồng).
  Future<void> _startLoop(AudioCueDto cue, List<int> bytes, int gen) async {
    // LOOP mới thay LOOP cũ — dừng cái đang chạy trước.
    await _stopLoop();
    if (_disposed || gen != _generation) return;
    // Test seam — trong flutter test (`_isTest` && không inject fake
    // player) thì skip phần config/play plugin; logic lifecycle vẫn chạy.
    if (_isTest) return;
    final p = _loopPlayer = _playerFactory();
    _loopStepId = cue.stepId;
    _loopFadeMs = cue.fadeMs;
    _loopVolume = cue.volume;
    _loopStarted = false;
    _loopPendingBytes = bytes;
    await p.setReleaseMode(ReleaseMode.loop);
    if (_disposed || gen != _generation) return;
    // fadeMs > 0 → fade-in từ 0 lên volume đích sau khi play.
    await p.setVolume(cue.fadeMs > 0 ? 0 : cue.volume);
    if (_disposed || gen != _generation) return;
    if (_paused) return; // learner đang pause → onResume sẽ play
    await p.play(BytesSource(Uint8List.fromList(bytes)));
    _loopStarted = true;
    _loopPendingBytes = null;
    if (cue.fadeMs > 0) {
      unawaited(_rampVolume(p, cue.volume, cue.fadeMs));
    }
  }

  /// Ramp volume của [p] về [target] trong [durationMs] — dùng cho
  /// fade-in của LOOP (0→cue.volume). Dừng sớm nếu player đã bị thay
  /// thế/dispose (check identical với _loopPlayer).
  Future<void> _rampVolume(
    CueAudioPlayer p,
    double target,
    int durationMs,
  ) async {
    const steps = 8;
    const startVol = 0.0;
    // fadeMs nhỏ (<8) → tick=0 → loop chồng setVolume; sàn 16ms/tick.
    final tick = Duration(
      milliseconds: (durationMs ~/ steps).clamp(16, 1 << 30),
    );
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(tick);
      if (_disposed || !identical(p, _loopPlayer)) return;
      final t = i / steps;
      final vol = startVol + (target - startVol) * t;
      try {
        await p.setVolume(vol.clamp(0.0, 1.0));
      } catch (_) {
        return;
      }
    }
  }

  /// Dừng LOOP — [fade]=true thì ramp volume về 0 trong `_loopFadeMs`
  /// trước khi stop (step exit tự nhiên); skip/dispose truyền false để
  /// dừng ngay.
  Future<void> _stopLoop({bool fade = false}) async {
    final p = _loopPlayer;
    final fadeMs = fade ? _loopFadeMs : 0;
    _loopPlayer = null;
    _loopStepId = null;
    _loopStarted = false;
    _loopPendingBytes = null;
    if (p == null) return;
    try {
      if (fadeMs > 0) {
        // Fade-out trên player detach — không còn là _loopPlayer nên
        // _rampVolume sẽ bail ngay; ramp thủ công ở đây.
        const steps = 8;
        final tick = Duration(
          milliseconds: (fadeMs ~/ steps).clamp(16, 1 << 30),
        );
        for (var i = 1; i <= steps; i++) {
          await Future.delayed(tick);
          if (_disposed) break;
          try {
            await p.setVolume(_loopVolume * (1 - i / steps).clamp(0.0, 1.0));
          } catch (_) {
            break;
          }
        }
      }
      await p.stop();
      await p.dispose();
    } catch (_) {}
    _loopFadeMs = 0;
  }

  /// Player vào step — fire ENTER cues + LOOP cues gắn stepId này.
  /// Idempotent khi gọi lại cùng step (replay an toàn). Bump generation
  /// để invalidate pending fetch của step trước.
  void onStepEnter(String stepId) {
    _generation++;
    if (_disposed || !_soundEnabled) return;
    final cues = cuesByStep[stepId];
    if (cues == null) return;
    for (final c in cues) {
      if (c.cue == 'EXIT') continue; // EXIT fire khi rời, không vào
      _fire(c);
    }
  }

  /// Player rời step — fire EXIT cues, dừng LOOP nếu LOOP gắn step này.
  /// LOOP fade-out theo `fadeMs` của cue (rời step tự nhiên), khác với
  /// skip/dispose là dừng ngay.
  ///
  /// FIX-04 — EXIT cue chạy ĐỘC LẬP generation: `onStepEnter` của step
  /// kế bump `_generation` NGAY sau (chuyển bước là atomic) — nếu EXIT
  /// dùng `_fire` chung, gen-check sẽ kill nó giữa fetch → exit cue
  /// hợp lệ không bao giờ phát. `_fireExit` pin `_exitEpoch` lúc rời
  /// bước; chỉ onSkip/dispose (reset `_exitEpoch = -1`) mới abort nó,
  /// còn enter step mới thì EXIT vẫn phát đúng. Byte-cache làm fetch
  /// EXIT thường instant nếu đã tải.
  void onStepExit(String stepId) {
    _generation++;
    _exitEpoch = _generation; // pin — chuyển step kế không kill EXIT
    if (_disposed || !_soundEnabled) return;
    final cues = cuesByStep[stepId];
    if (cues != null) {
      for (final c in cues) {
        if (c.cue == 'EXIT') _fireExit(c);
      }
    }
    // _stopLoop tự reset _loopPlayer/_loopStepId/_loopStarted/_loopPendingBytes.
    if (_loopStepId == stepId) _stopLoop(fade: true);
  }

  /// Learner pause — LOOP pause theo; one-shot (narration ENTER/EXIT dài)
  /// cũng pause để không lệch hình (FIX-02). One-shot ngắn pause rồi
  /// resume là no-op an toàn.
  void onPause() {
    _paused = true;
    try {
      _loopPlayer?.pause();
    } catch (_) {}
    for (final p in _oneShotPlayers.values) {
      try {
        p.pause();
      } catch (_) {}
    }
  }

  /// Learner resume — LOOP tiếp tục nếu còn active. Nếu LOOP được fire
  /// TRONG LÚC pause (chưa start — `_loopStarted=false`), resume() trên
  /// player chưa play là no-op → phải `play` với bytes đã giữ.
  /// One-shot (narration ENTER dài) resume nối tiếp từ vị trí pause —
  /// KHÔNG replay từ đầu. audioplayers: resume() trên player đã
  /// stop/finished là no-op an toàn. FIX-02: resume one-shot chạy độc
  /// lập LOOP — `_loopPlayer == null` (scene không có LOOP cue) không
  /// được bỏ qua phần one-shot.
  void onResume() {
    _paused = false;
    final p = _loopPlayer;
    if (p != null) {
      if (!_loopStarted && _loopPendingBytes != null) {
        final bytes = _loopPendingBytes!;
        _loopPendingBytes = null;
        p
            .play(BytesSource(Uint8List.fromList(bytes)))
            .then((_) {
              _loopStarted = true;
              if (_loopFadeMs > 0) {
                unawaited(_rampVolume(p, _loopVolume, _loopFadeMs));
              }
            })
            .catchError((_) {});
      } else {
        try {
          p.resume();
        } catch (_) {}
      }
    }
    // One-shot bị chặn bởi pause (bytes đã về, chưa kịp play) — phát
    // đúng một lần; drop những cue đã stale (learner chuyển step/skip
    // trong lúc pause). Clear TRƯỚC khi phát để một pending không thể
    // re-queue chính nó nếu `_playOnce` gặp `_paused` lần nữa.
    final pending = List.of(_pendingOneShots);
    _pendingOneShots.clear();
    for (final p in pending) {
      if (_disposed || p.stale()) continue;
      unawaited(_playOnce(p.cue, p.bytes, p.stale));
    }
    for (final s in _oneShotPlayers.values) {
      try {
        s.resume();
      } catch (_) {}
    }
  }

  /// Skip — dừng mọi cue ngay (không fire EXIT). Bump generation +
  /// `_exitEpoch` để pending fetch/EXIT không phát âm sau skip.
  void onSkip() {
    _generation++;
    _exitEpoch = -1;
    if (_disposed) return;
    _stopLoop();
    _pendingOneShots.clear(); // pending của session cũ — không phát sau skip
    for (final p in _oneShotPlayers.values) {
      try {
        p.stop();
      } catch (_) {}
    }
  }

  /// Dispose player — stop + release mọi player. Bump generation.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _exitEpoch = -1; // pending EXIT abort
    await _stopLoop();
    _pendingOneShots.clear();
    for (final p in _oneShotPlayers.values) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _oneShotPlayers.clear();
  }
}
