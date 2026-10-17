import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/dau_viet_audio_service.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/bite_sized_completion_modal.dart';
import '../../../core/widgets/combo_streak_badge_widget.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../../core/widgets/tactile_3d_card.dart';

/// Màn hình M-12: Kéo Thả & Sắp Xếp Niên Đại Chiến Dịch (Chronological Order Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class ChronologicalOrderScreen extends StatefulWidget {
  const ChronologicalOrderScreen({super.key});

  @override
  State<ChronologicalOrderScreen> createState() =>
      _ChronologicalOrderScreenState();
}

class _ChronologicalOrderScreenState extends State<ChronologicalOrderScreen> {
  // Thứ tự đúng: prepare -> invade -> lure -> victory
  final List<String> _correctOrder = [
    'step_prepare',
    'step_invade',
    'step_lure',
    'step_victory',
  ];

  // Danh sách khởi tạo (được xáo trộn để người học sắp xếp)
  late List<Map<String, dynamic>> _items;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _items = [
      {
        'id': 'step_invade',
        'title': 'Địch Vượt Cửa Biển',
        'text':
            'Đạo thủy quân Nam Hán do Hoằng Tháo chỉ huy vượt biển hùng hổ tiến vào cửa sông Bạch Đằng.',
      },
      {
        'id': 'step_prepare',
        'title': 'Chuẩn Bị Cọc Ngầm',
        'text':
            'Ngô Quyền họp bàn kế sách, quân dân bí mật đốn gỗ lim vót nhọn bịt sắt cắm ngầm lúc triều rút.',
      },
      {
        'id': 'step_victory',
        'title': 'Tổng Phản Công Đại Thắng',
        'text':
            'Triều rút xiết, cọc gỗ nhô lên đâm thủng vỡ thuyền giặc, quân ta quật lại tiêu diệt hoàn toàn quân thù.',
      },
      {
        'id': 'step_lure',
        'title': 'Khiêu Chiến & Nhử Địch',
        'text':
            'Thuyền nhẹ quân ta ra khiêu chiến rồi giả thua rút chạy, nhử thuyền địch vượt qua bãi cọc lúc triều dâng.',
      },
    ];
  }

  bool get _isOrderCorrect {
    for (int i = 0; i < _items.length; i++) {
      if (_items[i]['id'] != _correctOrder[i]) {
        return false;
      }
    }
    return true;
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    if (_isSubmitted) return;
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _moveUp(int index) {
    if (_isSubmitted || index == 0) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index - 1, item);
    });
    DauVietAudioService.instance.playTap();
  }

  void _moveDown(int index) {
    if (_isSubmitted || index == _items.length - 1) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index + 1, item);
    });
    DauVietAudioService.instance.playTap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GoldConfettiOverlay(
        trigger: _isSubmitted && _isOrderCorrect,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [DauVietColors.parchmentSurface, Color(0xFFFAF2E4)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Top Bar Tiêu Đề & Năng Lượng
                _buildTopBar(context),

                // 2. Thanh tiến độ lướt sáng hoàng kim Duolingo
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ShimmerProgressBar(
                    progress: _isSubmitted && _isOrderCorrect
                        ? 1.0
                        : (_isSubmitted ? 0.6 : 0.4),
                    height: 8,
                    fillColor: _isSubmitted && _isOrderCorrect
                        ? DauVietColors.natureGreen
                        : DauVietColors.cinnabarRed,
                  ),
                ),

                // 3. Nội dung cuộn chính
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 4. Khung Hướng Dẫn Kéo Thả
                        _buildInstructionCard(),
                        const SizedBox(height: 14),

                        // 5. Danh Sách Sắp Xếp Niên Đại (Drag & Reorder)
                        _buildReorderableList(),
                        const SizedBox(height: 16),

                        // 5. Khung Phản Hồi Sau Khi Nộp
                        if (_isSubmitted) ...[
                          _buildFeedbackCard(),
                          const SizedBox(height: 16),
                        ],

                        // 6. Nút Hành Động
                        if (!_isSubmitted)
                          DongSonButton(
                            label: 'KIỂM TRA THỨ TỰ NIÊN ĐẠI',
                            icon: Icons.check_circle_outline_rounded,
                            variant: DongSonButtonVariant.primaryCinnabar,
                            height: 52,
                            onPressed: () {
                              setState(() {
                                _isSubmitted = true;
                              });
                              if (_isOrderCorrect) {
                                DauVietAudioService.instance.playCorrect();
                                DauVietAudioService.instance.playStreakUp();
                              } else {
                                DauVietAudioService.instance.playWrong();
                              }
                            },
                          )
                        else
                          DongSonButton(
                            label: _isOrderCorrect
                                ? 'HOÀN THÀNH DẤU VẾT 3 & TIẾP TỤC (M-08) ›'
                                : 'SẮP XẾP LẠI THỨ TỰ',
                            icon: _isOrderCorrect
                                ? Icons.arrow_forward_rounded
                                : Icons.replay_rounded,
                            variant: DongSonButtonVariant.primaryCinnabar,
                            height: 52,
                            onPressed: () {
                              if (_isOrderCorrect) {
                                BiteSizedCompletionModal.show(
                                  context: context,
                                  title: 'NIÊN BIỂU CHÍNH XÁC!',
                                  subtitle:
                                      'Bạn đã nắm vững toàn bộ 4 giai đoạn chiến dịch Bạch Đằng từ chuẩn bị đến toàn thắng!',
                                  scorePoints: 150,
                                  xpPoints: 80,
                                  accuracy: 1.0,
                                  streakCount: 5,
                                  multiplier: 2.0,
                                  badgeAsset:
                                      'assets/badges/badge_trace_3_tactics.png',
                                  onContinue: () {
                                    context.go('/traces/evt_bach_dang_938');
                                  },
                                );
                              } else {
                                setState(() {
                                  _isSubmitted = false;
                                });
                              }
                            },
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Header đỉnh trang
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            color: DauVietColors.inkText,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/traces/evt_bach_dang_938');
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DẤU VẾT 3',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'SẮP XẾP NIÊN ĐẠI',
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 16,
                          color: DauVietColors.inkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '4 bước ngoặt diễn biến Bạch Đằng 938',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SoundToggleButton(),
          const SizedBox(width: 8),
          const ComboStreakBadgeWidget(streakCount: 5, multiplier: 2.0),
        ],
      ),
    );
  }

  // Khung hướng dẫn
  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.swap_vert_rounded,
            color: DauVietColors.cinnabarRed,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kéo giữ biểu tượng ☰ hoặc bấm nút mũi tên ▲▼ để di chuyển các bước theo đúng trình tự thời gian.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Danh sách các bước diễn biến
  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      onReorderItem: _onReorderItem,
      itemBuilder: (context, index) {
        final item = _items[index];
        final id = item['id'] as String;
        final stepNumber = index + 1;

        final isCorrectPosition = _isSubmitted && id == _correctOrder[index];

        Color numBg = DauVietColors.parchmentHigh;
        Color numFg = DauVietColors.inkText;

        if (_isSubmitted) {
          if (isCorrectPosition) {
            numBg = DauVietColors.natureGreen;
            numFg = Colors.white;
          } else {
            numBg = DauVietColors.cinnabarRed;
            numFg = Colors.white;
          }
        }

        return Container(
          key: ValueKey(id),
          margin: const EdgeInsets.only(bottom: 12),
          child: Tactile3DCard(
            isCorrect: _isSubmitted && isCorrectPosition,
            isWrong: _isSubmitted && !isCorrectPosition,
            depth: 3.5,
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thứ tự mốc
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: numBg,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: numFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nội dung diễn biến
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: DauVietTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _isSubmitted && isCorrectPosition
                              ? DauVietColors.natureGreen
                              : DauVietColors.inkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['text'] as String,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkText.withValues(alpha: 0.85),
                          height: 1.35,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Nút điều khiển trợ năng (Lên / Xuống) & Tay cầm kéo
                if (!_isSubmitted)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: index > 0 ? () => _moveUp(index) : null,
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 20,
                          color: index > 0
                              ? DauVietColors.cinnabarRed
                              : Colors.black12,
                        ),
                      ),
                      const Icon(
                        Icons.drag_handle_rounded,
                        size: 20,
                        color: DauVietColors.inkMuted,
                      ),
                      GestureDetector(
                        onTap: index < _items.length - 1
                            ? () => _moveDown(index)
                            : null,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: index < _items.length - 1
                              ? DauVietColors.cinnabarRed
                              : Colors.black12,
                        ),
                      ),
                    ],
                  )
                else
                  Icon(
                    isCorrectPosition
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isCorrectPosition
                        ? DauVietColors.natureGreen
                        : DauVietColors.cinnabarRed,
                    size: 22,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Khung phản hồi sau khi kiểm tra
  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isOrderCorrect
            ? const Color(0xFFEAF5EE)
            : const Color(0xFFFDEEEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOrderCorrect
              ? DauVietColors.natureGreen
              : DauVietColors.cinnabarRed,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isOrderCorrect ? Icons.stars_rounded : Icons.info_outline_rounded,
            color: _isOrderCorrect
                ? DauVietColors.natureGreen
                : DauVietColors.cinnabarRed,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOrderCorrect
                      ? 'TUYỆT VỜI! ĐÚNG TRÌNH TỰ CHIẾN THUẬT'
                      : 'CHƯA ĐÚNG TRÌNH TỰ THỜI GIAN',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _isOrderCorrect
                        ? DauVietColors.natureGreen
                        : DauVietColors.cinnabarRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOrderCorrect
                      ? 'Bạn đã tái hiện chuẩn xác 4 bước ngoặt: Chuẩn bị cọc ngầm -> Địch vượt biển -> Nhử địch triều dâng -> Phản công triều rút toàn thắng. Nhận +150 Điểm Sử Ký + 50 XP!'
                      : 'Lưu ý: Bãi cọc phải được chuẩn bị trước khi địch tới, và quân ta chỉ phản công khi con nước triều bắt đầu rút mạnh.',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
