import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-19: Nhận Thưởng Chiến Dịch & Rương Báu (Reward Claim Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class RewardClaimScreen extends StatelessWidget {
  const RewardClaimScreen({super.key});

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
                      // 3. Hoạt cảnh Rương Báu Mở Ra
                      _buildChestRewardHero(),
                      const SizedBox(height: 16),

                      // 4. Lưới Vật Phẩm Nhận Được
                      _buildRewardItemsGrid(),
                      const SizedBox(height: 16),

                      // 5. Thẻ Mở Khóa Thành Tích
                      _buildAchievementUnlockedCard(),
                      const SizedBox(height: 16),

                      // 6. Thẻ Cổ Vật Độc Bản Nhận Được
                      _buildCollectiblePreviewCard(context),
                      const SizedBox(height: 20),

                      // 7. Cặp Nút Hành Động
                      DongSonButton(
                        label: 'CHIÊM NGƯỠNG BẢO VẬT CHIẾN THUYỀN (M-21) ›',
                        icon: Icons.directions_boat_filled_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/rewards/artifact/art_thuyen_chien_938');
                        },
                      ),
                      const SizedBox(height: 10),
                      DongSonButton(
                        label: 'VỀ BÀN HỌC TẬP (DASHBOARD)',
                        icon: Icons.home_rounded,
                        variant: DongSonButtonVariant.secondaryParchment,
                        height: 48,
                        onPressed: () {
                          context.go('/dashboard');
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
                context.go('/rewards/victory');
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
                        'PHẦN THƯỞNG',
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
                        'NHẬN CHIẾN LỢI PHẨM',
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
                  'Rương Báu Hoàng Gia Bạch Đằng',
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

  // Hoạt cảnh Rương Báu Mở Ra
  Widget _buildChestRewardHero() {
    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Rương đồng mở nắp tỏa hào quang
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DauVietColors.imperialGold.withValues(alpha: 0.25),
                  boxShadow: [
                    BoxShadow(
                      color: DauVietColors.imperialGold.withValues(alpha: 0.6),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DauVietColors.cinnabarRed,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DauVietColors.imperialGold, width: 2.5),
                  boxShadow: DauVietColors.heritageShadow,
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'RƯƠNG BẢO VẬT HOÀNG GIA',
            style: DauVietTypography.headlineLarge.copyWith(
              color: DauVietColors.cinnabarRed,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            'Phần thưởng xứng đáng cho Sĩ Tử thấu triệt 4 dấu vết',
            textAlign: TextAlign.center,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Lưới các vật phẩm nhận được
  Widget _buildRewardItemsGrid() {
    return Row(
      children: [
        // 1. Điểm Sử Ký
        Expanded(
          child: _buildRewardBox(
            icon: Icons.history_edu_rounded,
            color: DauVietColors.imperialGold,
            value: '+500',
            label: 'Điểm Sử Ký',
            desc: 'Đổi đồ Đảo di sản',
          ),
        ),
        const SizedBox(width: 8),

        // 2. XP Sĩ Tử
        Expanded(
          child: _buildRewardBox(
            icon: Icons.auto_awesome_rounded,
            color: DauVietColors.riverBlue,
            value: '+300 XP',
            label: 'Kinh Nghiệm',
            desc: 'Thăng cấp Sĩ Tử',
          ),
        ),
        const SizedBox(width: 8),

        // 3. Tiền Đồng Sơn
        Expanded(
          child: _buildRewardBox(
            icon: Icons.monetization_on_rounded,
            color: DauVietColors.cinnabarRed,
            value: '+50',
            label: 'Đồng Cổ',
            desc: 'Tiền giao thương',
          ),
        ),
      ],
    );
  }

  Widget _buildRewardBox({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: DauVietTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DauVietTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: DauVietColors.inkText,
              fontSize: 10.5,
            ),
          ),
          Text(
            desc,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 9.5,
              color: DauVietColors.inkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Thẻ Mở Khóa Thành Tích Mới
  Widget _buildAchievementUnlockedCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.natureGreen, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.natureGreen,
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DauVietColors.natureGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'MỞ KHÓA THÀNH TÍCH',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hào Khí Bạch Đằng: Định Quốc An Dân',
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 14,
                    color: DauVietColors.inkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đã giải mã thành công 4 dấu vết lịch sử với độ chính xác 100% không qua trợ giúp.',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: DauVietColors.inkMuted,
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

  // Thẻ Cổ Vật Độc Bản Nhận Được
  Widget _buildCollectiblePreviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: DauVietColors.cinnabarRed,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
            ),
            child: const Icon(
              Icons.directions_boat_filled_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DauVietColors.imperialGold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CỔ VẬT HIẾM',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: DauVietColors.inkText,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Chiến Thuyền Bạch Đằng (Thế kỷ X)',
                  style: DauVietTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkText,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Mô hình phục dựng thủy chiến lấy đoản chế trường',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: DauVietColors.cinnabarRed,
            size: 24,
          ),
        ],
      ),
    );
  }
}
