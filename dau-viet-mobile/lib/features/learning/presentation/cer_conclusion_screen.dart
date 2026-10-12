import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/audio/dau_viet_audio_service.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/ambient_atmosphere_overlay.dart';
import '../../../core/widgets/bite_sized_completion_modal.dart';
import '../../../core/widgets/combo_streak_badge_widget.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/interactive_historical_mascot_widget.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../../core/widgets/story_audio_player_widget.dart';

/// Màn hình M-14: Kết Luận Lập Luận CER (Claim - Evidence - Reasoning Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class CerConclusionScreen extends StatefulWidget {
  const CerConclusionScreen({super.key});

  @override
  State<CerConclusionScreen> createState() => _CerConclusionScreenState();
}

class _CerConclusionScreenState extends State<CerConclusionScreen> {
  String? _selectedEvidenceId;
  bool _isSubmitted = false;

  final List<Map<String, dynamic>> _evidenceOptions = [
    {
      'id': 'evi_1',
      'title': 'Di Chỉ Khảo Cổ Bãi Cọc Yên Giang (Quảng Ninh)',
      'desc': 'Hàng trăm cọc gỗ lim bịt sắt cắm nghiêng 15-45 độ xuôi theo dòng chảy, định tuổi Carbon phóng xạ C-14 thế kỷ X SCN.',
      'isStrong': true,
    },
    {
      'id': 'evi_2',
      'title': 'Truyền Thuyết Dân Gian Về Vị Tướng Đánh Cá',
      'desc': 'Giai thoại truyền miệng qua nhiều thế hệ của cư dân ven cửa biển sông Bạch Đằng.',
      'isStrong': false,
    },
  ];

  bool get _isStrongEvidence {
    if (_selectedEvidenceId == null) return false;
    final item = _evidenceOptions.firstWhere((e) => e['id'] == _selectedEvidenceId);
    return item['isStrong'] as bool;
  }

  @override
  Widget build(BuildContext context) {
    final mascotState = !_isSubmitted
        ? MascotState.guiding
        : (_isStrongEvidence ? MascotState.cheering : MascotState.thinking);

    final mascotMessage = !_isSubmitted
        ? 'Hãy chọn nguồn bằng chứng có tính thực chứng khảo cổ học cao nhất để hoàn thiện mô hình CER!'
        : (_isStrongEvidence
            ? 'Hoan hô! Luận điểm vững chắc kết hợp di chỉ khảo cổ Yên Giang giúp phục dựng lịch sử chân thực nhất!'
            : 'Truyền thuyết dân gian rất giàu cảm xúc nhưng chưa đủ tính xác thực khoa học bằng di chỉ bãi cọc khảo cổ.');

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: AmbientAtmosphereOverlay(
        mode: AtmosphereMode.goldEmbers,
        backgroundImage: 'assets/images/bg_story_thu_phong.jpg',
        backgroundOpacity: 0.18,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar Tiêu Đề & Năng Lượng
              _buildTopBar(context),

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

                      // 3. Khung Giới Thiệu Mô Hình CER
                      _buildHeaderIntroCard(),
                      const SizedBox(height: 14),

                      // 4. Khối C - Claim (Luận điểm trung tâm)
                      _buildClaimCard(),
                      const SizedBox(height: 14),

                      // 5. Khối E - Evidence (Chọn bằng chứng mạnh nhất)
                      _buildEvidenceSelectionSection(),
                      const SizedBox(height: 14),

                      // 6. Khối R - Reasoning (Xuất hiện sau khi chọn bằng chứng đúng)
                      if (_isSubmitted) ...[
                        _buildReasoningCard(),
                        const SizedBox(height: 16),
                      ],

                      // 7. Cặp Nút Hành Động
                      if (!_isSubmitted)
                        DongSonButton(
                          label: 'XÁC LẬP LUẬN ĐIỂM CER',
                          icon: Icons.verified_rounded,
                          variant: _selectedEvidenceId != null
                              ? DongSonButtonVariant.primaryCinnabar
                              : DongSonButtonVariant.secondaryParchment,
                          height: 52,
                          onPressed: _selectedEvidenceId != null
                              ? () {
                                  setState(() {
                                    _isSubmitted = true;
                                  });
                                  if (_isStrongEvidence) {
                                    DauVietAudioService.instance.playCorrect();
                                    DauVietAudioService.instance.playStreakUp();
                                  } else {
                                    DauVietAudioService.instance.playWrong();
                                  }
                                }
                              : null,
                        )
                      else
                        DongSonButton(
                          label: _isStrongEvidence
                              ? 'HOÀN THÀNH & KHẢI HOÀN CHIẾN DỊCH (M-18) ›'
                              : 'CHỌN LẠI BẰNG CHỨNG MẠNH NHẤT',
                          icon: _isStrongEvidence ? Icons.emoji_events_rounded : Icons.replay_rounded,
                          variant: DongSonButtonVariant.primaryCinnabar,
                          height: 52,
                          onPressed: () {
                            if (_isStrongEvidence) {
                              BiteSizedCompletionModal.show(
                                context: context,
                                title: 'TOÀN THẮNG CHIẾN DỊCH!',
                                subtitle: 'Bạn đã hoàn thiện xuất sắc mô hình lập luận CER và minh định toàn bộ 4 Dấu Vết Bạch Đằng 938!',
                                scorePoints: 200,
                                xpPoints: 100,
                                accuracy: 1.0,
                                streakCount: 7,
                                multiplier: 2.0,
                                badgeAsset: 'assets/badges/badge_trace_1_context.png',
                                onContinue: () {
                                  context.go('/rewards/victory');
                                },
                              );
                            } else {
                              setState(() {
                                _isSubmitted = false;
                                _selectedEvidenceId = null;
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
                        'KẾT LUẬN CER',
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
                  'Mô hình Claim - Evidence - Reasoning',
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
            streakCount: 7,
            multiplier: 2.0,
          ),
        ],
      ),
    );
  }

  // Khung giới thiệu mô hình CER
  Widget _buildHeaderIntroCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.cinnabarRed,
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Rèn luyện năng lực sử học: Kết nối Luận điểm (Claim) với Bằng chứng (Evidence) và Lập luận khoa học (Reasoning).',
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

  // Khối C - Claim (Luận điểm lịch sử)
  Widget _buildClaimCard() {
    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.8,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DauVietColors.cinnabarRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'C — CLAIM (LUẬN ĐIỂM)',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified_rounded, size: 18, color: DauVietColors.imperialGold),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“Kế sách cọc ngầm của Tiền Ngô Vương Ngô Quyền trên sông Bạch Đằng năm 938 là sự thật lịch sử khách quan, minh chứng cho đỉnh cao nghệ thuật quân sự lấy đoản chế trường.”',
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 15,
              color: DauVietColors.inkText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // Khối E - Evidence (Chọn bằng chứng)
  Widget _buildEvidenceSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'E — EVIDENCE (BẰNG CHỨNG KHOA HỌC)',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Chọn nguồn mạnh nhất',
              style: DauVietTypography.labelSmall.copyWith(
                color: DauVietColors.cinnabarRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ..._evidenceOptions.map((opt) {
          final id = opt['id'] as String;
          final isSelected = _selectedEvidenceId == id;
          final isStrong = opt['isStrong'] as bool;

          Color borderCol = DauVietColors.outlineVariant;
          Color bgCol = Colors.white.withValues(alpha: 0.9);

          if (_isSubmitted) {
            if (isStrong) {
              borderCol = DauVietColors.natureGreen;
              bgCol = const Color(0xFFEAF5EE);
            } else if (isSelected && !isStrong) {
              borderCol = DauVietColors.cinnabarRed;
              bgCol = const Color(0xFFFDEEEC);
            }
          } else if (isSelected) {
            borderCol = DauVietColors.imperialGold;
            bgCol = DauVietColors.parchmentContainer;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: _isSubmitted
                  ? null
                  : () {
                      setState(() {
                        _selectedEvidenceId = id;
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol, width: isSelected || (_isSubmitted && isStrong) ? 1.8 : 1.0),
                  boxShadow: isSelected ? DauVietColors.heritageShadow : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? DauVietColors.cinnabarRed : DauVietColors.inkMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['title'] as String,
                            style: DauVietTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: DauVietColors.inkText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            opt['desc'] as String,
                            style: DauVietTypography.bodySmall.copyWith(
                              fontSize: 11,
                              height: 1.35,
                              color: DauVietColors.inkText.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // Khối R - Reasoning (Lập luận logic)
  Widget _buildReasoningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isStrongEvidence ? const Color(0xFFEAF5EE) : const Color(0xFFFDEEEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isStrongEvidence ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
          width: 1.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isStrongEvidence ? DauVietColors.natureGreen : DauVietColors.cinnabarRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'R — REASONING (LẬP LUẬN)',
                    style: DauVietTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isStrongEvidence)
                const Text(
                  '🏅 NHÀ SỬ HỌC TRẺ',
                  style: TextStyle(
                    color: DauVietColors.natureGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isStrongEvidence
                ? 'Hiện vật khảo cổ học thực địa có niên đại C-14 thế kỷ X hoàn toàn trùng khớp với ghi chép trong Đại Việt Sử Ký Toàn Thư. Đặc biệt, hướng cắm cọc nghiêng 15-45 độ xuôi dòng triều chứng minh quân ta đã tính toán chính xác để khi nước rút, chiến thuyền giặc xuôi ra biển sẽ tự đâm phập vào cọc nhọn bịt sắt, chứng minh sự kết hợp tài tình giữa mưu trí con người và quy luật tự nhiên.'
                : 'Truyền thuyết dân gian là nguồn tư liệu thứ cấp có giá trị văn hóa, nhưng không đủ tính thực chứng khoa học để làm bằng chứng cốt lõi. Hãy chọn di chỉ khảo cổ học Yên Giang.',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.45,
              fontSize: 12,
            ),
          ),
          if (_isStrongEvidence) ...[
            const SizedBox(height: 12),
            const StoryAudioPlayerWidget(
              title: 'Giọng đọc tổng kết: Luận chứng Bạch Đằng 938',
              audioAsset: 'audio/narration_bach_dang.wav',
              compact: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: DauVietColors.imperialGold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phần thưởng: +200 Điểm Sử Ký • +100 XP',
                      style: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DauVietColors.cinnabarRed,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
