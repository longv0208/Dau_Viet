import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide Image;

import '../audio/dau_viet_audio_service.dart';
import '../theme/dau_viet_colors.dart';

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
/// Sử dụng công nghệ Rive Bone-rigged Animation v7, hỗ trợ 29 poses & 8 moods
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
  StateMachineController? _controller;
  SMINumber? _poseInput;
  SMINumber? _moodInput;
  SMINumber? _colorInput;
  SMIBool? _headOnlyInput;
  SMIBool? _glassesInput;
  SMITrigger? _jumpTrigger;
  SMITrigger? _pokeTrigger;

  bool _hasError = false;

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        'Kabi',
      );
      if (controller == null) return;
      artboard.addController(controller);
      _controller = controller;

      for (final input in controller.inputs) {
        if (input.name == 'pose' && input is SMINumber) _poseInput = input;
        if (input.name == 'mood' && input is SMINumber) _moodInput = input;
        if (input.name == 'color' && input is SMINumber) _colorInput = input;
        if (input.name == 'headOnly' && input is SMIBool) _headOnlyInput = input;
        if (input.name == 'glasses' && input is SMIBool) _glassesInput = input;
        if (input.name == 'jump' && input is SMITrigger) _jumpTrigger = input;
        if (input.name == 'poke' && input is SMITrigger) _pokeTrigger = input;
      }

      _applyMood();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
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
    if (oldWidget.mood != widget.mood || oldWidget.headOnly != widget.headOnly) {
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
    final isTest = DauVietAudioService.isTestEnvironment || kIsWeb == false && defaultTargetPlatform == TargetPlatform.windows && _hasError;

    if (isTest || _hasError) {
      return _buildFallbackMascot();
    }

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: RiveAnimation.asset(
          'assets/rive/kabi.riv',
          artboard: 'Kabi',
          stateMachines: const ['Kabi'],
          fit: BoxFit.contain,
          onInit: _onRiveInit,
          placeHolder: SizedBox(width: widget.width, height: widget.height),
        ),
      ),
    );
  }

  Widget _buildFallbackMascot() {
    // Không hiển thị bất kỳ icon vui / buồn nào làm chớp nháy trước khi mascot tải xong
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
      ),
    );
  }
}
