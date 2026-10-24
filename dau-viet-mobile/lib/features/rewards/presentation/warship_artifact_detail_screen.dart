import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../mock/data/mock_bach_dang_data.dart';

/// Màn hình M-21: Chi Tiết Cổ Vật Chiến Hạm Thủy Quân Bạch Đằng (Warship Artifact Detail Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class WarshipArtifactDetailScreen extends StatelessWidget {
  final String artifactId;

  const WarshipArtifactDetailScreen({
    super.key,
    this.artifactId = 'art_thuyen_chien_938',
  });

  @override
  Widget build(BuildContext context) {
    final artifact = MockBachDangData.artifactThuyenChien;

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF7EB),
              DauVietColors.parchmentSurface,
              Color(0xFFF7ECDA),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Thanh tiêu đề trên cùng
              _buildTopBar(context),

              // 2. Nội dung cuộn chính
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      // 3. Khung Trưng Bày Cổ Vật (Museum Display Hero)
                      _buildArtifactDisplayCard(artifact),
                      const SizedBox(height: 16),

                      // 4. Bảng Thông Số Kỹ Thuật Quân Sự Cổ Truyền
                      _buildTechnicalSpecsCard(),
                      const SizedBox(height: 16),

                      // 5. Ý Nghĩa Lịch Sử & Nghệ Thuật Quân Sự
                      _buildHistoricalSignificanceCard(artifact),
                      const SizedBox(height: 16),

                      // 6. Địa Điểm Lưu Giữ & Bảo Tồn Hiện Vật
                      _buildConservationLocationCard(artifact),
                      const SizedBox(height: 20),

                      // 7. Cặp Nút Hành Động
                      DongSonButton(
                        label: 'CẤT VÀO TÚI ĐỒ & VỀ BÀN HỌC (M-03) ›',
                        icon: Icons.check_circle_outline_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/dashboard');
                        },
                      ),
                      const SizedBox(height: 10),
                      DongSonButton(
                        label: 'XEM LẠI PHẦN THƯỞNG CHIẾN DỊCH (M-19)',
                        icon: Icons.card_giftcard_rounded,
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 48,
                        onPressed: () {
                          context.go('/rewards/claim');
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
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: DauVietColors.inkText,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/rewards/claim');
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
                        'CỔ VẬT',
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
                        'CHI TIẾT DI SẢN',
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
                  'Kho Cổ Vật Lịch Sử Việt Nam',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
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

  // Khung trưng bày cổ vật trên bệ gỗ viện bảo tàng
  Widget _buildArtifactDisplayCard(dynamic artifact) {
    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Bệ trưng bày hiện vật
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2B211B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DauVietColors.imperialGold, width: 2),
              boxShadow: DauVietColors.heritageShadow,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hiệu ứng sóng nước mờ dưới đáy
                Positioned(
                  bottom: 12,
                  child: Container(
                    width: 220,
                    height: 18,
                    decoration: BoxDecoration(
                      color: DauVietColors.riverBlue.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Biểu tượng thuyền chiến Bạch Đằng
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_boat_filled_rounded,
                      color: DauVietColors.imperialGold,
                      size: 64,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CHIẾN THUYỀN ĐÁY NÔNG THẾ KỶ X',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.parchmentSurface,
                        fontSize: 10,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // Huy hiệu phẩm cấp góc trên
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: DauVietColors.imperialGold,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      artifact.rarity as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tên hiện vật & Niên đại
          Text(
            artifact.name as String,
            textAlign: TextAlign.center,
            style: DauVietTypography.headlineMedium.copyWith(
              color: DauVietColors.cinnabarRed,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            'Niên đại: ${artifact.era}',
            style: DauVietTypography.labelSmall.copyWith(
              color: DauVietColors.inkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            artifact.description as String,
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Bảng thông số kỹ thuật quân sự cổ truyền
  Widget _buildTechnicalSpecsCard() {
    final specs = [
      {'label': 'Chiều dài thân thuyền', 'value': '15 – 18 mét'},
      {'label': 'Chiều rộng mạn thuyền', 'value': '2.2 – 2.5 mét'},
      {'label': 'Đặc tính cấu trúc đáy', 'value': 'Đáy nông, lướt nước cạn'},
      {'label': 'Thủy binh biên chế', 'value': '25 – 30 dũng sĩ'},
      {'label': 'Vũ khí trang bị', 'value': 'Cung nỏ, giáo mác, đuốc hỏa công'},
      {
        'label': 'Chiến thuật sở trường',
        'value': 'Lấy đoản chế trường, nhử địch',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: DauVietColors.cinnabarRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'THÔNG SỐ QUÂN SỰ CỔ TRUYỀN:',
                style: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.inkText,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...specs.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      item['label']!,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: Text(
                      item['value']!,
                      style: DauVietTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DauVietColors.inkText,
                        fontSize: 11.5,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Ý nghĩa lịch sử & Nghệ thuật thủy chiến
  Widget _buildHistoricalSignificanceCard(dynamic artifact) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F1E2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_rounded,
                color: DauVietColors.cinnabarRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GIÁ TRỊ CHIẾN LƯỢC QUỐC GIA:',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            artifact.historicalSignificance as String,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Địa điểm lưu giữ & Di tích
  Widget _buildConservationLocationCard(dynamic artifact) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.natureGreen, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.museum_rounded,
            color: DauVietColors.natureGreen,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ĐỊA ĐIỂM KHAI QUẬT & BẢO TỒN:',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.natureGreen,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  artifact.excavationLocation as String,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trưng bày tại Bảo tàng Lịch sử Quốc gia & Khu Di tích Quốc gia Đặc biệt Bạch Đằng.',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
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
