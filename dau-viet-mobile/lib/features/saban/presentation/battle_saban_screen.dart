import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/main_bottom_nav.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../mock/data/mock_saban_data.dart';
import '../../../mock/models/saban_models.dart';
import '../../../mock/models/timeline_models.dart';
import '../../events/data/events_providers.dart';

/// Màn hình M-06: Sa Bàn Chiến Thuật & Bản Đồ Thủy Chiến Sông Bạch Đằng (Battle Saban Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & ART_DIRECTION.md
class BattleSabanScreen extends ConsumerStatefulWidget {
  const BattleSabanScreen({super.key});

  @override
  ConsumerState<BattleSabanScreen> createState() => _BattleSabanScreenState();
}

class _BattleSabanScreenState extends ConsumerState<BattleSabanScreen> {
  int _currentPhaseIndex = 0;
  SabanMarkerModel? _selectedMarker;

  SabanPhaseModel get _currentPhase => MockSabanData.phases[_currentPhaseIndex];

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
              // 1. Top Bar Tiêu Đề Sa Bàn
              _buildTopBar(context),

              // 2. Nội dung cuộn chính
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 3. Khung Sa Bàn Địa Hình Tương Tác
                      _buildInteractiveSabanCanvas(),
                      const SizedBox(height: 16),

                      // 4. Bộ Điều Khiển Tiến Trình Thủy Triều (Tide Controller)
                      _buildTidePhaseSelector(),
                      const SizedBox(height: 16),

                      // 5. Thẻ Thuyết Minh Diễn Biến Chiến Thuật
                      _buildTacticalNarrationCard(),
                      const SizedBox(height: 16),

                      // 6. Hộp Chú Giải Sa Bàn Quân Sự (Legend)
                      _buildSabanLegend(),
                      const SizedBox(height: 20),

                      // 7. Nút Hành Động Liên Kết
                      Row(
                        children: [
                          Expanded(
                            child: DongSonButton(
                              label: 'Xem Chi Tiết Chiến Dịch',
                              icon: Icons.auto_stories_rounded,
                              variant: DongSonButtonVariant.primaryCinnabar,
                              height: 48,
                              onPressed: () {
                                final events = ref.read(eventsListProvider).value?.milestones ?? [];
                                final bd = events.cast<TimelineMilestoneModel?>().firstWhere(
                                  (e) => e != null && (e.id.contains('000000000001') || e.title.toLowerCase().contains('bạch đằng')),
                                  orElse: () => null,
                                );
                                final targetId = bd?.id ?? (ApiConfig.useMock ? 'evt_bach_dang_938' : '00000000-0000-0000-0000-000000000001');
                                context.go('/campaign/$targetId');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          DongSonButton(
                            label: 'Bàn Học',
                            icon: Icons.home_outlined,
                            variant: DongSonButtonVariant.secondaryParchment,
                            height: 48,
                            onPressed: () {
                              context.go('/dashboard');
                            },
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
      bottomNavigationBar: const MainBottomNav(),
    );
  }

  // Header thanh đỉnh trang
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
                context.go('/timeline');
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
                        'QUÂN SỰ HỌC',
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
                        'SA BÀN THỦY CHIẾN BẠCH ĐẰNG',
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
                  'Diễn biến tương tác theo con nước triều năm 938',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // La bàn Đông Sơn 8 hướng
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.parchmentContainer,
              border: Border.all(color: DauVietColors.imperialGold, width: 1.5),
            ),
            child: const Icon(
              Icons.explore_outlined,
              color: DauVietColors.cinnabarRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // Khung mô phỏng Sa bàn sông Bạch Đằng dạng Thủy Mặc
  Widget _buildInteractiveSabanCanvas() {
    final waterLevel = _currentPhase.waterLevelPercent;
    final isStakesExposed = waterLevel < 0.4;

    return ParchmentCard(
      backgroundColor: const Color(0xFFE8DCC4),
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 240,
          child: Stack(
            children: [
              // Ảnh nền Sa Bàn Thủy Chiến Bạch Đằng 938
              Positioned.fill(
                child: Image.asset(
                  'assets/images/dv_MAP_ngoquyen_bachdang-base_v01.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),

              // Nền sông nước thủy mặc Bạch Đằng phủ theo chu kỳ nước
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF3B5B66).withValues(alpha: 0.45),
                      Color.lerp(
                        const Color(0xFF4A7C8C),
                        const Color(0xFF75979C),
                        1.0 - waterLevel,
                      )!.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),

              // Bờ sông tả ngạn và hữu ngạn (Rừng sú vẹt & bãi phù sa)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF485834).withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'Rừng sú vẹt mai phục',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: const Color(0xFFD6DEC5),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 45,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF485834).withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      bottomLeft: Radius.circular(30),
                    ),
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        'Dãy núi Tràng Kênh',
                        style: DauVietTypography.labelSmall.copyWith(
                          color: const Color(0xFFD6DEC5),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bãi cọc ngầm Yên Giang (Hình ảnh minh họa tương tác)
              Positioned(
                left: 70,
                right: 65,
                top: 120,
                height: 55,
                child: Container(
                  decoration: BoxDecoration(
                    color: isStakesExposed
                        ? const Color(0xFF5A3825).withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isStakesExposed
                          ? DauVietColors.imperialGold
                          : Colors.white24,
                      width: isStakesExposed ? 1.5 : 0.8,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        7,
                        (i) => Icon(
                          isStakesExposed
                              ? Icons.change_history_rounded
                              : Icons.water_drop_outlined,
                          size: isStakesExposed ? 18 : 12,
                          color: isStakesExposed
                              ? DauVietColors.imperialGold
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Huy hiệu chỉ dẫn Cửa biển và Thượng lưu
              Positioned(
                top: 8,
                left: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '▲ Thượng lưu sông (Bản doanh Ngô Quyền)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 8,
                left: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '▼ Cửa biển Nam Triệu (Đường quân giặc tiến)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Các điểm Marker tương tác trên sa bàn
              ..._currentPhase.activeMarkers.map((marker) {
                final isSelected = _selectedMarker?.id == marker.id;
                return Positioned(
                  left: 300 * marker.xPercent,
                  top: 200 * marker.yPercent,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMarker = marker;
                      });
                      _showMarkerDetailSheet(marker);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getMarkerColor(marker.markerType),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : DauVietColors.imperialGold,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                        boxShadow: DauVietColors.heritageShadow,
                      ),
                      child: Icon(
                        _getMarkerIcon(marker.markerType),
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Bộ chọn 3 nhịp thủy triều (Time Step Selector)
  Widget _buildTidePhaseSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'CHU KỲ THỦY TRIỀU CHIẾN THUẬT',
                style: DauVietTypography.labelMedium.copyWith(
                  color: DauVietColors.inkMuted,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Nhấn để đổi con nước',
              style: DauVietTypography.labelSmall.copyWith(
                color: DauVietColors.cinnabarRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(MockSabanData.phases.length, (index) {
            final isSelected = _currentPhaseIndex == index;
            final labels = [
              '1. Giờ Tỵ\n(Triều dâng)',
              '2. Giờ Ngọ\n(Đỉnh triều)',
              '3. Giờ Mùi\n(Triều rút cạn)',
            ];

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < MockSabanData.phases.length - 1 ? 6 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentPhaseIndex = index;
                      _selectedMarker = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DauVietColors.cinnabarRed
                          : DauVietColors.parchmentContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? DauVietColors.imperialGold
                            : DauVietColors.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? DauVietColors.heritageShadow
                          : null,
                    ),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: DauVietTypography.labelSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : DauVietColors.inkText,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // Thẻ thuyết minh chiến thuật theo thời gian thực
  Widget _buildTacticalNarrationCard() {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DauVietColors.cinnabarRed,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _currentPhase.timeLabel,
                  style: DauVietTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentPhase.tideStatus,
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.natureGreen,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _currentPhase.tacticalAction,
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 16,
              color: DauVietColors.cinnabarRed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentPhase.description,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Hộp chú giải ký hiệu quân sự
  Widget _buildSabanLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHÚ GIẢI KÝ HIỆU SA BÀN',
            style: DauVietTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: DauVietColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                Icons.change_history_rounded,
                const Color(0xFF8B5A2B),
                'Bãi cọc ngầm',
              ),
              _buildLegendItem(
                Icons.sailing_rounded,
                DauVietColors.cinnabarRed,
                'Quân ta (Tiền Ngô)',
              ),
              _buildLegendItem(
                Icons.dangerous_rounded,
                const Color(0xFF2C3E50),
                'Quân Nam Hán',
              ),
              _buildLegendItem(
                Icons.shield_outlined,
                DauVietColors.natureGreen,
                'Phục binh bờ sông',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: DauVietTypography.labelSmall.copyWith(
            fontSize: 10,
            color: DauVietColors.inkText,
          ),
        ),
      ],
    );
  }

  void _showMarkerDetailSheet(SabanMarkerModel marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DauVietColors.parchmentSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getMarkerIcon(marker.markerType),
                    color: _getMarkerColor(marker.markerType),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      marker.title,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 17,
                        color: DauVietColors.cinnabarRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                marker.description,
                style: DauVietTypography.bodyMedium.copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              DongSonButton(
                label: 'Đóng chú giải',
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

  Color _getMarkerColor(String type) {
    switch (type) {
      case 'enemy':
        return const Color(0xFF2C3E50);
      case 'ambush':
        return DauVietColors.natureGreen;
      case 'stake_field':
        return const Color(0xFF8B5A2B);
      case 'command':
      default:
        return DauVietColors.cinnabarRed;
    }
  }

  IconData _getMarkerIcon(String type) {
    switch (type) {
      case 'enemy':
        return Icons.dangerous_rounded;
      case 'ambush':
        return Icons.shield_outlined;
      case 'stake_field':
        return Icons.change_history_rounded;
      case 'command':
      default:
        return Icons.sailing_rounded;
    }
  }
}
