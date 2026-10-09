import 'package:flutter/material.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/heritage_scaffold.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình Trưng bày & Kiểm định Theme Di sản v2.0 (Phase M1 Showcase)
class ThemeShowcaseScreen extends StatelessWidget {
  const ThemeShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HeritageScaffold(
      title: 'Dấu Việt v2.0 • Theme Di Sản',
      showBack: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner Card
            ParchmentCard(
              backgroundColor: DauVietColors.parchmentContainer,
              borderColor: DauVietColors.imperialGold,
              borderWidth: 1.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: DauVietColors.cinnabarRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CHIẾN DỊCH TIÊU BIỂU',
                          style: DauVietTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.verified_rounded, color: DauVietColors.natureGreen, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Chuẩn GDPT 2018',
                        style: DauVietTypography.labelSmall.copyWith(color: DauVietColors.natureGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Đại Chiến Bạch Đằng 938',
                    style: DauVietTypography.headlineLarge.copyWith(color: DauVietColors.cinnabarRed),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hồi 2: Kế sách cọc ngầm & Phối hợp quy luật thủy triều',
                    style: DauVietTypography.headlineSmall.copyWith(color: DauVietColors.inkText),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mô phỏng trải nghiệm học tập di sản văn hiến trên nền tảng Flutter. Tích hợp trích dẫn cổ thư, bản đồ sa bàn và mô hình lập luận khoa học.',
                    style: DauVietTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Typography Showcase
            Text('HỆ THỐNG TYPOGRAPHY', style: DauVietTypography.labelMedium.copyWith(color: DauVietColors.inkMuted)),
            const SizedBox(height: 8),
            ParchmentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Noto Serif Tiêu Đề Lớn (26px)', style: DauVietTypography.headlineLarge),
                  const Divider(color: DauVietColors.outlineVariant, height: 20),
                  Text('Noto Serif Niên Đại & Mục (20px)', style: DauVietTypography.headlineMedium),
                  const Divider(color: DauVietColors.outlineVariant, height: 20),
                  Text(
                    'Trích Đại Việt Sử Ký Toàn Thư: "Quyền nghe tin Hoằng Tháo sắp đến, bảo các tướng tá rằng: Hoằng Tháo là đứa trẻ khờ dại..."',
                    style: DauVietTypography.ancientCitation,
                  ),
                  const Divider(color: DauVietColors.outlineVariant, height: 20),
                  Text('Be Vietnam Pro - Nội dung mô tả và giải thích khoa học dễ đọc trên mọi thiết bị di động (14px).', style: DauVietTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Color Palette Chips
            Text('BẢNG MÀU VĂN HIẾN ĐẠI VIỆT', style: DauVietTypography.labelMedium.copyWith(color: DauVietColors.inkMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildColorChip('Đỏ Chu Sa', DauVietColors.cinnabarRed, Colors.white),
                _buildColorChip('Vàng Ngự Xưởng', DauVietColors.imperialGold, DauVietColors.inkText),
                _buildColorChip('Lục Ngàn', DauVietColors.natureGreen, Colors.white),
                _buildColorChip('Lam Giang', DauVietColors.riverBlue, Colors.white),
                _buildColorChip('Nâu Gỗ Lim', DauVietColors.woodBrown, Colors.white),
                _buildColorChip('Mực Nho', DauVietColors.inkText, Colors.white),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Text('HỆ THỐNG NÚT BẤM ĐÔNG SƠN', style: DauVietTypography.labelMedium.copyWith(color: DauVietColors.inkMuted)),
            const SizedBox(height: 8),
            Column(
              children: [
                DongSonButton(
                  label: 'Bắt Đầu Khám Phá Chiến Dịch',
                  icon: Icons.play_arrow_rounded,
                  variant: DongSonButtonVariant.primaryCinnabar,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang khởi tạo luồng khám phá Bạch Đằng 938!')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                DongSonButton(
                  label: 'Xem Lại Sa Bàn & Bằng Chứng Khảo Cổ',
                  icon: Icons.map_outlined,
                  variant: DongSonButtonVariant.secondaryParchment,
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                DongSonButton(
                  label: 'Mở Khóa Cổ Vật Danh Vọng',
                  icon: Icons.stars_rounded,
                  variant: DongSonButtonVariant.imperialGold,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChip(String name, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DauVietColors.outlineVariant, width: 1),
        boxShadow: DauVietColors.heritageShadow,
      ),
      child: Text(
        name,
        style: DauVietTypography.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
