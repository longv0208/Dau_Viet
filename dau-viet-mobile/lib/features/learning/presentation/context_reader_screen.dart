import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/ambient_atmosphere_overlay.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/interactive_historical_mascot_widget.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../../core/widgets/story_audio_player_widget.dart';
import '../../../mock/data/mock_bach_dang_data.dart';

/// Màn hình M-09: Đọc Bối Cảnh Lịch Sử & Thư Tịch Cổ (Context Reader Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & ART_DIRECTION.md
class ContextReaderScreen extends StatefulWidget {
  const ContextReaderScreen({super.key});

  @override
  State<ContextReaderScreen> createState() => _ContextReaderScreenState();
}

class _ContextReaderScreenState extends State<ContextReaderScreen> {
  final Map<String, String> _glossary = {
    'Hoằng Tháo':
        'Con trai vua Nam Hán Lưu Cung, được phong làm Giao Châu vương thống lĩnh thủy quân xâm lược nước ta.',
    'bịt sắt':
        'Đầu cọc gỗ lim được gia cố kim loại nhọn để tăng sức công phá lườn đáy thuyền giặc khi triều rút.',
    'cửa biển':
        'Cửa biển Nam Triệu thuộc hạ lưu sông Bạch Đằng, vùng ranh giới giữa Hải Phòng và Quảng Ninh ngày nay.',
    'nước triều lên':
        'Hiện tượng nhật triều đặc biệt của vịnh Bắc Bộ: Mỗi ngày chỉ có một lần nước triều dâng cao và một lần nước triều rút cạn.',
  };

  @override
  Widget build(BuildContext context) {
    final evidence = MockBachDangData.evidenceToanThu;

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: AmbientAtmosphereOverlay(
        mode: AtmosphereMode.goldEmbers,
        backgroundImage: 'assets/images/bg_story_doanh_trai.jpg',
        backgroundOpacity: 0.20,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar Tiêu Đề & Năng Lượng
              _buildTopBar(context),

              // 2. Nội dung cuộn chính của bài đọc tư liệu
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 3. Khung Tiêu Đề Bài Học & Gợi Ý Sư Phạm
                      _buildHeaderCard(),
                      const SizedBox(height: 12),

                      // 3.1 Nhân vật đại diện Chibi Sĩ Tử Dấu Việt hướng dẫn
                      const InteractiveHistoricalMascotWidget(
                        state: MascotState.guiding,
                        message:
                            'Chào bạn! Hãy đọc kỹ từng câu chữ trong sử liệu và chạm vào các từ màu đỏ để mở khóa chú giải cổ thư nhé!',
                      ),
                      const SizedBox(height: 10),

                      // 3.2 Trình đọc âm thanh giọng dẫn sử liệu Duolingo Story Audio
                      const StoryAudioPlayerWidget(
                        title:
                            'Giọng đọc sử liệu: Đại Việt Sử Ký Toàn Thư (Năm 938)',
                        audioAsset: 'audio/narration_bach_dang.wav',
                      ),
                      const SizedBox(height: 14),

                      // 4. Khung Trích Dẫn Thư Tịch Cổ Tương Tác
                      _buildParchmentCitationCard(),
                      const SizedBox(height: 16),

                      // 5. Thẻ Nguồn Chứng Cứ Sử Học
                      _buildEvidenceSourceCard(evidence),
                      const SizedBox(height: 16),

                      // 6. Hộp Điểm Chốt Lịch Sử (Key Historical Insight)
                      _buildKeyInsightCard(),
                      const SizedBox(height: 24),

                      // 7. Nút Chuyển Tiếp Sang Hoạt Động Trắc Nghiệm M-16
                      DongSonButton(
                        label: 'LÀM TRẮC NGHIỆM TƯ LIỆU (M-16) ›',
                        icon: Icons.quiz_outlined,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/learning/quiz');
                        },
                      ),
                      const SizedBox(height: 10),
                      DongSonButton(
                        label: 'Quay Lại Trang Chủ',
                        icon: Icons.arrow_back_rounded,
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 48,
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
                        'DẤU VẾT 1',
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
                        'BỐI CẢNH LỊCH SỬ',
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
                  'Khai thác thư tịch cổ Hán Nôm',
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
          EnergyPill(
            energy: 100,
            maxEnergy: 100,
            showHistoryPoints: false,
            onEnergyTap: () => context.go('/energy'),
          ),
        ],
      ),
    );
  }

  // Khung hướng dẫn đọc hiểu
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.cinnabarRed,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khảo Cứu Quân Mưu Tiền Ngô Vương',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 15,
                    color: DauVietColors.cinnabarRed,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đọc kỹ trích đoạn sử liệu. Chạm vào các từ gạch chân đỏ để tra cứu từ vựng cổ.',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khung trích dẫn thư tịch cổ
  Widget _buildParchmentCitationCard() {
    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.8,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dấu trích dẫn cổ
          Row(
            children: [
              const Text('📜', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TRÍCH ĐOẠN ĐẠI VIỆT SỬ KÝ TOÀN THƯ',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Văn bản trích dẫn có RichText và từ điển tương tác
          RichText(
            text: TextSpan(
              style: DauVietTypography.bodyMedium.copyWith(
                fontSize: 15,
                height: 1.65,
                color: DauVietColors.inkText,
                fontFamily: 'Noto Serif',
              ),
              children: [
                const TextSpan(text: '“Quyền nghe tin '),
                _buildGlossarySpan('Hoằng Tháo'),
                const TextSpan(
                  text:
                      ' sắp đến, bảo các tướng tá rằng: Hoằng Tháo là đứa trẻ khờ dại, đem quân từ xa đến, quân lính mỏi mệt, lại nghe tin Công Tiễn đã chết, không có người làm nội ứng, khí thế đã mất một nửa rồi.\n\nNếu ta sai người vót nhọn cọc lớn ',
                ),
                _buildGlossarySpan('bịt sắt'),
                const TextSpan(text: ' cắm ngầm trước ở '),
                _buildGlossarySpan('cửa biển'),
                const TextSpan(text: ', thuyền giặc nhân khi '),
                _buildGlossarySpan('nước triều lên'),
                const TextSpan(
                  text:
                      ' tiến vào bên trong bãi cọc, sau đó ta dễ bề chế ngự, không kế gì hơn kế ấy.”',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: DauVietColors.outlineVariant, height: 1),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— Bản Kỷ Quyển 1, Kỷ Nhà Ngô',
              style: DauVietTypography.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: DauVietColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildGlossarySpan(String word) {
    return TextSpan(
      text: word,
      style: const TextStyle(
        color: DauVietColors.cinnabarRed,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dashed,
        decorationColor: DauVietColors.cinnabarRed,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          _showGlossarySheet(word, _glossary[word] ?? 'Thuật ngữ lịch sử cổ.');
        },
    );
  }

  // Thẻ thông tin nguồn tư liệu
  Widget _buildEvidenceSourceCard(dynamic evidence) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: DauVietColors.natureGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NGUỒN SỬ LIỆU KHẢO CỨU',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: DauVietColors.imperialGold,
                  ),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: DauVietColors.imperialGold,
                  ),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: DauVietColors.imperialGold,
                  ),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: DauVietColors.imperialGold,
                  ),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: DauVietColors.imperialGold,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            evidence.title as String,
            style: DauVietTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Phân loại: ${evidence.category} • Niên đại: ${evidence.dating}',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Hộp Điểm Chốt Lịch Sử
  Widget _buildKeyInsightCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DauVietColors.imperialGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: DauVietColors.imperialGold.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: DauVietColors.cinnabarRed,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUẬN ĐIỂM CỐT LÕI',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kế cọc ngầm được chuẩn bị bí mật từ tháng 10 năm 938. Ngô Quyền đã phân tích thế giặc kiệt sức và quy luật nhật triều để chủ động bày sẵn cạm bẫy từ trước khi giặc tới.',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGlossarySheet(String word, String definition) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DauVietColors.parchmentSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    color: DauVietColors.cinnabarRed,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    word,
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 18,
                      color: DauVietColors.cinnabarRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                definition,
                style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              DongSonButton(
                label: 'Đã hiểu',
                variant: DongSonButtonVariant.secondaryParchment,
                height: 44,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
