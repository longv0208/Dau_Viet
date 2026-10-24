import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-22: Bản Đồ Đảo Di Sản Cá Nhân 2.5D (Heritage Island Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class HeritageIslandScreen extends StatefulWidget {
  const HeritageIslandScreen({super.key});

  @override
  State<HeritageIslandScreen> createState() => _HeritageIslandScreenState();
}

class _HeritageIslandScreenState extends State<HeritageIslandScreen> {
  int _selectedSlot = 1;

  final List<Map<String, dynamic>> _islandSlots = [
    {
      'id': 1,
      'name': 'Đình Làng Cổ Truyền',
      'category': 'Điện Chính',
      'icon': Icons.account_balance_rounded,
      'assetImage': 'assets/items/decor_nha_tranh.png',
      'color': DauVietColors.cinnabarRed,
      'status': 'Đã hoàn thành',
      'desc':
          'Kiến trúc gỗ lim truyền thống thời Ngô, nơi phụng thờ anh linh các bậc tiền nhân.',
    },
    {
      'id': 2,
      'name': 'Bến Thuyền Bạch Đằng',
      'category': 'Cảng Thủy Quân',
      'icon': Icons.directions_boat_filled_rounded,
      'assetImage': 'assets/items/decor_cau_kieu.png',
      'color': DauVietColors.riverBlue,
      'status': 'Chiến thuyền đã neo đậu',
      'desc':
          'Nơi neo đậu Mô hình Chiến Thuyền Độc Mộc Thế Kỷ X vừa mở khóa từ chiến dịch.',
    },
    {
      'id': 3,
      'name': 'Thủy Tạ Sen & Giếng Cổ',
      'category': 'Cảnh Quan Di Sản',
      'icon': Icons.park_rounded,
      'assetImage': 'assets/items/decor_ho_sen.png',
      'color': DauVietColors.natureGreen,
      'status': 'Sẵn sàng đặt',
      'desc':
          'Ô đất cảnh quan, dùng Điểm Sử Ký trong Túi Đồ để đặt công trình kiến trúc cổ.',
    },
    {
      'id': 4,
      'name': 'Cây Đa Di Sản & Vườn Trúc',
      'category': 'Khu Mở Rộng',
      'icon': Icons.forest_rounded,
      'assetImage': 'assets/items/decor_cay_da.png',
      'color': DauVietColors.imperialGold,
      'status': 'Mở khóa ở Đảo Cấp 2',
      'desc':
          'Cây đa cổ thụ che bóng mát cho di sản đảo, kết nối cội nguồn dòng dõi Tiên Rồng.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final selectedSlotData = _islandSlots.firstWhere(
      (s) => s['id'] == _selectedSlot,
    );

    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEBF5FA), // Mặt nước biển xanh nhạt
              DauVietColors.parchmentSurface,
              Color(0xFFFAF2E4),
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
                      // 3. Khung Mô Phỏng Bản Đồ Đảo Di Sản 2.5D
                      _buildIslandMapCanvas(),
                      const SizedBox(height: 14),

                      // 4. Thanh Chỉ Số Kinh Tế Đảo
                      _buildIslandEconomyBar(),
                      const SizedBox(height: 14),

                      // 5. Chi Tiết Vị Trí Slot Đang Chọn
                      _buildSlotDetailCard(selectedSlotData),
                      const SizedBox(height: 16),

                      // 6. Cụm Nút Hành Động Xây Dựng
                      DongSonButton(
                        label: 'MỞ TÚI ĐỒ & KHO TRANG TRÍ (M-27) ›',
                        icon: Icons.backpack_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/inventory');
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DongSonButton(
                              label: 'VIỆN THÁI Y (M-28)',
                              icon: Icons.spa_rounded,
                              variant: DongSonButtonVariant.secondaryParchment,
                              height: 48,
                              onPressed: () {
                                context.go('/energy');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DongSonButton(
                              label: 'VỀ BÀN HỌC (M-03)',
                              icon: Icons.home_rounded,
                              variant: DongSonButtonVariant.secondaryParchment,
                              height: 48,
                              onPressed: () {
                                context.go('/dashboard');
                              },
                            ),
                          ),
                        ],
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
                        'CẤP 1',
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
                        'ĐẢO DI SẢN CÁ NHÂN',
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
                  'Hòn Đảo Tân Sinh • Vịnh Bạch Đằng',
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

  // Khung bản đồ đảo di sản 2.5D
  Widget _buildIslandMapCanvas() {
    return Container(
      height: 270,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD4EBF8), // Nước biển ngọc bích
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DauVietColors.imperialGold, width: 2),
        boxShadow: DauVietColors.heritageShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ảnh nền Đảo Di Sản 2.5D chân thực
            Positioned.fill(
              child: Image.asset(
                'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: const Color(0xFFE2D6B5)),
              ),
            ),
            // Lớp phủ tinh tế bảo đảm tương phản các điểm chạm
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),

            // Lưới các vị trí Slot công trình tương tác 2.5D
            // Slot 1: Đình Làng Cổ (Trung tâm đảo)
            Positioned(
              top: 75,
              child: _buildInteractiveSlotMarker(
                slotId: 1,
                assetImage: 'assets/items/decor_nha_tranh.png',
                icon: Icons.account_balance_rounded,
                label: 'Đình Cổ',
                color: DauVietColors.cinnabarRed,
              ),
            ),

            // Slot 2: Bến Thuyền (Bên phải hướng sông nước)
            Positioned(
              top: 135,
              right: 24,
              child: _buildInteractiveSlotMarker(
                slotId: 2,
                assetImage: 'assets/items/decor_cau_kieu.png',
                icon: Icons.directions_boat_filled_rounded,
                label: 'Bến Thuyền',
                color: DauVietColors.riverBlue,
              ),
            ),

            // Slot 3: Thủy Tạ Sen (Bên trái)
            Positioned(
              top: 135,
              left: 24,
              child: _buildInteractiveSlotMarker(
                slotId: 3,
                assetImage: 'assets/items/decor_ho_sen.png',
                icon: Icons.park_rounded,
                label: 'Thủy Tạ Sen',
                color: DauVietColors.natureGreen,
              ),
            ),

            // Slot 4: Cây Đa Di Sản (Phía Bắc)
            Positioned(
              top: 14,
              child: _buildInteractiveSlotMarker(
                slotId: 4,
                assetImage: 'assets/items/decor_cay_da.png',
                icon: Icons.forest_rounded,
                label: 'Cây Đa Cổ',
                color: DauVietColors.imperialGold,
              ),
            ),

            // Nhãn tên đảo góc dưới
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DauVietColors.imperialGold.withValues(alpha: 0.6),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  'BẢN ĐỒ ĐẢO DI SẢN (CHẠM VÀO ĐỂ ĐẶT CÔNG TRÌNH)',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkText,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nút chốt vị trí Slot công trình trên bản đồ
  Widget _buildInteractiveSlotMarker({
    required int slotId,
    required String assetImage,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedSlot == slotId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSlot = slotId;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 52 : 44,
            height: isSelected ? 52 : 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.95),
              border: Border.all(
                color: isSelected
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.imperialGold,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? DauVietColors.cinnabarRed : Colors.black)
                      .withValues(alpha: 0.35),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                assetImage,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: color,
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSelected ? 24 : 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? DauVietColors.cinnabarRed
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? DauVietColors.imperialGold
                    : DauVietColors.outlineVariant,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              style: DauVietTypography.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : DauVietColors.inkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thanh chỉ số kinh tế đảo
  Widget _buildIslandEconomyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildEconomyItem(
            icon: Icons.history_edu_rounded,
            color: DauVietColors.imperialGold,
            value: '500',
            label: 'Điểm Sử Ký',
          ),
          Container(width: 1, height: 28, color: DauVietColors.outlineVariant),
          _buildEconomyItem(
            icon: Icons.monetization_on_rounded,
            color: DauVietColors.cinnabarRed,
            value: '50',
            label: 'Đồng Cổ',
          ),
          Container(width: 1, height: 28, color: DauVietColors.outlineVariant),
          _buildEconomyItem(
            icon: Icons.bolt_rounded,
            color: DauVietColors.natureGreen,
            value: '100/100',
            label: 'Thể Lực',
          ),
        ],
      ),
    );
  }

  Widget _buildEconomyItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: DauVietTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
                fontSize: 12.5,
              ),
            ),
            Text(
              label,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 9.5,
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Thẻ chi tiết vị trí đang chọn
  Widget _buildSlotDetailCard(Map<String, dynamic> slot) {
    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DauVietColors.imperialGold,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Image.asset(
                  slot['assetImage'] as String,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: slot['color'] as Color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      slot['icon'] as IconData,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                            slot['category'] as String,
                            style: DauVietTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            slot['status'] as String,
                            style: DauVietTypography.bodySmall.copyWith(
                              color: DauVietColors.natureGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      slot['name'] as String,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 15,
                        color: DauVietColors.inkText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            slot['desc'] as String,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.35,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
