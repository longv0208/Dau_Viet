import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/energy_pill.dart';
import '../../../core/widgets/parchment_card.dart';

/// Màn hình M-03: Bàn Học Tập Người Học (Learner Dashboard & Resume Card)
/// Khớp 100% với thiết kế Stitch f478e5da7eb1492ba6be259f9e31d459
class LearnerDashboardScreen extends StatefulWidget {
  const LearnerDashboardScreen({super.key});

  @override
  State<LearnerDashboardScreen> createState() => _LearnerDashboardScreenState();
}

class _LearnerDashboardScreenState extends State<LearnerDashboardScreen> {
  int _currentBottomNavIndex = 0;

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
              // 1. Top Bar: Hồ Sơ Sĩ Tử & Chỉ Số Sinh Lực
              _buildTopHeader(),

              // 2. Nội dung cuộn chính của Bàn Học Tập
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lời chào & Huy hiệu ngày học
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào Sĩ tử,',
                                  style: DauVietTypography.bodySmall.copyWith(color: DauVietColors.inkMuted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bàn Học Tập Sử Ký',
                                  style: DauVietTypography.headlineMedium.copyWith(
                                    color: DauVietColors.cinnabarRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chuỗi ngày học Streak
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: DauVietColors.parchmentContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: DauVietColors.imperialGold, width: 1.2),
                              boxShadow: DauVietColors.heritageShadow,
                            ),
                            child: Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Text(
                                  '3 ngày',
                                  style: DauVietTypography.labelMedium.copyWith(
                                    color: DauVietColors.inkText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. Hero Resume Card (M-C04): Tiếp tục bài học đang dang dở
                      _buildResumeCard(),
                      const SizedBox(height: 24),

                      // 4. Khối 4 Dấu Vết Lịch Sử Trung Tâm
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '4 DẤU VẾT LỊCH SỬ',
                              style: DauVietTypography.labelMedium.copyWith(
                                color: DauVietColors.inkMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Text(
                            'Khám phá theo quy trình',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: DauVietColors.cinnabarRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildFourTracesGrid(),
                      const SizedBox(height: 24),

                      // 5. Khối Lối Tắt Nhanh (Sa bàn, Đảo di sản, Viện Thái Y)
                      Text(
                        'LỐI TẮT KHÁM PHÁ',
                        style: DauVietTypography.labelMedium.copyWith(
                          color: DauVietColors.inkMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickShortcuts(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Top Bar với Avatar và EnergyPill
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          // Avatar Sĩ tử tròn viền vàng
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.parchmentContainer,
              border: Border.all(color: DauVietColors.imperialGold, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'KM',
              style: TextStyle(
                fontFamily: 'Noto Serif',
                fontWeight: FontWeight.w800,
                color: DauVietColors.cinnabarRed,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sĩ tử Khang Minh',
                  style: DauVietTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Cấp độ 5 • Tập sự Sử ký',
                  style: DauVietTypography.labelSmall.copyWith(color: DauVietColors.natureGreen),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.go('/energy');
            },
            child: const EnergyPill(
              energy: 100,
              maxEnergy: 100,
              historyPoints: 150,
            ),
          ),
        ],
      ),
    );
  }

  // Resume Card (M-C04): Bài học đang dang dở
  Widget _buildResumeCard() {
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DauVietColors.cinnabarRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'BÀI HỌC ĐANG HỌC',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('⚡ -20 Thể lực', style: TextStyle(fontSize: 12, color: DauVietColors.inkMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Chiến Dịch Bạch Đằng 938',
            style: DauVietTypography.headlineMedium.copyWith(
              color: DauVietColors.cinnabarRed,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hồi 2: Kế sách cọc ngầm & Sa bàn thủy chiến',
            style: DauVietTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // Thanh tiến trình học tập 50%
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Tiến độ hoàn thành', style: DauVietTypography.bodySmall),
                  ),
                  Text('50% (2/4 Giai đoạn)', style: DauVietTypography.labelSmall.copyWith(color: DauVietColors.cinnabarRed)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.5,
                  minHeight: 8,
                  backgroundColor: DauVietColors.parchmentHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(DauVietColors.cinnabarRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Nút tiếp tục
          DongSonButton(
            label: 'Tiếp tục bài học ngay ->',
            icon: Icons.play_arrow_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            height: 48,
            onPressed: () {
              context.go('/campaign/evt_bach_dang_938');
            },
          ),
        ],
      ),
    );
  }

  // Lưới 4 Dấu Vết Lịch Sử
  Widget _buildFourTracesGrid() {
    final traces = [
      {'num': '1', 'name': 'Khởi Nguồn', 'desc': 'Quân mưu Ngô Quyền', 'done': true},
      {'num': '2', 'name': 'Diễn Biến', 'desc': 'Cọc ngầm & Thủy triều', 'done': true},
      {'num': '3', 'name': 'Bằng Chứng', 'desc': 'Bãi cọc Yên Giang C-14', 'done': false},
      {'num': '4', 'name': 'Âm Vang', 'desc': 'Độc lập trường tồn', 'done': false},
    ];

    return Row(
      children: traces.map((t) {
        final isDone = t['done'] as bool;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFFBF4E6) : DauVietColors.parchmentContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone ? DauVietColors.imperialGold : DauVietColors.outlineVariant,
                width: isDone ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDone ? DauVietColors.cinnabarRed : DauVietColors.parchmentHigh,
                  child: Text(
                    t['num'] as String,
                    style: TextStyle(
                      color: isDone ? Colors.white : DauVietColors.inkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t['name'] as String,
                  textAlign: TextAlign.center,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DauVietColors.inkText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Khối lối tắt khám phá
  Widget _buildQuickShortcuts() {
    return Row(
      children: [
        Expanded(
          child: ParchmentCard(
            padding: const EdgeInsets.all(14),
            onTap: () {
              context.go('/saban');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.military_tech_rounded, color: DauVietColors.cinnabarRed, size: 28),
                const SizedBox(height: 8),
                Text('Sa Bàn Thời Kỳ', style: DauVietTypography.labelMedium),
                const SizedBox(height: 2),
                Text('Bạch Đằng 938 & 54 Chiến dịch', style: DauVietTypography.bodySmall.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ParchmentCard(
            padding: const EdgeInsets.all(14),
            onTap: () {
              context.go('/timeline');
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.timeline_rounded, color: DauVietColors.imperialGold, size: 28),
                const SizedBox(height: 8),
                Text('Lược Sử Niên Biểu', style: DauVietTypography.labelMedium),
                const SizedBox(height: 2),
                Text('Dòng thời gian các triều đại', style: DauVietTypography.bodySmall.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Bottom Navigation Bar di sản
  Widget _buildBottomNav() {
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
        currentIndex: _currentBottomNavIndex,
        onTap: (index) {
          setState(() {
            _currentBottomNavIndex = index;
          });
          if (index == 0) {
            // Đang ở Bàn học
          } else if (index == 1) {
            context.go('/timeline');
          } else if (index == 2) {
            context.go('/saban');
          } else if (index == 3) {
            context.go('/island');
          } else if (index == 4) {
            context.go('/inventory');
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: DauVietColors.cinnabarRed,
        unselectedItemColor: DauVietColors.inkMuted,
        selectedLabelStyle: DauVietTypography.labelSmall.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: DauVietTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
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
