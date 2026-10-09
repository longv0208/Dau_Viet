import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-18: Khải Hoàn Chiến Dịch & Tổng Kết Điểm (Event Victory Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class EventVictoryScreen extends StatelessWidget {
  final String eventId;

  const EventVictoryScreen({
    super.key,
    this.eventId = 'evt_bach_dang_938',
  });

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // 3. Khung Vinh danh Khải hoàn Hero
                      _buildVictoryHeroCard(),
                      const SizedBox(height: 16),

                      // 4. Chỉ số chiến công & Thống kê
                      _buildPerformanceStatsCard(),
                      const SizedBox(height: 16),

                      // 5. Danh sách 4 Dấu vết đã chinh phục
                      _buildTracesBreakdownCard(),
                      const SizedBox(height: 16),

                      // 6. Lời đúc kết chính sử
                      _buildHistoricalQuoteCard(),
                      const SizedBox(height: 20),

                      // 7. Cụm nút hành động CTA
                      DongSonButton(
                        label: 'NHẬN PHẦN THƯỞNG CHIẾN DỊCH (M-19) ›',
                        icon: Icons.card_giftcard_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/rewards/claim');
                        },
                      ),
                      const SizedBox(height: 10),
                      DongSonButton(
                        label: 'XEM LẠI 4 DẤU VẾT LỊCH SỬ',
                        icon: Icons.history_edu_rounded,
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 48,
                        onPressed: () {
                          context.go('/traces/$eventId');
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
                context.go('/traces/$eventId');
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
                        'KẾT QUẢ',
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
                        'KHẢI HOÀN KHẮC SỬ',
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
                  'Hoàn thành chiến dịch Bạch Đằng 938',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Khung vinh danh Hero với 3 sao vàng
  Widget _buildVictoryHeroCard() {
    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Dải Băng Khải Hoàn Di Sản
          Image.asset(
            'assets/images/victory_banner.png',
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DauVietColors.cinnabarRed,
                border: Border.all(color: DauVietColors.imperialGold, width: 3),
              ),
              child: const Icon(Icons.military_tech_rounded, color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: 12),

          // Tiêu đề Đại Thắng
          Text(
            'ĐẠI THẮNG BẠCH ĐẰNG',
            style: DauVietTypography.headlineLarge.copyWith(
              color: DauVietColors.cinnabarRed,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            'Kế Sách Cọc Ngầm Đè Bẹp Thủy Quân Nam Hán',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Đánh giá 3 sao vàng hoàng kim
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.star_rounded,
                  color: DauVietColors.imperialGold,
                  size: 34,
                  shadows: [
                    Shadow(
                      color: DauVietColors.inkText.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Huy hiệu danh hiệu học tập
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DauVietColors.imperialGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, color: DauVietColors.cinnabarRed, size: 16),
                const SizedBox(width: 6),
                Text(
                  'SĨ TỬ THÔNG TUỆ',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Thống kê thành tích
  Widget _buildPerformanceStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.check_circle_outline_rounded,
            color: DauVietColors.natureGreen,
            value: '100%',
            label: 'Độ Chính Xác',
          ),
          Container(width: 1, height: 36, color: DauVietColors.outlineVariant),
          _buildStatItem(
            icon: Icons.timer_outlined,
            color: DauVietColors.riverBlue,
            value: '3p 45s',
            label: 'Thời Gian',
          ),
          Container(width: 1, height: 36, color: DauVietColors.outlineVariant),
          _buildStatItem(
            icon: Icons.bolt_rounded,
            color: DauVietColors.cinnabarRed,
            value: '-20',
            label: 'Thể Lực',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: DauVietTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11,
            color: DauVietColors.inkMuted,
          ),
        ),
      ],
    );
  }

  // Danh sách 4 Dấu vết đã chinh phục
  Widget _buildTracesBreakdownCard() {
    final traces = [
      {'num': '1', 'name': 'Bối Cảnh & Quân Mưu', 'type': 'Khảo cứu thư tịch & Trắc nghiệm'},
      {'num': '2', 'name': 'Nhân Vật & Bố Phòng', 'type': 'Ghép nối dữ kiện 4 cặp'},
      {'num': '3', 'name': 'Sa Bàn Tác Chiến', 'type': 'Sắp xếp niên đại con nước triều'},
      {'num': '4', 'name': 'Khảo Cổ & Di Sản', 'type': 'Kiểm chứng giả thuyết & Mô hình CER'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_outlined, color: DauVietColors.cinnabarRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '4 DẤU VẾT ĐÃ CHINH PHỤC (100%):',
                style: DauVietTypography.labelSmall.copyWith(
                  color: DauVietColors.inkMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...traces.map((trace) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAF7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DauVietColors.natureGreen.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: DauVietColors.natureGreen,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    trace['num']!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dấu Vết ${trace['num']}: ${trace['name']}',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: DauVietColors.inkText,
                        ),
                      ),
                      Text(
                        trace['type']!,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 10.5,
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: DauVietColors.natureGreen, size: 20),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Khung đúc kết chính sử
  Widget _buildHistoricalQuoteCard() {
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
              const Icon(Icons.format_quote_rounded, color: DauVietColors.cinnabarRed, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'LỜI BÀN CỦA SỬ GIA NGÔ SĨ LIÊN:',
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
            '“Tiền Ngô Vương mưu tài đánh giỏi, làm nên chiến công khải hoàn ngút trời, rửa sạch quốc sỉ ngàn năm, mở nền độc lập tự chủ cho nước Nam ta.”',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              fontStyle: FontStyle.italic,
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
