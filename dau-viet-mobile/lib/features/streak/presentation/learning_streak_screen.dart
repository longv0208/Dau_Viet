import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/section_eyebrow.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: DauVietColors.inkText,
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          'NGỌN LỬA HÀO KHÍ',
          style: DauVietTypography.labelMedium.copyWith(
            color: DauVietColors.cinnabarRed,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        iconTheme: const IconThemeData(color: DauVietColors.inkText),
      ),
      body: Stack(
        children: [
          // Nền chìm tranh non nước phía trên — đồng bộ dashboard.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 460,
            child: IgnorePointer(
              child: Image.asset(
                'assets/images/landscape_hero_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Veil giấy mờ — phai tranh vào parchment.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 520,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DauVietColors.paperCard.withValues(alpha: 0.52),
                      DauVietColors.paperCard.withValues(alpha: 0.62),
                      DauVietColors.paperBackground.withValues(alpha: 0.90),
                      DauVietColors.paperBackground,
                    ],
                    stops: const [0.0, 0.40, 0.80, 1.0],
                  ),
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
    final bool lit = streak.completedToday || streak.streakAlive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner card: badge + title + subtitle + mascot (mockup)
        TactileCard(
          padding: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFFF3E5CE),
          borderColor: DauVietColors.outlineVariant,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionEyebrow(
                      'CHUỖI NGÀY HỌC',
                      color: DauVietColors.imperialGoldDark,
                      showShadow: false,
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ngọn Lửa Hào Khí',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: DauVietColors.chapterGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thắp sáng hành trình khám phá\nsử Việt mỗi ngày',
                      maxLines: 2,
                      style: DauVietTypography.bodySmall.copyWith(
                        fontSize: 11.5,
                        height: 1.35,
                        color: DauVietColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Image.asset(
                'assets/images/turtle_map.png',
                width: 84,
                height: 84,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.local_fire_department_rounded,
                  size: 60,
                  color: DauVietColors.cinnabarRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Flame card: vầng sáng vàng + lửa nhiều lớp + số chuỗi (mockup)
        TactileCard(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Vầng sáng vàng sau lửa (mockup golden glow)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          DauVietColors.imperialGold.withValues(alpha: 0.55),
                          DauVietColors.imperialGold.withValues(alpha: 0.18),
                          DauVietColors.imperialGold.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  // Lửa lớp ngoài (đỏ) + lõi trong (vàng cam)
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 64,
                    color: lit
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.cinnabarRed.withValues(alpha: 0.3),
                  ),
                  Positioned(
                    bottom: 20,
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      size: 28,
                      color: lit
                          ? DauVietColors.imperialGold
                          : DauVietColors.imperialGold.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${streak.currentStreak}',
                style: DauVietTypography.headlineLarge.copyWith(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.cinnabarRed,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ngày học liên tiếp',
                style: DauVietTypography.bodyMedium.copyWith(
                  color: DauVietColors.chapterGreen,
                  fontWeight: FontWeight.w700,
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

    return TactileCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
    // Status box xanh (mockup): icon check tròn trái + text đậm xanh
    // + mây trang trí mờ góc phải
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DauVietColors.heritageGreenSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DauVietColors.heritageGreenLight.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // Mây mờ góc phải (mockup)
            Positioned(
              right: -8,
              top: -8,
              child: Icon(
                Icons.cloud_rounded,
                size: 46,
                color: DauVietColors.heritageGreen.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              right: 16,
              bottom: -10,
              child: Icon(
                Icons.cloud_rounded,
                size: 34,
                color: DauVietColors.heritageGreen.withValues(alpha: 0.05),
              ),
            ),
            // Nội dung chính
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: DauVietColors.heritageGreenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      text,
                      style: DauVietTypography.bodyMedium.copyWith(
                        fontSize: 12.5,
                        color: DauVietColors.chapterGreen,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
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
    return TactileCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          // Icon trong vòng tròn nhẹ (mockup)
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: DauVietTypography.headlineSmall.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: DauVietColors.inkHeading,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10,
              color: DauVietColors.inkMuted,
              fontWeight: FontWeight.w600,
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
