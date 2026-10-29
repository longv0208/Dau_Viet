import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import '../audio/dau_viet_audio_service.dart';

/// Các trạng thái cảm xúc của Mascot Kabi theo chuẩn gamification Duolingo
enum KabiMood {
  idle, // Nghỉ ngơi / Chờ đợi
  guiding, // Đang dẫn nhập / Chỉ tay hướng dẫn sử liệu
  cheering, // Trả lời ĐÚNG! Nhảy cẫng ăn mừng, cười rạng rỡ
  thinking, // Trả lời SAI! Đăm chiêu gãi đầu, động viên thử lại
  streak, // Chuỗi đúng liên tiếp! Đeo kính râm ngầu, bốc lửa
  victory, // Hoàn thành bài học! Ôm cúp vàng vinh quang
}

/// Widget hiển thị Linh vật Kabi (Capybara Mascot) từ repository bryllim/kabi-mascot
/// Rive 0.14.x: dùng FileLoader + RiveWidgetController + RiveWidget (API mới,
/// input lấy qua stateMachine.number/boolean/trigger thay SMI* cũ).
class KabiMascotWidget extends StatefulWidget {
  final KabiMood mood;
  final double width;
  final double height;
  final bool headOnly;
  final bool enableSound;
  final VoidCallback? onTap;

  const KabiMascotWidget({
    super.key,
    this.mood = KabiMood.guiding,
    this.width = 110,
    this.height = 110,
    this.headOnly = false,
    this.enableSound = true,
    this.onTap,
  });

  @override
  State<KabiMascotWidget> createState() => _KabiMascotWidgetState();
}

class _KabiMascotWidgetState extends State<KabiMascotWidget> {
  rive.FileLoader? _fileLoader;
  rive.RiveWidgetController? _controller;

  rive.NumberInput? _poseInput;
  rive.NumberInput? _moodInput;
  rive.NumberInput? _colorInput;
  rive.BooleanInput? _headOnlyInput;
  rive.BooleanInput? _glassesInput;
  rive.TriggerInput? _jumpTrigger;
  rive.TriggerInput? _pokeTrigger;

  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (DauVietAudioService.isTestEnvironment) {
      _hasError = true;
      return;
    }
    final loader = rive.FileLoader.fromAsset(
      'assets/rive/kabi.riv',
      riveFactory: rive.Factory.rive,
    );
    _fileLoader = loader;
    loader
        .file()
        .then((file) {
          if (!mounted) return;
          try {
            final controller = rive.RiveWidgetController(
              file,
              artboardSelector: const rive.ArtboardNamed('Kabi'),
              stateMachineSelector: const rive.StateMachineNamed('Kabi'),
            );
            final sm = controller.stateMachine;
            _poseInput = sm.number('pose');
            _moodInput = sm.number('mood');
            _colorInput = sm.number('color');
            _headOnlyInput = sm.boolean('headOnly');
            _glassesInput = sm.boolean('glasses');
            _jumpTrigger = sm.trigger('jump');
            _pokeTrigger = sm.trigger('poke');
            setState(() => _controller = controller);
            _applyMood();
          } catch (_) {
            setState(() => _hasError = true);
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fileLoader?.dispose();
    super.dispose();
  }

  void _applyMood() {
    if (_controller == null) return;

    _headOnlyInput?.value = widget.headOnly;
    // Màu Đỏ Chu Sa (2) hoặc Nâu truyền thống (7)
    _colorInput?.value = 2;

    switch (widget.mood) {
      case KabiMood.idle:
        _poseInput?.value = 0; // idle
        _moodInput?.value = 0; // neutral
        _glassesInput?.value = false;
        break;
      case KabiMood.guiding:
        _poseInput?.value = 21; // presentLeft / chỉ tay hướng dẫn
        _moodInput?.value = 1; // happy
        _glassesInput?.value = false;
        break;
      case KabiMood.cheering:
        _poseInput?.value = 7; // celebrate
        _moodInput?.value = 1; // happy
        _glassesInput?.value = false;
        _jumpTrigger?.fire();
        break;
      case KabiMood.thinking:
        _poseInput?.value = 19; // thinking
        _moodInput?.value = 4; // sad
        _glassesInput?.value = false;
        break;
      case KabiMood.streak:
        _poseInput?.value = 27; // fistPump
        _moodInput?.value = 7; // proud
        _glassesInput?.value = true; // sunglasses on!
        break;
      case KabiMood.victory:
        _poseInput?.value = 7; // celebrate
        _moodInput?.value = 7; // proud
        _glassesInput?.value = false;
        _jumpTrigger?.fire();
        break;
    }
  }

  @override
  void didUpdateWidget(covariant KabiMascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood ||
        oldWidget.headOnly != widget.headOnly) {
      _applyMood();
    }
  }

  void _handleTap() {
    if (widget.enableSound) {
      DauVietAudioService.instance.playTap();
    }
    _pokeTrigger?.fire();
    _jumpTrigger?.fire();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Trong môi trường test hoặc nếu Rive tải lỗi, fallback sang ảnh đại diện an toàn
    final isTest =
        DauVietAudioService.isTestEnvironment ||
        (kIsWeb == false &&
            defaultTargetPlatform == TargetPlatform.windows &&
            _hasError);

    if (isTest || _hasError) {
      return _buildFallbackMascot();
    }

    final controller = _controller;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: controller == null
            ? _buildFallbackMascot()
            : rive.RiveWidget(controller: controller, fit: rive.Fit.contain),
      ),
    );
  }

  Widget _buildFallbackMascot() {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: DauVietAudioService.isTestEnvironment
            ? null
            : Image.asset(
                'assets/images/turtle_welcome.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF2E7D32),
                ),
              ),
      ),
    );
  }
}
