import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/dau_viet_audio_service.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/ambient_atmosphere_overlay.dart';
import '../../../core/widgets/bite_sized_completion_modal.dart';
import '../../../core/widgets/combo_streak_badge_widget.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/interactive_historical_mascot_widget.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/shake_animation_widget.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../../core/widgets/tactile_3d_card.dart';

/// Màn hình M-13: Kiểm Chứng Giả Thuyết Lịch Sử (Hypothesis Verification Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class HypothesisVerificationScreen extends StatefulWidget {
  const HypothesisVerificationScreen({super.key});

  @override
  State<HypothesisVerificationScreen> createState() => _HypothesisVerificationScreenState();
}

class _HypothesisVerificationScreenState extends State<HypothesisVerificationScreen> {
  String? _selectedOptionId;
  bool _isSubmitted = false;
  final Map<String, GlobalKey<ShakeAnimationWidgetState>> _shakeKeys = {};

  final List<Map<String, dynamic>> _options = [
    {
      'id': 'opt_a',
      'label': 'A',
      'text': 'Giả thuyết nghi vấn là SAI. Hiện vật cọc gỗ lim khảo cổ học thế kỷ X và thư tịch cổ của cả hai phía chứng minh kế cọc ngầm là sự thật lịch sử được khoa học xác thực.',
      'isCorrect': true,
    },
    {
      'id': 'opt_b',
      'label': 'B',
      'text': 'Giả thuyết đúng. Trận cọc ngầm chỉ là sự thêu dệt trong truyền thuyết dân gian của cư dân chài lưới.',
      'isCorrect': false,
    },
    {
      'id': 'opt_c',
      'label': 'C',
      'text': 'Hiện nay vẫn chưa có đủ cứ liệu khảo cổ học để đưa ra bất kỳ kết luận xác đáng nào.',
      'isCorrect': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    for (final opt in _options) {
      _shakeKeys[opt['id'] as String] = GlobalKey<ShakeAnimationWidgetState>();
    }
  }

  bool get _isCorrect {
    if (_selectedOptionId == null) return false;
    final opt = _options.firstWhere((o) => o['id'] == _selectedOptionId);
    return opt['isCorrect'] as bool;
  }

  void _submitAnswer() {
    setState(() {
      _isSubmitted = true;
    });
    if (!_isCorrect && _selectedOptionId != null) {
      _shakeKeys[_selectedOptionId]?.currentState?.shake();
      DauVietAudioService.instance.playWrong();
    } else if (_isCorrect) {
      DauVietAudioService.instance.playCorrect();
      DauVietAudioService.instance.playStreakUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascotState = !_isSubmitted
        ? MascotState.guiding
        : (_isCorrect ? MascotState.cheering : MascotState.thinking);

    final mascotMessage = !_isSubmitted
        ? 'Hãy đối chiếu hiện vật cọc gỗ thực địa Yên Giang với thư tịch cổ để tìm câu trả lời chuẩn xác nhất!'
        : (_isCorrect
            ? 'Chính xác! Niên đại C-14 thế kỷ X xác thực trận địa cọc ngầm Bạch Đằng là sự thật lịch sử vĩ đại!'
            : 'Chưa chính xác! Di chỉ bãi cọc Yên Giang và Đồng Vạn Muối đã được giám định khoa học C-14.');

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GoldConfettiOverlay(
        trigger: _isSubmitted && _isCorrect,
        child: AmbientAtmosphereOverlay(
          mode: AtmosphereMode.riverMist,
          backgroundImage: 'assets/images/bg_story_tran_dia.jpg',
          backgroundOpacity: 0.18,
          child: SafeArea(
            child: Column(
              children: [
                // 1. Top Bar Tiêu Đề & Năng Lượng
                _buildTopBar(context),

                // 2. Thanh tiến độ lướt sáng hoàng kim Duolingo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ShimmerProgressBar(
                    progress: _isSubmitted && _isCorrect
                        ? 1.0
                        : (_selectedOptionId != null ? 0.75 : 0.4),
                    height: 8,
                    fillColor: _isSubmitted && _isCorrect
                        ? DauVietColors.natureGreen
                        : DauVietColors.cinnabarRed,
                  ),
                ),

              // 2. Nội dung cuộn chính
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2.1 Mascot Chibi Sĩ Tử Dấu Việt phản hồi
                      InteractiveHistoricalMascotWidget(
                        state: mascotState,
                        message: mascotMessage,
                      ),
                      const SizedBox(height: 10),

                      // 3. Khung Giả Thuyết Nghi Vấn
                      _buildHypothesisBox(),
                      const SizedBox(height: 14),

                      // 4. Khung Dữ Liệu Đối Chiếu Thực Địa & Thư Tịch
                      _buildEvidenceComparisonSection(),
                      const SizedBox(height: 16),

                      // 5. Câu Hỏi Phản Biện & Các Lựa Chọn
                      Text(
                        'KẾT LUẬN CỦA BẠN SAU KHI ĐỐI CHIẾU DỮ LIỆU:',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.inkMuted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._options.map((option) => _buildOptionTile(option)),
                      const SizedBox(height: 14),

                      // 6. Khung Phản Hồi Sư Phạm
                      if (_isSubmitted) ...[
                        _buildFeedbackCard(),
                        const SizedBox(height: 16),
                      ],

                      // 7. Cặp Nút Hành Động
                      if (!_isSubmitted)
                        DongSonButton(
                          label: 'KIỂM TRA KẾT LUẬN ĐỐI CHIẾU',
                          icon: Icons.check_circle_outline_rounded,
                          variant: _selectedOptionId != null
                              ? DongSonButtonVariant.primaryCinnabar
                              : DongSonButtonVariant.secondaryParchment,
                          height: 52,
                          onPressed: _selectedOptionId != null ? _submitAnswer : null,
                        )
                      else
                        DongSonButton(
                          label: _isCorrect
                              ? 'TIẾP TỤC SANG LẬP LUẬN CER (M-14) ›'
                              : 'CHỌN LẠI KẾT LUẬN',
                          icon: _isCorrect ? Icons.arrow_forward_rounded : Icons.replay_rounded,
                          variant: DongSonButtonVariant.primaryCinnabar,
                          height: 52,
                          onPressed: () {
                            if (_isCorrect) {
                              BiteSizedCompletionModal.show(
                                context: context,
                                title: 'ĐỐI CHIẾU SỬ LIỆU THÀNH CÔNG!',
                                subtitle: 'Bạn đã xuất sắc phân biệt giữa hư cấu văn học và chứng cứ khảo cổ học thực địa!',
                                scorePoints: 180,
                                xpPoints: 90,
                                accuracy: 1.0,
                                streakCount: 6,
                                multiplier: 2.0,
                                badgeAsset: 'assets/badges/badge_trace_4_archaeology.png',
                                onContinue: () {
                                  context.go('/learning/cer');
                                },
                              );
                            } else {
                              setState(() {
                                _isSubmitted = false;
                                _selectedOptionId = null;
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DẤU VẾT 4',
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
                        'KIỂM CHỨNG GIẢ THUYẾT',
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
                  'Đối chiếu thực địa khảo cổ & thư tịch cổ',
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
          const ComboStreakBadgeWidget(
            streakCount: 6,
            multiplier: 2.0,
          ),
        ],
      ),
    );
  }

  // Khung giả thuyết hoài nghi
  Widget _buildHypothesisBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF2E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.cinnabarRed.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: DauVietColors.cinnabarRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GIẢ THUYẾT / Ý KIẾN NGHI VẤN',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '“Có ý kiến cho rằng: Trận cọc ngầm Bạch Đằng chỉ là truyền thuyết dân gian do người đời sau thêu dệt, vì người xưa không thể vót và cắm hàng vạn cọc gỗ lim dưới lòng sông sâu và rộng trong thời gian ngắn.”',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              fontStyle: FontStyle.italic,
              height: 1.45,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // Khung dữ liệu đối chiếu đa nguồn
  Widget _buildEvidenceComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DỮ LIỆU ĐỐI CHIẾU THỰC TẾ:',
          style: DauVietTypography.labelSmall.copyWith(
            color: DauVietColors.inkMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Nguồn 1: Khảo cổ học thực địa
        ParchmentCard(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          borderColor: DauVietColors.imperialGold,
          borderWidth: 1.2,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.museum_rounded, color: DauVietColors.natureGreen, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Khảo Cổ Bãi Cọc Yên Giang (Quảng Ninh)',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Phát hiện hàng trăm cọc gỗ lim đường kính 20-30cm, cắm nghiêng 15-45 độ xuôi dòng triều. Định tuổi Carbon phóng xạ C-14: Thế kỷ X SCN (trùng khớp năm 938).',
                      style: DauVietTypography.bodySmall.copyWith(fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Nguồn 2: Thư tịch hai phía
        ParchmentCard(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          borderColor: DauVietColors.imperialGold,
          borderWidth: 1.2,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_stories_rounded, color: DauVietColors.riverBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Đối Chiếu Thư Tịch Chính Sử Hai Phía',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Đại Việt Sử Ký Toàn Thư (nước ta) và Tân Đường Thư, Tống Sử (phương Bắc) đều ghi nhận Hoằng Tháo đền tội và toàn bộ chiến thuyền bị tiêu diệt tại cửa sông Bạch Đằng.',
                      style: DauVietTypography.bodySmall.copyWith(fontSize: 11, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Thẻ một phương án lựa chọn (3D Tactile Card + Shake feedback)
  Widget _buildOptionTile(Map<String, dynamic> option) {
    final id = option['id'] as String;
    final label = option['label'] as String;
    final text = option['text'] as String;
    final isOptionCorrect = option['isCorrect'] as bool;

    final isSelected = _selectedOptionId == id;
    final isSubmittedCorrect = _isSubmitted && isOptionCorrect;
    final isSubmittedWrong = _isSubmitted && isSelected && !isOptionCorrect;

    Color labelBg = DauVietColors.parchmentHigh;
    Color labelFg = DauVietColors.inkText;
    IconData? statusIcon;

    if (_isSubmitted) {
      if (isOptionCorrect) {
        labelBg = DauVietColors.natureGreen;
        labelFg = Colors.white;
        statusIcon = Icons.check_circle_rounded;
      } else if (isSelected && !isOptionCorrect) {
        labelBg = DauVietColors.cinnabarRed;
        labelFg = Colors.white;
        statusIcon = Icons.cancel_rounded;
      }
    } else if (isSelected) {
      labelBg = DauVietColors.cinnabarRed;
      labelFg = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShakeAnimationWidget(
        key: _shakeKeys[id],
        child: Tactile3DCard(
          isSelected: isSelected && !_isSubmitted,
          isCorrect: isSubmittedCorrect,
          isWrong: isSubmittedWrong,
          isEnabled: !_isSubmitted,
          depth: 3.5,
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(10),
          onTap: _isSubmitted
              ? null
              : () {
                  setState(() {
                    _selectedOptionId = id;
                  });
                },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: labelBg,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(color: labelFg, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: DauVietTypography.bodySmall.copyWith(
                    height: 1.35,
                    color: DauVietColors.inkText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (statusIcon != null) ...[
                const SizedBox(width: 6),
                Icon(statusIcon, size: 22, color: isOptionCorrect ? DauVietColors.natureGreen : DauVietColors.cinnabarRed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Khung giải thích sư phạm sau khi đối chiếu
  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isCorrect ? const Color(0xFFEAF5EE) : const Color(0xFFFDEEEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCorrect ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCorrect ? Icons.stars_rounded : Icons.info_outline_rounded,
                color: _isCorrect ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isCorrect ? 'CHÍNH XÁC! TƯ DUY PHẢN BIỆN KHOA HỌC' : 'CHƯA CHÍNH XÁC',
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _isCorrect ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isCorrect
                ? 'Phương pháp sử học hiện đại kết hợp giữa khảo cứu văn bản và khảo cổ học thực nghiệm. Bãi cọc Yên Giang niên đại C-14 thế kỷ X là bằng chứng thép bác bỏ mọi nghi vấn.'
                : 'Hãy đối chiếu: Cọc gỗ lim có niên đại C-14 thế kỷ X được khai quật thực tế tại Quảng Ninh, hoàn toàn khớp với ghi chép của cả sử Việt lẫn sử Trung Quốc.',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
