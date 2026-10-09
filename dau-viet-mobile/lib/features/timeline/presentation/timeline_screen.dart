import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../mock/data/mock_timeline_data.dart';
import '../../../mock/models/timeline_models.dart';

/// Màn hình M-04: Dòng Thời Gian Lịch Sử Việt Nam (Historical Timeline Screen)
/// Khớp 100% với đặc tả trong MOBILE_SCREEN_DESIGN.md & ART_DIRECTION.md
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String _selectedEra = 'Tất cả';

  List<TimelineMilestoneModel> get _filteredMilestones {
    if (_selectedEra == 'Tất cả') {
      return MockTimelineData.milestones;
    }
    return MockTimelineData.milestones
        .where((m) => m.era == _selectedEra)
        .toList();
  }

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
              DauVietColors.parchmentSurface,
              Color(0xFFFAF2E4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar Tiêu Đề Cuốn Thư
              _buildTopBar(context),

              // 2. Bộ lọc thời kỳ ngang (Era Filter Chips)
              _buildEraFilters(),

              // 3. Trục thời gian dọc (Vertical Timeline)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  itemCount: _filteredMilestones.length,
                  itemBuilder: (context, index) {
                    final item = _filteredMilestones[index];
                    final isLast = index == _filteredMilestones.length - 1;
                    return _buildTimelineItem(item, isLast);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // Header thanh điều hướng đỉnh trang
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'DẤU VIỆT',
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
                        'DÒNG THỜI GIAN LỊCH SỬ',
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
                  'Hành trình hàng ngàn năm dựng nước & giữ nước',
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: DauVietColors.cinnabarRed),
            tooltip: 'Sa bàn chiến thuật',
            onPressed: () {
              context.go('/saban');
            },
          ),
        ],
      ),
    );
  }

  // Bộ lọc danh mục thời kỳ lịch sử
  Widget _buildEraFilters() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: MockTimelineData.eras.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final era = MockTimelineData.eras[index];
          final isSelected = era == _selectedEra;
          return ChoiceChip(
            label: Text(
              era,
              style: DauVietTypography.labelSmall.copyWith(
                color: isSelected ? Colors.white : DauVietColors.inkText,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            selected: isSelected,
            selectedColor: DauVietColors.cinnabarRed,
            backgroundColor: DauVietColors.parchmentContainer,
            side: BorderSide(
              color: isSelected ? DauVietColors.cinnabarRed : DauVietColors.outlineVariant,
              width: 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedEra = era;
                });
              }
            },
          );
        },
      ),
    );
  }

  // Một mốc trên Trục Thời Gian Lịch Sử
  Widget _buildTimelineItem(TimelineMilestoneModel item, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trục son và điểm nút (Node)
          SizedBox(
            width: 38,
            child: Column(
              children: [
                // Điểm nút tròn
                Container(
                  width: item.isActive ? 28 : 20,
                  height: item.isActive ? 28 : 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isActive ? DauVietColors.cinnabarRed : DauVietColors.parchmentContainer,
                    border: Border.all(
                      color: item.isActive ? DauVietColors.imperialGold : DauVietColors.cinnabarRed,
                      width: item.isActive ? 3 : 2,
                    ),
                    boxShadow: item.isActive ? DauVietColors.heritageShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: item.isActive
                      ? const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white)
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DauVietColors.cinnabarRed,
                          ),
                        ),
                ),
                // Đường gióng trục dọc
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      color: DauVietColors.imperialGold.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Nội dung thẻ niên biểu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ParchmentCard(
                backgroundColor: item.isActive
                    ? DauVietColors.parchmentContainer
                    : Colors.white.withValues(alpha: 0.8),
                borderColor: item.isActive ? DauVietColors.imperialGold : DauVietColors.outlineVariant,
                borderWidth: item.isActive ? 2.0 : 1.0,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mốc năm & Huy hiệu
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.isActive
                                ? DauVietColors.cinnabarRed
                                : DauVietColors.imperialGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.yearLabel,
                            style: DauVietTypography.labelSmall.copyWith(
                              color: item.isActive ? Colors.white : DauVietColors.inkText,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (item.badgeText != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isActive
                                    ? DauVietColors.imperialGold.withValues(alpha: 0.25)
                                    : DauVietColors.outlineVariant.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.badgeText!,
                                style: DauVietTypography.labelSmall.copyWith(
                                  color: item.isActive ? DauVietColors.cinnabarRed : DauVietColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Tiêu đề sự kiện
                    Text(
                      item.title,
                      style: DauVietTypography.headlineMedium.copyWith(
                        fontSize: 17,
                        color: item.isActive ? DauVietColors.cinnabarRed : DauVietColors.inkText,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Phụ đề nhân vật / bối cảnh
                    Text(
                      item.subtitle,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tóm lược ý nghĩa
                    Text(
                      item.description,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkText.withValues(alpha: 0.9),
                        height: 1.45,
                      ),
                    ),

                    // Nếu là mốc Active (Bạch Đằng 938): Hiện các nút CTA khám phá
                    if (item.isActive && item.eventId != null) ...[
                      const SizedBox(height: 16),
                      const Divider(color: DauVietColors.outlineVariant, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DongSonButton(
                              label: 'Khám phá Chiến dịch',
                              icon: Icons.explore_rounded,
                              variant: DongSonButtonVariant.primaryCinnabar,
                              height: 44,
                              onPressed: () {
                                context.go('/campaign/${item.eventId}');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          DongSonButton(
                            label: 'Sa Bàn',
                            icon: Icons.shield_outlined,
                            variant: DongSonButtonVariant.secondaryParchment,
                            height: 44,
                            onPressed: () {
                              context.go('/saban');
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thanh điều hướng Bottom Bar 5 Tab di sản
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          top: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        boxShadow: DauVietColors.heritageShadow,
      ),
      child: BottomNavigationBar(
        currentIndex: 1, // Tab Lược Sử đang chọn
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DauVietColors.cinnabarRed,
        unselectedItemColor: DauVietColors.inkMuted,
        selectedLabelStyle: DauVietTypography.labelSmall.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: DauVietTypography.labelSmall,
        onTap: (index) {
          if (index == 0) {
            context.go('/dashboard');
          } else if (index == 1) {
            // Đang ở Lược Sử
          } else if (index == 2) {
            context.go('/saban');
          } else {
            context.go('/dashboard');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            activeIcon: Icon(Icons.school_rounded),
            label: 'Bàn Học',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined),
            activeIcon: Icon(Icons.auto_stories_rounded),
            label: 'Lược Sử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.military_tech_outlined),
            activeIcon: Icon(Icons.military_tech_rounded),
            label: 'Sa Bàn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.landscape_outlined),
            activeIcon: Icon(Icons.landscape_rounded),
            label: 'Di Sản',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Sĩ Tử',
          ),
        ],
      ),
    );
  }
}
