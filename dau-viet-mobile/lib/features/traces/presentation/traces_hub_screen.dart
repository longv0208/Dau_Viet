import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-08: Trung Tâm 4 Dấu Vết Lịch Sử (4 Traces Exploration Hub)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & ART_DIRECTION.md
class TracesHubScreen extends StatelessWidget {
  final String eventId;

  const TracesHubScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
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

              // 2. Nội dung cuộn chính
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 3. Khối Tiến Trình Thu Thập Dấu Vết
                      _buildProgressCard(),
                      const SizedBox(height: 18),

                      // 4. Tiêu đề khối lưới
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '4 DẤU VẾT LỊCH SỬ CẦN GIẢI MÃ',
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
                            'Hoàn thành tuần tự',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.cinnabarRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 5. Danh Sách 4 Thẻ Bài Dấu Vết Di Sản
                      _buildTraceCard(
                        context: context,
                        number: '1',
                        title: 'Dấu Vết 1: Bối Cảnh & Quân Mưu',
                        subtitle:
                            'Thư tịch cổ: Vì sao đóng cọc trước khi giặc đến?',
                        statusLabel: 'SẴN SÀNG KHÁM PHÁ',
                        statusColor: DauVietColors.natureGreen,
                        icon: Icons.auto_stories_rounded,
                        isUnlocked: true,
                        isCurrent: true,
                        onTap: () {
                          context.go('/learning/context-reader');
                        },
                      ),
                      const SizedBox(height: 12),

                      _buildTraceCard(
                        context: context,
                        number: '2',
                        title: 'Dấu Vết 2: Nhân Vật & Bố Phòng',
                        subtitle:
                            'Ghép dữ kiện: Tiền Ngô Vương & Bãi cọc Yên Giang',
                        statusLabel: 'SẴN SÀNG GHÉP NỐI',
                        statusColor: DauVietColors.imperialGold,
                        icon: Icons.shield_rounded,
                        isUnlocked: true,
                        isCurrent: false,
                        onTap: () {
                          context.go('/learning/matching');
                        },
                      ),
                      const SizedBox(height: 12),

                      _buildTraceCard(
                        context: context,
                        number: '3',
                        title: 'Dấu Vết 3: Sa Bàn Tác Chiến',
                        subtitle:
                            'Sắp xếp niên đại: Nhịp con nước triều & Phản công',
                        statusLabel: 'SẴN SÀNG KÉO THẢ',
                        statusColor: DauVietColors.riverBlue,
                        icon: Icons.military_tech_rounded,
                        isUnlocked: true,
                        isCurrent: false,
                        onTap: () {
                          context.go('/learning/order');
                        },
                      ),
                      const SizedBox(height: 12),

                      _buildTraceCard(
                        context: context,
                        number: '4',
                        title: 'Dấu Vết 4: Khảo Cổ & Di Sản',
                        subtitle:
                            'Kiểm chứng giả thuyết (M-13) & Lập luận CER (M-14)',
                        statusLabel: 'SẴN SÀNG KHÁM PHÁ',
                        statusColor: DauVietColors.natureGreen,
                        icon: Icons.museum_rounded,
                        isUnlocked: true,
                        isCurrent: true,
                        onTap: () {
                          context.go('/learning/verification');
                        },
                      ),
                      const SizedBox(height: 20),

                      // 6. Nút Hành Động Khám Phá
                      DongSonButton(
                        label: 'BẮT ĐẦU DẤU VẾT 1: BỐI CẢNH (M-09) ›',
                        icon: Icons.play_arrow_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/learning/context-reader');
                        },
                      ),
                      const SizedBox(height: 10),
                      DongSonButton(
                        label: 'XEM LẠI SA BÀN CHIẾN THUẬT (M-06)',
                        icon: Icons.map_outlined,
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 48,
                        onPressed: () {
                          context.go('/saban');
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
                context.go('/campaign/$eventId');
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4 DẤU VẾT LỊCH SỬ',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 16,
                    color: DauVietColors.inkText,
                  ),
                ),
                Text(
                  'Chiến Dịch Bạch Đằng 938 • Hồi 2',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const EnergyPill(
            energy: 100,
            maxEnergy: 100,
            showHistoryPoints: false,
          ),
        ],
      ),
    );
  }

  // Khối tổng kết tiến trình 4 dấu vết
  Widget _buildProgressCard() {
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'HÀNH TRÌNH KHÁM PHÁ',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tiến độ: 1/4 Dấu Vết',
                style: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DauVietColors.cinnabarRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Thu thập đủ 4 Dấu Vết để mở khóa Bảo vật Chiến Thuyền Bạch Đằng (M-21) và nhận +500 Điểm Sử Ký.',
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0.25,
              minHeight: 8,
              backgroundColor: DauVietColors.parchmentHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DauVietColors.cinnabarRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thẻ bài từng Dấu Vết Di Sản
  Widget _buildTraceCard({
    required BuildContext context,
    required String number,
    required String title,
    required String subtitle,
    required String statusLabel,
    required Color statusColor,
    required IconData icon,
    required bool isUnlocked,
    required bool isCurrent,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ParchmentCard(
        backgroundColor: isCurrent
            ? DauVietColors.parchmentContainer
            : isUnlocked
            ? Colors.white.withValues(alpha: 0.85)
            : const Color(0xFFF0EAE1),
        borderColor: isCurrent
            ? DauVietColors.imperialGold
            : isUnlocked
            ? DauVietColors.outlineVariant
            : Colors.black12,
        borderWidth: isCurrent ? 2.0 : 1.0,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Huy hiệu số thứ tự tròn kèm ảnh badge di sản
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? DauVietColors.cinnabarRed
                    : isUnlocked
                    ? DauVietColors.imperialGold
                    : DauVietColors.inkMuted.withValues(alpha: 0.5),
                border: Border.all(
                  color: isCurrent ? DauVietColors.imperialGold : Colors.white,
                  width: 2,
                ),
                boxShadow: isCurrent ? DauVietColors.heritageShadow : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                _getBadgeAssetForNumber(number),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      fontFamily: 'Noto Serif',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nội dung chi tiết
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
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: DauVietTypography.labelSmall.copyWith(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!isUnlocked)
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: DauVietColors.inkMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: DauVietTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isCurrent
                          ? DauVietColors.cinnabarRed
                          : DauVietColors.inkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: DauVietColors.inkMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Icon biểu trưng
            Icon(
              icon,
              size: 24,
              color: isCurrent
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _getBadgeAssetForNumber(String number) {
    switch (number) {
      case '1':
        return 'assets/badges/badge_trace_1_context.png';
      case '2':
        return 'assets/badges/badge_trace_2_characters.png';
      case '3':
        return 'assets/badges/badge_trace_3_tactics.png';
      case '4':
        return 'assets/badges/badge_trace_4_archaeology.png';
      default:
        return 'assets/badges/badge_trace_1_context.png';
    }
  }
}
