import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/shake_animation_widget.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/tactile_3d_card.dart';

/// Màn hình M-16: Hoạt Động Trắc Nghiệm Tư Liệu Tương Tác (Multiple Choice Quiz Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
/// Tích hợp hiệu ứng vi mô xúc giác 3D, thanh lướt sáng và pháo hoa ánh vàng chuẩn Duolingo
class MultipleChoiceQuizScreen extends StatefulWidget {
  const MultipleChoiceQuizScreen({super.key});

  @override
  State<MultipleChoiceQuizScreen> createState() => _MultipleChoiceQuizScreenState();
}

class _MultipleChoiceQuizScreenState extends State<MultipleChoiceQuizScreen> {
  String? _selectedOptionId;
  bool _isSubmitted = false;
  final Map<String, GlobalKey<ShakeAnimationWidgetState>> _shakeKeys = {};

  final List<Map<String, dynamic>> _options = [
    {
      'id': 'opt_a',
      'label': 'A',
      'text': 'Để chuẩn bị bí mật khi giặc chưa tới và con nước triều đang rút cạn lộ bãi, dễ dàng cắm cọc sâu vào lòng sông.',
      'isCorrect': true,
    },
    {
      'id': 'opt_b',
      'label': 'B',
      'text': 'Để ngăn chặn thuyền buôn dân sự không đi vào cửa biển Nam Triệu trong thời kỳ chiến sự.',
      'isCorrect': false,
    },
    {
      'id': 'opt_c',
      'label': 'C',
      'text': 'Vì cọc gỗ lim chỉ đóng được vào ban đêm lúc có trăng sáng để các hào trưởng định vị hướng dòng chảy.',
      'isCorrect': false,
    },
    {
      'id': 'opt_d',
      'label': 'D',
      'text': 'Được đóng cấp tốc ngay trong lúc hai bên đang giao chiến trực diện giữa dòng nước lớn.',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GoldConfettiOverlay(
        trigger: _isSubmitted && _isCorrect,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DauVietColors.parchmentSurface,
                Color(0xFFFAF2E4),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Top Bar Hoạt Động & Thanh Tiến Trình
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

                // 3. Nội dung cuộn chính của câu hỏi
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 4. Khung Câu Hỏi Trắc Nghiệm Trung Tâm
                        _buildQuestionCard(),
                        const SizedBox(height: 18),

                        // 5. Danh Sách Các Lựa Chọn Đáp Án (3D Tactile Cards)
                        ..._options.map((option) => _buildOptionTile(option)),
                        const SizedBox(height: 16),

                        // 6. Khung Phản Hồi Sư Phạm (Hiện ra sau khi nộp)
                        if (_isSubmitted) ...[
                          _buildFeedbackCard(),
                          const SizedBox(height: 20),
                        ],

                        // 7. Nút Hành Động 3D: Kiểm Tra hoặc Tiếp Tục
                        if (!_isSubmitted)
                          DongSonButton(
                            label: 'KIỂM TRA KẾT QUẢ',
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
                                ? 'HOÀN THÀNH DẤU VẾT 1 & TIẾP TỤC ›'
                                : 'THỬ CHỌN LẠI ĐÁP ÁN',
                            icon: _isCorrect ? Icons.arrow_forward_rounded : Icons.replay_rounded,
                            variant: DongSonButtonVariant.primaryCinnabar,
                            height: 52,
                            onPressed: () {
                              if (_isCorrect) {
                                context.go('/traces/evt_bach_dang_938');
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
                context.go('/learning/context-reader');
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
                        'TRẮC NGHIỆM',
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
                        'KIỂM CHỨNG TƯ LIỆU',
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
                  'Hoạt động 2/2 • Dấu Vết 1',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, size: 16, color: DauVietColors.imperialGold),
                const SizedBox(width: 4),
                Text(
                  '+100',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khung câu hỏi
  Widget _buildQuestionCard() {
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: DauVietColors.cinnabarRed, size: 20),
              const SizedBox(width: 8),
              Text(
                'CÂU HỎI TRUNG TÂM SỬ KÝ',
                style: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.cinnabarRed,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tại sao việc đóng cọc gỗ ngầm phải được quân dân ta bí mật chuẩn bị từ tháng 10 năm 938 (trước khi thủy quân Nam Hán kéo đến)?',
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 16,
              height: 1.45,
              color: DauVietColors.inkText,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: ShakeAnimationWidget(
        key: _shakeKeys[id],
        child: Tactile3DCard(
          isSelected: isSelected && !_isSubmitted,
          isCorrect: isSubmittedCorrect,
          isWrong: isSubmittedWrong,
          isEnabled: !_isSubmitted,
          depth: 4.0,
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
              // Chữ cái đầu phương án (A, B, C, D)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: labelBg,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nội dung đáp án
              Expanded(
                child: Text(
                  text,
                  style: DauVietTypography.bodyMedium.copyWith(
                    height: 1.4,
                    color: DauVietColors.inkText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),

              // Icon trạng thái sau khi nộp
              if (statusIcon != null) ...[
                const SizedBox(width: 8),
                Icon(
                  statusIcon,
                  size: 24,
                  color: isOptionCorrect ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Khung giải thích sư phạm sau khi trả lời
  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  _isCorrect ? 'XUẤT SẮC! CĂN CỨ SỬ HỌC CHÍNH XÁC' : 'CHƯA CHÍNH XÁC',
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _isCorrect ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isCorrect
                ? 'Đúng như ghi chép trong Đại Việt Sử Ký Toàn Thư, việc đóng cọc gỗ lim cần nhiều công sức đốn gỗ, vót nhọn bịt sắt và phải cắm ngầm lúc triều rút để bảo đảm tính bí mật quân sự tuyệt đối trước khi Lưu Hoằng Tháo kéo tới.'
                : 'Hãy đọc lại trích đoạn tư liệu: Ngô Quyền chuẩn bị cắm cọc trước ở cửa biển để khi thuyền giặc nhân triều lên tiến vào mới bị sập bẫy khi triều rút.',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
