import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-28: Quản Lý Năng Lượng & Viện Thái Y (Energy Management Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & UI_COMPONENT_SPEC.md
class EnergyManagementScreen extends StatefulWidget {
  const EnergyManagementScreen({super.key});

  @override
  State<EnergyManagementScreen> createState() => _EnergyManagementScreenState();
}

class _EnergyManagementScreenState extends State<EnergyManagementScreen> {
  int _currentEnergy = 80;
  final int _maxEnergy = 100;

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
              Color(0xFFF2F8F4), // Xanh lá thảo dược viện thái y
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
                      // 3. Khung Thước Đo Năng Lượng Hero
                      _buildEnergyGaugeHero(),
                      const SizedBox(height: 16),

                      // 4. Các Liệu Pháp Phục Hồi Viện Thái Y
                      _buildRemediesList(),
                      const SizedBox(height: 16),

                      // 5. Lời Dặn Của Ngự Y
                      _buildPhysicianAdviceCard(),
                      const SizedBox(height: 20),

                      // 6. Cặp Nút Hành Động
                      DongSonButton(
                        label: 'HỒI PHỤC NGAY QUA CÂU ĐỐ SỬ HỌC ›',
                        icon: Icons.quiz_rounded,
                        variant: DongSonButtonVariant.primaryCinnabar,
                        height: 52,
                        onPressed: () {
                          setState(() {
                            _currentEnergy = (_currentEnergy + 20).clamp(
                              0,
                              _maxEnergy,
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã phục hồi +20 Thể Lực qua Tĩnh Tâm Ôn Luyện!',
                              ),
                              backgroundColor: DauVietColors.natureGreen,
                            ),
                          );
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
                        color: DauVietColors.natureGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'VIỆN THÁI Y',
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
                        'QUẢN LÝ THỂ LỰC',
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
                  'Dưỡng Tâm • Phục Hồi Sinh Lực Sĩ Tử',
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

  // Khung thước đo năng lượng Hero
  Widget _buildEnergyGaugeHero() {
    final double percent = _currentEnergy / _maxEnergy;

    return ParchmentCard(
      backgroundColor: const Color(0xFFFBF4E4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: DauVietColors.cinnabarRed,
                size: 24,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'THỂ LỰC HIỆN TẠI',
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.cinnabarRed,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_currentEnergy / $_maxEnergy',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: DauVietColors.inkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Thanh tiến trình sinh lực
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 14,
              backgroundColor: DauVietColors.outlineVariant.withValues(
                alpha: 0.4,
              ),
              valueColor: const AlwaysStoppedAnimation<Color>(
                DauVietColors.natureGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.timelapse_rounded,
                size: 16,
                color: DauVietColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '+1 Thể lực / 30 phút',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: DauVietColors.inkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đủ học 4 bài (-20/bài)',
                style: DauVietTypography.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DauVietColors.natureGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Danh sách các liệu pháp hồi phục
  Widget _buildRemediesList() {
    final remedies = [
      {
        'title': 'Tĩnh Tâm Ôn Luyện (Nước Vối Miễn Phí)',
        'desc':
            'Bát nước vối ấm lành tính giúp sĩ tử giải nhiệt, thư giãn gân cốt.',
        'reward': '+20 Thể Lực',
        'cost': 'Miễn phí',
        'assetImage': 'assets/items/energy_nuoc_voi.png',
        'icon': Icons.psychology_rounded,
        'color': DauVietColors.natureGreen,
        'onTap': () {
          setState(() {
            _currentEnergy = (_currentEnergy + 20).clamp(0, _maxEnergy);
          });
        },
      },
      {
        'title': 'Trà Sen Tây Hồ (Dưỡng Thần)',
        'desc': 'Trà sen ướp hương thơm ngát giúp tinh thần minh mẫn tức thì.',
        'reward': '+50 Thể Lực',
        'cost': '50 Điểm Sử Ký',
        'assetImage': 'assets/items/energy_tra_sen.png',
        'icon': Icons.local_cafe_rounded,
        'color': DauVietColors.imperialGold,
        'onTap': () {
          setState(() {
            _currentEnergy = (_currentEnergy + 50).clamp(0, _maxEnergy);
          });
        },
      },
      {
        'title': 'Nấm Linh Chi Ngự Dược',
        'desc': 'Thảo dược đại bổ triều đình bồi bổ nguyên khí, chống mỏi mệt.',
        'reward': '+80 Thể Lực',
        'cost': '80 Đồng Cổ',
        'assetImage': 'assets/items/energy_linh_chi.png',
        'icon': Icons.spa_rounded,
        'color': const Color(0xFFC05621),
        'onTap': () {
          setState(() {
            _currentEnergy = (_currentEnergy + 80).clamp(0, _maxEnergy);
          });
        },
      },
      {
        'title': 'Sâm Ngọc Linh Hoàng Gia',
        'desc': 'Bảo vật sâm rừng nghìn năm phục hồi 100% sinh lực tức thì.',
        'reward': 'Hồi Đầy 100%',
        'cost': '120 Đồng Cổ',
        'assetImage': 'assets/items/energy_sam_ngoc_linh.png',
        'icon': Icons.stars_rounded,
        'color': DauVietColors.cinnabarRed,
        'onTap': () {
          setState(() {
            _currentEnergy = _maxEnergy;
          });
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medical_services_outlined,
              color: DauVietColors.natureGreen,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'LIỆU PHÁP VIỆN THÁI Y:',
              style: DauVietTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkMuted,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...remedies.map((rem) {
          return InkWell(
            onTap: rem['onTap'] as VoidCallback,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (rem['color'] as Color).withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (rem['color'] as Color).withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Image.asset(
                      rem['assetImage'] as String,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          color: (rem['color'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          rem['icon'] as IconData,
                          color: rem['color'] as Color,
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
                        Text(
                          rem['title'] as String,
                          style: DauVietTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DauVietColors.inkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rem['desc'] as String,
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 10.5,
                            color: DauVietColors.inkMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        rem['reward'] as String,
                        style: DauVietTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: rem['color'] as Color,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        rem['cost'] as String,
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 10,
                          color: DauVietColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // Khung lời dặn của Ngự Y
  Widget _buildPhysicianAdviceCard() {
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
                Icons.favorite_rounded,
                color: DauVietColors.cinnabarRed,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'LỜI DẶN DƯỠNG SINH VIỆN THÁI Y:',
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
            '“Học sử cần tinh tấn nhưng dưỡng thần cần điều hòa. Nghỉ ngơi tĩnh tâm giữa các đợt khảo cứu để tâm trí luôn sáng suốt, hào khí luôn tràn đầy.”',
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
