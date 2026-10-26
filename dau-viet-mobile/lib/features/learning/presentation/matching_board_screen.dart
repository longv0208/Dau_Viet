import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/dau_viet_audio_service.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/bite_sized_completion_modal.dart';
import '../../../core/widgets/combo_streak_badge_widget.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../../core/widgets/tactile_3d_card.dart';

/// Màn hình M-11: Bảng Ghép Nối Dữ Kiện Lịch Sử (Matching Board Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class MatchingBoardScreen extends StatefulWidget {
  const MatchingBoardScreen({super.key});

  @override
  State<MatchingBoardScreen> createState() => _MatchingBoardScreenState();
}

class _MatchingBoardScreenState extends State<MatchingBoardScreen> {
  String? _selectedLeftId;
  final Map<String, String> _matches = {}; // leftId -> rightId
  bool _isSubmitted = false;

  final List<Map<String, dynamic>> _leftItems = [
    {
      'id': 'L1',
      'title': 'Ngô Quyền',
      'icon': Icons.person_rounded,
      'correctRight': 'R2',
    },
    {
      'id': 'L2',
      'title': 'Sông Bạch Đằng',
      'icon': Icons.water_rounded,
      'correctRight': 'R4',
    },
    {
      'id': 'L3',
      'title': 'Bãi cọc gỗ lim',
      'icon': Icons.change_history_rounded,
      'correctRight': 'R1',
    },
    {
      'id': 'L4',
      'title': 'Quân Nam Hán',
      'icon': Icons.dangerous_rounded,
      'correctRight': 'R3',
    },
  ];

  final List<Map<String, dynamic>> _rightItems = [
    {
      'id': 'R1',
      'desc':
          'Vót nhọn bịt sắt cắm ngầm lúc triều rút, đâm vỡ đáy thuyền giặc.',
    },
    {
      'id': 'R2',
      'desc':
          'Chủ tướng mưu lược, hiểu thấu thế giặc và quy luật con nước triều.',
    },
    {
      'id': 'R3',
      'desc':
          'Hạm đội xâm lược do Hoằng Tháo cầm đầu, kiêu ngạo mắc bẫy truy đuổi.',
    },
    {
      'id': 'R4',
      'desc':
          'Địa bàn hiểm yếu có quy luật nhật triều và rừng sú vẹt thuận lợi mai phục.',
    },
  ];

  bool get _allMatched => _matches.length == _leftItems.length;

  bool get _isAllCorrect {
    if (!_allMatched) return false;
    for (final item in _leftItems) {
      if (_matches[item['id']] != item['correctRight']) {
        return false;
      }
    }
    return true;
  }

  void _onLeftTap(String leftId) {
    if (_isSubmitted) return;
    setState(() {
      if (_selectedLeftId == leftId) {
        _selectedLeftId = null;
      } else {
        _selectedLeftId = leftId;
      }
    });
  }

  void _onRightTap(String rightId) {
    if (_isSubmitted || _selectedLeftId == null) return;
    setState(() {
      // Gỡ bỏ ghép cũ nếu rightId đã được ghép bởi left khác
      _matches.removeWhere((key, value) => value == rightId);
      // Gán ghép mới
      _matches[_selectedLeftId!] = rightId;
      _selectedLeftId = null;
    });
    DauVietAudioService.instance.playTap();
  }

  void _removeMatch(String leftId) {
    if (_isSubmitted) return;
    setState(() {
      _matches.remove(leftId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: GoldConfettiOverlay(
        trigger: _isSubmitted && _isAllCorrect,
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
                    progress: _isSubmitted && _isAllCorrect
                        ? 1.0
                        : (_matches.length / _leftItems.length) * 0.85,
                    height: 8,
                    fillColor: _isSubmitted && _isAllCorrect
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
                        // 4. Khung Hướng Dẫn Sư Phạm
                        _buildInstructionCard(),
                        const SizedBox(height: 14),

                        // 5. Bảng Ghép Nối Hai Cột (Left & Right)
                        _buildMatchingGrid(),
                        const SizedBox(height: 16),

                        // 5. Khung Phản Hồi Sau Khi Nộp
                        if (_isSubmitted) ...[
                          _buildFeedbackCard(),
                          const SizedBox(height: 16),
                        ],

                        // 6. Cặp Nút Hành Động
                        if (!_isSubmitted)
                          DongSonButton(
                            label: 'KIỂM TRA KẾT QUẢ GHÉP NỐI',
                            icon: Icons.check_circle_outline_rounded,
                            variant: _allMatched
                                ? DongSonButtonVariant.primaryCinnabar
                                : DongSonButtonVariant.secondaryParchment,
                            height: 52,
                            onPressed: _allMatched
                                ? () {
                                    setState(() {
                                      _isSubmitted = true;
                                    });
                                    if (_isAllCorrect) {
                                      DauVietAudioService.instance
                                          .playCorrect();
                                      DauVietAudioService.instance
                                          .playStreakUp();
                                    } else {
                                      DauVietAudioService.instance.playWrong();
                                    }
                                  }
                                : null,
                          )
                        else
                          DongSonButton(
                            label: _isAllCorrect
                                ? 'HOÀN THÀNH DẤU VẾT 2 -> SANG DẤU VẾT 3 (M-12) ›'
                                : 'GHÉP LẠI CÁC CẶP CHƯA ĐÚNG',
                            icon: _isAllCorrect
                                ? Icons.arrow_forward_rounded
                                : Icons.replay_rounded,
                            variant: DongSonButtonVariant.primaryCinnabar,
                            height: 52,
                            onPressed: () {
                              if (_isAllCorrect) {
                                BiteSizedCompletionModal.show(
                                  context: context,
                                  title: 'CHIẾN CÔNG HOÀN TẤT!',
                                  subtitle:
                                      'Bạn đã ghép nối chuẩn xác các nhân vật, chiến thuật và địa danh Bạch Đằng 938!',
                                  scorePoints: 120,
                                  xpPoints: 60,
                                  accuracy: 1.0,
                                  streakCount: 4,
                                  badgeAsset:
                                      'assets/badges/badge_trace_2_characters.png',
                                  onContinue: () {
                                    context.go('/learning/order');
                                  },
                                );
                              } else {
                                setState(() {
                                  _isSubmitted = false;
                                  // Giữ lại cặp đúng, gỡ cặp sai
                                  _matches.removeWhere((leftId, rightId) {
                                    final item = _leftItems.firstWhere(
                                      (e) => e['id'] == leftId,
                                    );
                                    return item['correctRight'] != rightId;
                                  });
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
                context.go('/dashboard');
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
                        'DẤU VẾT 2',
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
                        'GHÉP NỐI DỮ KIỆN',
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
                  'Nhân vật, địa danh & chiến thuật Bạch Đằng',
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
          const EnergyPill(
            energy: 100,
            maxEnergy: 100,
            showHistoryPoints: false,
          ),
          const SizedBox(width: 8),
          const ComboStreakBadgeWidget(streakCount: 4),
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
            Icons.touch_app_rounded,
            color: DauVietColors.cinnabarRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chạm 1 mục ở cột trái, sau đó chạm vai trò tương ứng ở cột phải để kết nối.',
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

  // Bảng ghép nối hai cột
  Widget _buildMatchingGrid() {
    return Column(
      children: List.generate(_leftItems.length, (index) {
        final left = _leftItems[index];
        final right = _rightItems[index];

        final leftId = left['id'] as String;
        final rightId = right['id'] as String;

        final isLeftSelected = _selectedLeftId == leftId;
        final matchedRightId = _matches[leftId];

        // Tìm xem rightId này có được ghép với left nào không
        final matchedLeftEntry = _matches.entries
            .where((e) => e.value == rightId)
            .firstOrNull;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thẻ bên trái (Thực thể lịch sử)
              Expanded(
                flex: 5,
                child: _buildLeftCard(left, isLeftSelected, matchedRightId),
              ),
              const SizedBox(width: 8),

              // Thẻ bên phải (Mô tả vai trò)
              Expanded(
                flex: 6,
                child: _buildRightCard(right, matchedLeftEntry?.key),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLeftCard(
    Map<String, dynamic> item,
    bool isSelected,
    String? matchedRightId,
  ) {
    final id = item['id'] as String;
    final isMatched = matchedRightId != null;

    final isSubmittedCorrect =
        _isSubmitted && isMatched && (item['correctRight'] == matchedRightId);
    final isSubmittedWrong =
        _isSubmitted && isMatched && (item['correctRight'] != matchedRightId);

    return Tactile3DCard(
      isSelected: isSelected && !_isSubmitted,
      isCorrect: isSubmittedCorrect,
      isWrong: isSubmittedWrong,
      isEnabled: !_isSubmitted,
      depth: 3.5,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _onLeftTap(id),
      child: Row(
        children: [
          Icon(
            item['icon'] as IconData,
            size: 20,
            color: DauVietColors.cinnabarRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item['title'] as String,
              style: DauVietTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: DauVietColors.inkText,
                fontSize: 12,
              ),
            ),
          ),
          if (isMatched && !_isSubmitted)
            GestureDetector(
              onTap: () => _removeMatch(id),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: DauVietColors.inkMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightCard(Map<String, dynamic> item, String? matchedLeftId) {
    final id = item['id'] as String;
    final isMatched = matchedLeftId != null;

    final isSubmittedCorrect =
        _isSubmitted &&
        isMatched &&
        (_leftItems.firstWhere(
              (e) => e['id'] == matchedLeftId,
            )['correctRight'] ==
            id);
    final isSubmittedWrong =
        _isSubmitted &&
        isMatched &&
        (_leftItems.firstWhere(
              (e) => e['id'] == matchedLeftId,
            )['correctRight'] !=
            id);

    return Tactile3DCard(
      isSelected: false,
      isCorrect: isSubmittedCorrect,
      isWrong: isSubmittedWrong,
      isEnabled: !_isSubmitted && _selectedLeftId != null,
      depth: 3.5,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _onRightTap(id),
      child: Text(
        item['desc'] as String,
        style: DauVietTypography.bodySmall.copyWith(
          fontSize: 11,
          height: 1.35,
          color: DauVietColors.inkText,
        ),
      ),
    );
  }

  // Khung phản hồi sau khi kiểm tra
  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isAllCorrect
            ? const Color(0xFFEAF5EE)
            : const Color(0xFFFDEEEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAllCorrect
              ? DauVietColors.natureGreen
              : DauVietColors.cinnabarRed,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isAllCorrect ? Icons.stars_rounded : Icons.info_outline_rounded,
            color: _isAllCorrect
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
                  _isAllCorrect
                      ? 'XUẤT SẮC! GHÉP NỐI CHÍNH XÁC 100%'
                      : 'CÓ CẶP GHÉP CHƯA ĐÚNG',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _isAllCorrect
                        ? DauVietColors.natureGreen
                        : DauVietColors.cinnabarRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAllCorrect
                      ? 'Bạn đã liên kết chuẩn xác vai trò của chủ tướng Ngô Quyền, bãi cọc gỗ lim hiểm yếu và địa bàn sông Bạch Đằng. Nhận +100 Điểm Sử Ký!'
                      : 'Các cặp màu xanh là chính xác, cặp màu đỏ cần ghép lại. Hãy đọc kỹ đặc điểm từng thực thể.',
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
