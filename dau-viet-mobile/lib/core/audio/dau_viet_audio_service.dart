import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service quản lý toàn bộ hệ thống âm thanh phản hồi tức thì (Micro-SFX)
/// và trình đọc giọng dẫn sử liệu (Historical Narration) của Dấu Việt.
class DauVietAudioService extends ChangeNotifier {
  static DauVietAudioService? _instance;
  static DauVietAudioService get instance =>
      _instance ??= DauVietAudioService();

  /// Phát hiện môi trường kiểm thử tự động headless để kích hoạt giả lập an toàn
  static bool get isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  // Danh mục đường dẫn âm thanh chuẩn hoá trong assets/audio/
  static const String sfxTapPath = 'audio/sfx_tap.wav';
  static const String sfxCorrectPath = 'audio/sfx_correct.wav';
  static const String sfxWrongPath = 'audio/sfx_wrong.wav';
  static const String sfxStreakUpPath = 'audio/sfx_streak_up.wav';
  static const String sfxChestOpenPath = 'audio/sfx_chest_open.wav';
  static const String defaultNarrationPath = 'audio/narration_bach_dang.wav';

  // Trạng thái cấu hình âm thanh
  bool _isSoundEnabled = true;
  bool _isNarrationEnabled = true;
  double _sfxVolume = 1.0;
  double _narrationVolume = 1.0;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isNarrationEnabled => _isNarrationEnabled;
  double get sfxVolume => _sfxVolume;
  double get narrationVolume => _narrationVolume;

  // Pool các player cho SFX để hỗ trợ phát đồng thời các hiệu ứng ngắn
  final List<AudioPlayer> _sfxPlayers = [];
  int _currentSfxIndex = 0;
  static const int _sfxPoolSize = 3;

  // Player riêng biệt cho phần đọc giọng kể lịch sử
  AudioPlayer? _narrationPlayer;
  PlayerState _narrationState = PlayerState.stopped;
  Duration _narrationPosition = Duration.zero;
  Duration _narrationDuration = const Duration(seconds: 8, milliseconds: 500);

  PlayerState get narrationState => _narrationState;
  Duration get narrationPosition => _narrationPosition;
  Duration get narrationDuration => _narrationDuration;
  bool get isNarrationPlaying => _narrationState == PlayerState.playing;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  DauVietAudioService() {
    if (!isTestEnvironment) {
      _initPlayers();
    }
  }

  void _initPlayers() {
    try {
      for (int i = 0; i < _sfxPoolSize; i++) {
        final player = AudioPlayer();
        player.setReleaseMode(ReleaseMode.stop);
        _sfxPlayers.add(player);
      }

      final nPlayer = AudioPlayer();
      nPlayer.setReleaseMode(ReleaseMode.stop);
      _narrationPlayer = nPlayer;

      _stateSubscription = nPlayer.onPlayerStateChanged.listen((state) {
        _narrationState = state;
        notifyListeners();
      }, onError: (_) {});

      _positionSubscription = nPlayer.onPositionChanged.listen((pos) {
        _narrationPosition = pos;
        notifyListeners();
      }, onError: (_) {});

      _durationSubscription = nPlayer.onDurationChanged.listen((dur) {
        if (dur > Duration.zero) {
          _narrationDuration = dur;
          notifyListeners();
        }
      }, onError: (_) {});
    } catch (e) {
      debugPrint('DauVietAudioService player initialization note: $e');
    }
  }

  void setSoundEnabled(bool enabled) {
    if (_isSoundEnabled != enabled) {
      _isSoundEnabled = enabled;
      notifyListeners();
    }
  }

  void toggleSound() {
    setSoundEnabled(!_isSoundEnabled);
  }

  void setNarrationEnabled(bool enabled) {
    if (_isNarrationEnabled != enabled) {
      _isNarrationEnabled = enabled;
      if (!enabled && isNarrationPlaying) {
        stopNarration();
      }
      notifyListeners();
    }
  }

  void toggleNarration() {
    setNarrationEnabled(!_isNarrationEnabled);
  }

  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setNarrationVolume(double volume) {
    _narrationVolume = volume.clamp(0.0, 1.0);
    _narrationPlayer?.setVolume(_narrationVolume).catchError((_) {});
    notifyListeners();
  }

  // --- HỆ THỐNG PHÁT SFX PHẢN HỒI TỨC THÌ ---

  Future<void> _playSfx(
    String assetPath, {
    double volumeMultiplier = 1.0,
  }) async {
    if (!_isSoundEnabled) return;
    if (isTestEnvironment) return;

    try {
      if (_sfxPlayers.isEmpty) return;
      final player = _sfxPlayers[_currentSfxIndex];
      _currentSfxIndex = (_currentSfxIndex + 1) % _sfxPlayers.length;

      await player.stop();
      await player.setVolume((_sfxVolume * volumeMultiplier).clamp(0.0, 1.0));
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('SFX playback error ($assetPath): $e');
    }
  }

  /// Phát tiếng gõ thẻ bài trúc nhẹ nhàng khi chạm / chọn
  Future<void> playTap() async {
    await _playSfx(sfxTapPath, volumeMultiplier: 0.85);
  }

  /// Phát tiếng Trống Đồng trầm hùng + chuông ngân hoàng gia khi trả lời đúng
  Future<void> playCorrect() async {
    await _playSfx(sfxCorrectPath, volumeMultiplier: 1.0);
  }

  /// Phát tiếng mộc gõ ấm áp, nhẹ nhàng khi trả lời sai
  Future<void> playWrong() async {
    await _playSfx(sfxWrongPath, volumeMultiplier: 0.9);
  }

  /// Phát chuỗi âm ngũ cung thăng tiến khi nối dài Combo Streak
  Future<void> playStreakUp({int combo = 1}) async {
    await _playSfx(sfxStreakUpPath, volumeMultiplier: 1.0);
  }

  /// Phát âm thanh mở rương báu cổ và nhận cổ vật
  Future<void> playChestOpen() async {
    await _playSfx(sfxChestOpenPath, volumeMultiplier: 1.0);
  }

  // --- TRÌNH ĐỌC LỊCH SỬ (NARRATION AUDIO) ---

  /// Bắt đầu hoặc tiếp tục phát giọng đọc bài sử liệu
  Future<void> playNarration({String assetPath = defaultNarrationPath}) async {
    if (!_isNarrationEnabled) return;

    if (isTestEnvironment) {
      _narrationState = PlayerState.playing;
      notifyListeners();
      return;
    }

    try {
      final player = _narrationPlayer;
      if (player == null) return;

      if (_narrationState == PlayerState.paused) {
        await player.resume();
      } else {
        await player.setVolume(_narrationVolume);
        await player.play(AssetSource(assetPath));
      }
    } catch (e) {
      debugPrint('Narration play error: $e');
    }
  }

  /// Tạm dừng giọng đọc
  Future<void> pauseNarration() async {
    if (isTestEnvironment) {
      _narrationState = PlayerState.paused;
      notifyListeners();
      return;
    }

    try {
      await _narrationPlayer?.pause();
    } catch (e) {
      debugPrint('Narration pause error: $e');
    }
  }

  /// Dừng hẳn giọng đọc và quay lại đầu
  Future<void> stopNarration() async {
    if (isTestEnvironment) {
      _narrationState = PlayerState.stopped;
      _narrationPosition = Duration.zero;
      notifyListeners();
      return;
    }

    try {
      await _narrationPlayer?.stop();
      _narrationPosition = Duration.zero;
      notifyListeners();
    } catch (e) {
      debugPrint('Narration stop error: $e');
    }
  }

  /// Tua tới vị trí trong bài đọc
  Future<void> seekNarration(Duration position) async {
    if (isTestEnvironment) {
      _narrationPosition = position;
      notifyListeners();
      return;
    }

    try {
      await _narrationPlayer?.seek(position);
    } catch (e) {
      debugPrint('Narration seek error: $e');
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    for (final player in _sfxPlayers) {
      player.dispose();
    }
    _narrationPlayer?.dispose();
    super.dispose();
  }
}

/// Riverpod provider cho DauVietAudioService
final dauVietAudioServiceProvider = Provider<DauVietAudioService>((ref) {
  return DauVietAudioService.instance;
});
