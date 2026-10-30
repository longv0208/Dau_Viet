import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/tactile_card.dart';
import '../../learning/data/learning_providers.dart';
import '../data/streak_dto.dart';
import '../data/streak_providers.dart';

/// Màn hình chi tiết Chuỗi Ngày Học — Ngọn Lửa Hào Khí (STREAK-01).
/// Mọi con số đọc từ streakProvider (server-side Asia/Ho_Chi_Minh);
/// lịch tháng đọc streakCalendarProvider — KHÔNG có số hard-code.
class LearningStreakScreen extends ConsumerStatefulWidget {
  const LearningStreakScreen({super.key});

  @override
  ConsumerState<LearningStreakScreen> createState() =>
      _LearningStreakScreenState();
}

class _LearningStreakScreenState extends ConsumerState<LearningStreakScreen> {
  /// Tháng đang xem trên lịch — khởi tạo theo device; ngày chấm vẫn
  /// theo ngày VN server trả.
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(streakProvider);
    final sess = streakSessionKeyOf(ref.watch(authSessionProvider));
    final calendarAsync = ref.watch(
      streakCalendarProvider((
        year: _visibleMonth.year,
        month: _visibleMonth.month,
        sess: sess,
      )),
    );

    return Scaffold(
      backgroundColor: DauVietColors.paperBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profile');
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4E4C6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD8BF96),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF3A2A1D),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'NGỌN LỬA HÀO KHÍ',
          style: DauVietTypography.labelLarge.copyWith(
            fontSize: 15.5,
            color: const Color(0xFF183D2C),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
      ),
      body: Stack(
        children: [
          // Nền giấy dó ấm đồng nhất chuẩn ảnh mẫu #4
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAF2E1), Color(0xFFF5EBD8)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: streakAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: DauVietColors.cinnabarRed,
                ),
              ),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(streakProvider.notifier).refresh(),
              ),
              data: (streak) => _Body(
                streak: streak,
                visibleMonth: _visibleMonth,
                calendar: calendarAsync,
                onShiftMonth: _shiftMonth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final LearningStreakDto streak;
  final DateTime visibleMonth;
  final AsyncValue<LearningStreakCalendarDto> calendar;
  final ValueChanged<int> onShiftMonth;

  const _Body({
    required this.streak,
    required this.visibleMonth,
    required this.calendar,
    required this.onShiftMonth,
  });

  @override
  Widget build(BuildContext context) {
    final totalStudiedDays = calendar.value?.days.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Banner card (badge + title + mascot) + 2. Flame card số chuỗi
          _FlameHero(streak: streak),
          const SizedBox(height: 16),

          // 3. Status box xanh: đã ghi danh / giữ lửa
          _TodayMessage(streak: streak),
          const SizedBox(height: 16),

          // 4. CTA đỏ "Học ngay"
          DongSonButton(
            label: 'Học ngay',
            icon: Icons.play_arrow_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            width: double.infinity,
            onPressed: () => context.go('/dashboard'),
          ),

          // 5. Nhịp độ tuần — header icon + link + 7 ô pagoda
          _SectionTitle(
            icon: Icons.calendar_month_outlined,
            iconColor: DauVietColors.heritageGreenLight,
            title: 'Nhịp độ tuần',
            trailing: 'Chuỗi 7 Ngày Gần Nhất >',
          ),
          _WeeklyStrip(streak: streak, calendar: calendar),

          // 6. Thống kê — 3 thẻ số
          const _SectionTitle(
            icon: Icons.bar_chart_rounded,
            iconColor: DauVietColors.heritageGreenLight,
            title: 'Thống kê',
          ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Chuỗi hiện tại',
                  value: '${streak.currentStreak}',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: DauVietColors.cinnabarRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Kỷ lục',
                  value: '${streak.longestStreak}',
                  icon: Icons.emoji_events_rounded,
                  iconColor: DauVietColors.imperialGoldDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: streak.lastQualifiedDate != null
                      ? 'Ngày gần nhất'
                      : 'Tổng ngày',
                  value: streak.lastQualifiedDate != null
                      ? _fmtDate(streak.lastQualifiedDate)
                      : '$totalStudiedDays',
                  icon: Icons.calendar_today_rounded,
                  iconColor: DauVietColors.heritageGreenLight,
                ),
              ),
            ],
          ),

          // 7. Sổ chuyên cần — header icon + điều hướng tháng + calendar
          _SectionTitle(
            icon: Icons.calendar_today_outlined,
            iconColor: DauVietColors.cinnabarRed,
            title: 'Sổ chuyên cần',
            trailing: 'Lịch Tháng',
          ),
          _MonthCalendar(
            month: visibleMonth,
            calendar: calendar,
            today: streak.today,
            onShiftMonth: onShiftMonth,
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}

/// Header cho section — icon tròn + title serif + optional trailing link.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailing;
  const _SectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DauVietTypography.headlineSmall.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkHeading,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: DauVietColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero banner + Ngọn lửa lớn + số chuỗi pixel font 48 cinnabarRed.
class _FlameHero extends StatelessWidget {
  final LearningStreakDto streak;
  const _FlameHero({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Banner CHUỖI NGÀY HỌC + Ngọn Lửa Hào Khí + Trâu Đỏ cầm đuốc (ảnh mẫu #4)
        Container(
          height: 118,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFAF1DC), Color(0xFFF6E4BE)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDEC69A), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1C5D4024),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Minh họa Trâu Đỏ cầm đuốc + cổng thành + mây vàng 4x sắc nét bên phải
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/images/streak_torch_buffalo_right.png',
                  height: 118,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 130, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE5D4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD96A42),
                          width: 1.1,
                        ),
                      ),
                      child: Text(
                        'CHUỖI NGÀY HỌC',
                        style: DauVietTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: const Color(0xFFB3281D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ngọn Lửa Hào Khí',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 20.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF163C2B),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thắp sáng hành trình khám phá\nsử Việt mỗi ngày',
                      maxLines: 2,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4A3B2C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Card 2: Tranh cổ lầu + kỳ đài cờ đỏ + Ngọn lửa 3 lớp + số ngày học liên tiếp (ảnh mẫu #4)
        Container(
          height: 152,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF0DA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDEC69A), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x185D4024),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/streak_flame_landscape_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              // Ngọn lửa 3 lớp + hào quang mặt trời vẽ bằng Vector CustomPainter (không bao giờ mờ)
              const Positioned(
                top: 6,
                child: SizedBox(
                  width: 96,
                  height: 82,
                  child: CustomPaint(
                    painter: _VectorHeroThreeLayerFlamePainter(),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${streak.currentStreak}',
                      style: DauVietTypography.headlineLarge.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFA91D15),
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ngày học liên tiếp',
                      style: DauVietTypography.bodyMedium.copyWith(
                        fontSize: 12.5,
                        color: const Color(0xFF233829),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dải 7 ngày trong tuần hiện tại:
/// - Số ngày: `ChapterNumberBadge` (size 36)
/// - `done`: `StampSealBadge.success('✓', size: 32)`
/// - `today`: `StampSealBadge('•', size: 32, color: imperialGold)`
/// - `missed`: `StampSealBadge.outline('·', size: 32, color: outlineVariant)`
class _WeeklyStrip extends StatelessWidget {
  final LearningStreakDto streak;
  final AsyncValue<LearningStreakCalendarDto> calendar;

  const _WeeklyStrip({
    required this.streak,
    required this.calendar,
  });

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final refDate = streak.today ?? DateTime.now();
    final monday = DateTime(
      refDate.year,
      refDate.month,
      refDate.day - (refDate.weekday - 1),
    );
    final studiedDays = <DateTime>{
      if (calendar.value != null)
        for (final d in calendar.value!.days) DateTime(d.year, d.month, d.day),
      if (streak.completedToday && streak.today != null)
        DateTime(
          streak.today!.year,
          streak.today!.month,
          streak.today!.day,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF3E4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0CCA9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x105D4024),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final dayDate = DateTime(monday.year, monday.month, monday.day + i);
          final isToday = streak.today != null
              ? (dayDate.year == streak.today!.year &&
                    dayDate.month == streak.today!.month &&
                    dayDate.day == streak.today!.day)
              : (dayDate.year == refDate.year &&
                    dayDate.month == refDate.month &&
                    dayDate.day == refDate.day);
          final isDone = studiedDays.contains(dayDate);
          final isFuture = dayDate.isAfter(
            DateTime(refDate.year, refDate.month, refDate.day),
          );

          // Ô tròn: đã học = xanh đậm + check; hôm nay viền vàng; sắp tới = xám
          final Color cellBg = isDone
              ? DauVietColors.heritageGreen
              : (isFuture ? DauVietColors.paperDim : DauVietColors.paperCard);
          final Color iconColor = isDone
              ? Colors.white
              : (isFuture ? DauVietColors.inkLight : DauVietColors.inkMuted);

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _weekdayLabels[i],
                  style: DauVietTypography.labelSmall.copyWith(
                    color: isToday
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cellBg,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(
                                color: DauVietColors.imperialGold,
                                width: 2,
                              )
                            : Border.all(
                                color: DauVietColors.outlineVariant,
                                width: 1,
                              ),
                      ),
                      child: Icon(
                        Icons.account_balance_rounded,
                        size: 19,
                        color: iconColor,
                      ),
                    ),
                    // Badge trạng thái nhỏ ở góc dưới-phải
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: isDone
                              ? DauVietColors.natureGreen
                              : DauVietColors.paperDim,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DauVietColors.paperCard,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : Icons.circle,
                          size: isDone ? 9 : 5,
                          color: isDone
                              ? Colors.white
                              : DauVietColors.inkLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Thông điệp theo trạng thái hôm nay — giữ ngọn lửa / đã ghi / mất chuỗi.
class _TodayMessage extends StatelessWidget {
  final LearningStreakDto streak;
  const _TodayMessage({required this.streak});

  @override
  Widget build(BuildContext context) {
    final String text;
    if (streak.completedToday) {
      text = 'Hôm nay bạn đã ghi danh — ngọn lửa vẫn rực sáng!';
    } else if (streak.streakAlive) {
      text = 'Chuỗi vẫn còn! Hoàn thành một bài học hôm nay để giữ ngọn lửa.';
    } else if (streak.currentStreak == 0) {
      text = 'Hoàn thành bài học đầu tiên để thắp Ngọn Lửa Hào Khí.';
    } else {
      text = 'Chuỗi đã dừng — bắt đầu lại hôm nay để thắp lửa mới!';
    }
    // Status box xanh lá (ảnh mẫu #4): nút tròn xanh đậm có viền sáng + chữ đậm xanh
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE0F1E5), Color(0xFFCDE7D6)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF5A9372),
          width: 1.3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -10,
              child: Icon(
                Icons.cloud_rounded,
                size: 56,
                color: const Color(0xFF1E4D3B).withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2F7553), Color(0xFF16462F)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF78B393),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: DauVietTypography.bodyMedium.copyWith(
                        fontSize: 13,
                        color: const Color(0xFF163C2B),
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = DauVietColors.jade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF3E4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0CCA9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x105D4024),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineSmall.copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkHeading,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 9.5,
                      color: DauVietColors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lịch tháng — ngày đã học chấm đỏ son; hôm nay viền vàng kim.
/// Header có nút qua tháng; provider family cache từng tháng riêng.
class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final AsyncValue<LearningStreakCalendarDto> calendar;
  final DateTime? today;
  final ValueChanged<int> onShiftMonth;

  const _MonthCalendar({
    required this.month,
    required this.calendar,
    required this.today,
    required this.onShiftMonth,
  });

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final studiedDays = calendar.value == null
        ? const <int>{}
        : {
            for (final d in calendar.value!.days)
              if (d.year == month.year && d.month == month.month) d.day,
          };
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Dart weekday: Mon=1..Sun=7 — ô trống đầu = weekday-1.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final todayVn = today;

    return TactileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: DauVietColors.inkText,
                onPressed: () => onShiftMonth(-1),
              ),
              Text(
                'Tháng ${month.month}/${month.year}',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.inkHeading,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: DauVietColors.inkText,
                onPressed: () => onShiftMonth(1),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 10,
                        color: DauVietColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, i) {
              if (i < leadingBlanks) return const SizedBox.shrink();
              final day = i - leadingBlanks + 1;
              final studied = studiedDays.contains(day);
              final isToday =
                  todayVn != null &&
                  todayVn.year == month.year &&
                  todayVn.month == month.month &&
                  todayVn.day == day;
              return Container(
                decoration: BoxDecoration(
                  color: studied
                      ? DauVietColors.cinnabarRed
                      : DauVietColors.paperCard,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(
                          color: DauVietColors.imperialGold,
                          width: 1.6,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: studied ? Colors.white : DauVietColors.inkText,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: DauVietColors.cinnabarRed,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tải được chuỗi ngày học',
              style: DauVietTypography.headlineSmall.copyWith(
                color: DauVietColors.inkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            DongSonButton(
              label: 'THỬ LẠI',
              icon: Icons.refresh_rounded,
              variant: DongSonButtonVariant.imperialGold,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ Vector ngọn lửa 3 lớp (đỏ chu sa -> cam rực -> vàng kim) kèm vầng hào quang
/// cho thẻ trung tâm Ngọn Lửa Hào Khí.
class _VectorHeroThreeLayerFlamePainter extends CustomPainter {
  const _VectorHeroThreeLayerFlamePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.54);

    // 1. Vầng hào quang mặt trời phía sau ngọn lửa
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF6C665).withValues(alpha: 0.65),
          const Color(0xFFF6C665).withValues(alpha: 0.25),
          const Color(0xFFF6C665).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.54));
    canvas.drawCircle(center, w * 0.54, haloPaint);

    // 2. Lớp lửa ngoài cùng (Đỏ chu sa đậm)
    final outer = Path()
      ..moveTo(w * 0.52, h * 0.04)
      ..cubicTo(w * 0.58, h * 0.18, w * 0.66, h * 0.26, w * 0.64, h * 0.38)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.80, h * 0.44, w * 0.78, h * 0.62)
      ..cubicTo(w * 0.76, h * 0.82, w * 0.64, h * 0.94, w * 0.50, h * 0.94)
      ..cubicTo(w * 0.36, h * 0.94, w * 0.22, h * 0.82, w * 0.22, h * 0.60)
      ..cubicTo(w * 0.22, h * 0.44, w * 0.30, h * 0.32, w * 0.36, h * 0.38)
      ..cubicTo(w * 0.35, h * 0.24, w * 0.44, h * 0.14, w * 0.52, h * 0.04)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB32317), Color(0xFFD8431E)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 3. Lớp lửa giữa (Cam vàng rực)
    final mid = Path()
      ..moveTo(w * 0.50, h * 0.28)
      ..cubicTo(w * 0.58, h * 0.40, w * 0.67, h * 0.52, w * 0.65, h * 0.70)
      ..cubicTo(w * 0.63, h * 0.86, w * 0.56, h * 0.93, w * 0.50, h * 0.93)
      ..cubicTo(w * 0.44, h * 0.93, w * 0.36, h * 0.86, w * 0.35, h * 0.68)
      ..cubicTo(w * 0.34, h * 0.52, w * 0.43, h * 0.40, w * 0.50, h * 0.28)
      ..close();
    canvas.drawPath(
      mid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF39832), Color(0xFFF9C459)],
        ).createShader(Rect.fromLTWH(0, h * 0.28, w, h * 0.66)),
    );

    // 4. Lõi lửa trong cùng (Đỏ cam + tâm vàng sáng)
    final core = Path()
      ..moveTo(w * 0.50, h * 0.54)
      ..cubicTo(w * 0.56, h * 0.64, w * 0.58, h * 0.76, w * 0.55, h * 0.88)
      ..cubicTo(w * 0.52, h * 0.94, w * 0.48, h * 0.94, w * 0.45, h * 0.88)
      ..cubicTo(w * 0.42, h * 0.76, w * 0.44, h * 0.64, w * 0.50, h * 0.54)
      ..close();
    canvas.drawPath(core, Paint()..color = const Color(0xFFC83619));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

