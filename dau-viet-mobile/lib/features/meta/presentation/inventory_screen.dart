import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-27: Túi Đồ & Quản Lý Cổ Vật Sở Hữu (Backpack / Inventory Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'all';
  String _selectedItemId = 'art_thuyen_chien';

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'art_thuyen_chien',
      'name': 'Mô hình Chiến thuyền Bạch Đằng',
      'category': 'artifacts',
      'categoryLabel': 'Cổ Vật',
      'rarity': 'Bảo vật Quốc gia',
      'rarityColor': DauVietColors.imperialGold,
      'assetImage': 'assets/items/decor_cau_kieu.png',
      'icon': Icons.directions_boat_filled_rounded,
      'color': DauVietColors.cinnabarRed,
      'desc':
          'Thuyền chiến đáy nông cơ động thế kỷ X, báu vật mở khóa sau đại thắng Bạch Đằng 938.',
      'actionRoute': '/rewards/artifact/art_thuyen_chien_938',
      'actionLabel': 'XEM CHI TIẾT CỔ VẬT (M-21) ›',
    },
    {
      'id': 'art_coc_yen_giang',
      'name': 'Cọc Gỗ Lim Yên Giang',
      'category': 'artifacts',
      'categoryLabel': 'Cổ Vật',
      'rarity': 'Cổ vật Hiếm',
      'rarityColor': DauVietColors.riverBlue,
      'assetImage': 'assets/badges/badge_trace_4_archaeology.png',
      'icon': Icons.architecture_rounded,
      'color': DauVietColors.riverBlue,
      'desc':
          'Hiện vật cọc gỗ lim vót nhọn bịt sắt, định tuổi Carbon C-14 trùng khớp năm 938.',
      'actionRoute': null,
      'actionLabel': 'CỔ VẬT ĐANG TRƯNG BÀY',
    },
    {
      'id': 'bld_thuy_ta_sen',
      'name': 'Thủy Tạ Sen Cổ Truyền',
      'category': 'island',
      'categoryLabel': 'Công Trình',
      'rarity': 'Kiến trúc Di sản',
      'rarityColor': DauVietColors.natureGreen,
      'assetImage': 'assets/items/decor_ho_sen.png',
      'icon': Icons.park_rounded,
      'color': DauVietColors.natureGreen,
      'desc':
          'Công trình thủy tạ hoa sen thanh tịnh, dùng đặt lên ô cảnh quan của Đảo Di Sản.',
      'actionRoute': '/island',
      'actionLabel': 'ĐẶT LÊN ĐẢO DI SẢN (M-22) ›',
    },
    {
      'id': 'bld_dinh_lang',
      'name': 'Đình Làng Cổ Ngô Quyền',
      'category': 'island',
      'categoryLabel': 'Công Trình',
      'rarity': 'Kiến trúc Cổ',
      'rarityColor': DauVietColors.cinnabarRed,
      'assetImage': 'assets/items/decor_nha_tranh.png',
      'icon': Icons.account_balance_rounded,
      'color': DauVietColors.cinnabarRed,
      'desc':
          'Công trình đình làng kiến trúc thời Ngô trang nghiêm, lưu dấu truyền thống ngàn năm.',
      'actionRoute': '/island',
      'actionLabel': 'ĐẶT LÊN ĐẢO DI SẢN (M-22) ›',
    },
    {
      'id': 'tkn_lenh_bai_ngo_vuong',
      'name': 'Lệnh Bài Tiền Ngô Vương',
      'category': 'tokens',
      'categoryLabel': 'Lệnh Bài',
      'rarity': 'Hoàng Gia',
      'rarityColor': DauVietColors.cinnabarRed,
      'assetImage': 'assets/badges/badge_trace_3_tactics.png',
      'icon': Icons.shield_moon_rounded,
      'color': DauVietColors.cinnabarRed,
      'desc':
          'Lệnh bài xuất quân Tiền Ngô Vương trao tặng Sĩ Tử thấu triệt binh lược.',
      'actionRoute': null,
      'actionLabel': 'LỆNH BÀI DANH DỰ',
    },
    {
      'id': 'it_tra_sen',
      'name': 'Trà Sen Tây Hồ Cổ Truyền',
      'category': 'tokens',
      'categoryLabel': 'Dược Phẩm',
      'rarity': 'Thảo Dược',
      'rarityColor': DauVietColors.natureGreen,
      'assetImage': 'assets/items/energy_tra_sen.png',
      'icon': Icons.local_cafe_rounded,
      'color': DauVietColors.imperialGold,
      'desc':
          'Trà sen ướp hương thơm ngát của Viện Thái Y giúp tăng tốc hồi phục thể lực.',
      'actionRoute': '/energy',
      'actionLabel': 'ĐẾN VIỆN THÁI Y (M-28) ›',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == 'all'
        ? _items
        : _items.where((i) => i['category'] == _selectedCategory).toList();

    final selectedItem = _items.firstWhere(
      (i) => i['id'] == _selectedItemId,
      orElse: () => _items.first,
    );

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3. Thanh Bộ Lọc Danh Mục (Category Tabs)
                      _buildCategoryFilters(),
                      const SizedBox(height: 14),

                      // 4. Lưới Vật Phẩm Sở Hữu (Inventory Grid)
                      _buildInventoryGrid(filteredItems),
                      const SizedBox(height: 16),

                      // 5. Thẻ Soi Chi Tiết Vật Phẩm Đang Chọn
                      _buildItemInspectorCard(selectedItem, context),
                      const SizedBox(height: 20),

                      // 6. Cặp Nút Hành Động
                      DongSonButton(
                        label: 'QUAY LẠI ĐẢO DI SẢN (M-22) ›',
                        icon: Icons.landscape_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          context.go('/island');
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
                context.go('/island');
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
                        'KHO DI SẢN',
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
                        'TÚI ĐỒ SĨ TỬ',
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
                  '${_items.length}/50 Cổ vật & Vật phẩm sở hữu',
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

  // Bộ lọc danh mục
  Widget _buildCategoryFilters() {
    final categories = [
      {'key': 'all', 'label': 'Tất Cả (${_items.length})'},
      {
        'key': 'artifacts',
        'label':
            'Cổ Vật (${_items.where((i) => i['category'] == 'artifacts').length})',
      },
      {
        'key': 'island',
        'label':
            'Công Trình (${_items.where((i) => i['category'] == 'island').length})',
      },
      {
        'key': 'tokens',
        'label':
            'Vật Phẩm (${_items.where((i) => i['category'] == 'tokens').length})',
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat['key']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DauVietColors.cinnabarRed
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.outlineVariant,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  cat['label']!,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : DauVietColors.inkText,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Lưới vật phẩm
  Widget _buildInventoryGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItemId == item['id'];

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedItemId = item['id'] as String;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFBF4E4)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? DauVietColors.cinnabarRed
                    : (item['rarityColor'] as Color).withValues(alpha: 0.5),
                width: isSelected ? 2.0 : 1.2,
              ),
              boxShadow: isSelected ? DauVietColors.heritageShadow : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (item['rarityColor'] as Color).withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item['categoryLabel'] as String,
                        style: TextStyle(
                          color: item['rarityColor'] as Color,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: DauVietColors.cinnabarRed,
                        size: 16,
                      ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (item['rarityColor'] as Color).withValues(
                          alpha: 0.4,
                        ),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: item['assetImage'] != null
                          ? Image.asset(
                              item['assetImage'] as String,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    item['icon'] as IconData,
                                    color: item['color'] as Color,
                                    size: 26,
                                  ),
                            )
                          : Icon(
                              item['icon'] as IconData,
                              color: item['color'] as Color,
                              size: 26,
                            ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item['name'] as String,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkText,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Thẻ soi chi tiết vật phẩm đang chọn
  Widget _buildItemInspectorCard(
    Map<String, dynamic> item,
    BuildContext context,
  ) {
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
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item['rarityColor'] as Color,
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
                child: item['assetImage'] != null
                    ? Image.asset(
                        item['assetImage'] as String,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            color: item['color'] as Color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: item['color'] as Color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: Colors.white,
                          size: 24,
                        ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: DauVietColors.cinnabarRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['rarity'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['name'] as String,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 14.5,
                        color: DauVietColors.inkText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['desc'] as String,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.4,
              fontSize: 11.5,
            ),
          ),
          if (item['actionRoute'] != null) ...[
            const SizedBox(height: 12),
            DongSonButton(
              label: item['actionLabel'] as String,
              icon: Icons.visibility_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 44,
              onPressed: () {
                context.go(item['actionRoute'] as String);
              },
            ),
          ],
        ],
      ),
    );
  }
}
