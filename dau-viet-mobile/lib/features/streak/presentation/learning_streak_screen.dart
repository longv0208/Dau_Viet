import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/chapter_number_badge.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../island/data/island_providers.dart';
import '../../../core/widgets/hero_paper_banner.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/stamp_seal_badge.dart';
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
      appBar: AppBar(
        backgroundColor: DauVietColors.paperBackground,
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
      body: SafeArea(
        child: streakAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: DauVietColors.cinnabarRed),
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
    );
  }
}

class _Body extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(islandWalletProvider);
    final int? balance = walletAsync.value?.historyPoints;
    final totalStudiedDays = calendar.value?.days.length ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header hero + 2. Số ngày streak lớn
          _FlameHero(streak: streak),
          const SizedBox(height: 16),

          // Thông điệp hôm nay
          _TodayMessage(streak: streak),
          const SizedBox(height: 16),

          // 5. CTA "Học ngay"
          DongSonButton(
            label: 'Học ngay',
            icon: Icons.play_arrow_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            width: double.infinity,
            onPressed: () => context.go('/dashboard'),
          ),

          // 6. Section title + 3. Weekly strip ngày
          const SectionDivider(
            eyebrow: 'NHỊP ĐỘ TUẦN',
            title: 'Chuỗi 7 Ngày Gần Nhất',
          ),
          _WeeklyStrip(streak: streak, calendar: calendar),

          // 6. Section title + 4. Stat cards
          const SectionDivider(
            eyebrow: 'THỐNG KÊ',
            title: 'Thành Tích Chuyên Cần',
          ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Chuỗi hiện tại',
                  value: '${streak.currentStreak}',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Kỷ lục',
                  value: '${streak.longestStreak}',
                  icon: Icons.emoji_events_rounded,
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
                ),
              ),
            ],
          ),

          // STREAK-02: Thẻ Khiên Bảo Vệ Chuỗi — X/3 khiên, đổi 20 điểm.
          _ShieldCard(streak: streak, balance: balance),
          const SizedBox(height: 18),

          // STREAK-02: Mốc thưởng chuỗi 3/7/14/30.
          _MilestoneCard(streak: streak),
          const SizedBox(height: 18),

          // 6. Section title + Lịch tháng — chấm đỏ ngày đã học theo
          // server + marker 🛡️ cho ngày được khiên bảo vệ.
          const SectionDivider(
            eyebrow: 'SỔ CHUYÊN CẦN',
            title: 'Lịch Tháng',
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
        const HeroPaperBanner(
          height: 160,
          eyebrow: 'CHUỖI NGÀY HỌC',
          title: 'Ngọn Lửa Hào Khí',
          subtitle: 'Thắp sáng hành trình khám phá sử Việt mỗi ngày',
        ),
        const SizedBox(height: 14),
        TactileCard(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 64,
                color: lit
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.cinnabarRed.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                '${streak.currentStreak}',
                style: DauVietTypography.chapterNumber.copyWith(
                  fontSize: 48,
                  color: DauVietColors.cinnabarRed,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ngày học liên tiếp',
                style: DauVietTypography.bodyMedium.copyWith(
                  color: DauVietColors.inkSecondary,
                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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

          final Widget statusSeal;
          if (isDone) {
            statusSeal = const StampSealBadge.success('✓', size: 32);
          } else if (isToday) {
            statusSeal = const StampSealBadge(
              '•',
              size: 32,
              color: DauVietColors.imperialGold,
            );
          } else {
            statusSeal = const StampSealBadge.outline(
              '·',
              size: 32,
              color: DauVietColors.outlineVariant,
            );
          }

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
                ChapterNumberBadge(
                  dayDate.day.toString().padLeft(2, '0'),
                  size: 36,
                  filled: isDone,
                ),
                const SizedBox(height: 6),
                statusSeal,
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
    final Color color;
    if (streak.completedToday) {
      text = 'Hôm nay bạn đã ghi danh — ngọn lửa vẫn rực sáng!';
      color = DauVietColors.heritageGreen;
    } else if (streak.streakAlive) {
      text = 'Chuỗi vẫn còn! Hoàn thành một bài học hôm nay để giữ ngọn lửa.';
      color = DauVietColors.imperialGold;
    } else if (streak.currentStreak == 0) {
      text = 'Hoàn thành bài học đầu tiên để thắp Ngọn Lửa Hào Khí.';
      color = DauVietColors.inkMuted;
    } else {
      text = 'Chuỗi đã dừng — bắt đầu lại hôm nay để thắp lửa mới!';
      color = DauVietColors.cinnabarRed;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: DauVietTypography.bodyMedium.copyWith(
          color: DauVietColors.inkText,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TactileCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 22, color: DauVietColors.jade),
          const SizedBox(height: 6),
          Text(
            value,
            style: DauVietTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: DauVietColors.inkHeading,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: DauVietTypography.sectionEyebrow.copyWith(
              fontSize: 9.5,
              color: DauVietColors.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// STREAK-02: Thẻ Khiên Bảo Vệ Chuỗi — X/3 khiên, nút đổi 20 Điểm Sử Ký.
/// Số khiên/giá/giới hạn đều đọc từ server (LearningStreakDto) — không
/// hard-code. Số dư ví đọc islandWalletProvider; nút disable khi đã 3/3
/// hoặc đang gọi API (chặn double-tap).
class _ShieldCard extends ConsumerStatefulWidget {
  final LearningStreakDto streak;
  final int? balance;
  const _ShieldCard({required this.streak, required this.balance});

  @override
  ConsumerState<_ShieldCard> createState() => _ShieldCardState();
}

class _ShieldCardState extends ConsumerState<_ShieldCard> {
  bool _buying = false;

  Future<void> _buy() async {
    if (_buying) return;
    setState(() => _buying = true);
    try {
      final res = await ref
          .read(streakProvider.notifier)
          .buyShield(idempotencyKey: const Uuid().v4());
      if (!mounted) return;
      // Invalidate ví để pill Điểm Sử Ký đồng bộ balance mới.
      ref.invalidate(islandWalletProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã đổi 1 Khiên Bảo Vệ · còn ${res.balanceAfter} Điểm Sử Ký',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = switch (e.error.code) {
        'SHIELD_AT_MAX_CAPACITY' =>
            'Đã đủ ${widget.streak.maxShields}/${widget.streak.maxShields} '
                'khiên — không thể đổi thêm.',
        'INSUFFICIENT_FUNDS' =>
            'Không đủ Điểm Sử Ký (cần ${widget.streak.shieldCostPoints}).',
        _ => 'Không đổi được khiên — thử lại sau.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không đổi được khiên — thử lại sau.')),
      );
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.streak;
    final atMax = streak.shieldCount >= streak.maxShields;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DAC6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  size: 18, color: DauVietColors.heritageGreen),
              const SizedBox(width: 6),
              Text(
                'BẢO VỆ CHUỖI',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${streak.shieldCount}/${streak.maxShields} khiên',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DauVietColors.heritageGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3 ô khiên — sáng lên theo số đang có.
          Row(
            children: [
              for (int i = 0; i < streak.maxShields; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 34,
                    color: i < streak.shieldCount
                        ? DauVietColors.heritageGreen
                        : const Color(0xFFE0D8C8),
                  ),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Khi quay lại học sau khi bỏ lỡ đúng một ngày, hệ thống '
                  'tự dùng một khiên để giữ chuỗi. Nghỉ lâu hơn sẽ bắt '
                  'đầu chuỗi mới.',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 10.5,
                    color: const Color(0xFF75807A),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (streak.atRiskToday && streak.shieldCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Hôm nay chuỗi của bạn sẽ được khiên bảo vệ nếu bỏ lỡ.',
                style: DauVietTypography.bodySmall.copyWith(
                  fontSize: 10.5,
                  color: DauVietColors.heritageGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          DongSonButton(
            label: atMax
                ? 'ĐÃ ĐỦ ${streak.maxShields}/${streak.maxShields} KHIÊN'
                : 'ĐỔI KHIÊN · ${streak.shieldCostPoints} ĐIỂM'
                    '${widget.balance == null ? '' : ' (CÒN ${widget.balance})'}',
            icon: Icons.shield_outlined,
            variant: DongSonButtonVariant.imperialGold,
            isLoading: _buying,
            onPressed: (atMax || _buying) ? null : _buy,
            height: 44,
          ),
        ],
      ),
    );
  }
}

/// STREAK-02: Card tiến độ mốc thưởng chuỗi 3/7/14/30 — mỗi mốc hiển
/// thị thưởng EXP + Điểm Sử Ký; đánh dấu mốc đã đạt và khoảng cách tới
/// mốc kế tiếp.
class _MilestoneCard extends StatelessWidget {
  final LearningStreakDto streak;
  const _MilestoneCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final current = streak.currentStreak;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DAC6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded,
                  size: 18, color: DauVietColors.imperialGold),
              const SizedBox(width: 6),
              Text(
                'THƯỞNG MỐC CHUỖI',
                style: DauVietTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2421),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Duy trì mỗi ngày từ ngày 2: +5 EXP, +5 Điểm Sử Ký. '
            'Thưởng lớn tại các mốc:',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 10.5,
              color: const Color(0xFF75807A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          for (final m in streak.milestones)
            _MilestoneRow(milestone: m, current: current),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final StreakMilestoneDto milestone;
  final int current;
  const _MilestoneRow({required this.milestone, required this.current});

  @override
  Widget build(BuildContext context) {
    final reached = current >= milestone.day;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            reached
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: reached
                ? DauVietColors.heritageGreen
                : const Color(0xFFC9BFAC),
          ),
          const SizedBox(width: 8),
          Text(
            '${milestone.day} ngày',
            style: DauVietTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: reached
                  ? DauVietColors.heritageGreen
                  : const Color(0xFF3D4842),
            ),
          ),
          const Spacer(),
          Text(
            '+${milestone.bonusExp} EXP · +${milestone.bonusPoints} Điểm',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 11,
              color: reached
                  ? const Color(0xFF75807A)
                  : DauVietColors.imperialGold,
              fontWeight: FontWeight.w700,
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
    // STREAK-02: ngày được khiên cứu — marker 🛡️ khác ngày học thực.
    final protectedDays = calendar.value == null
        ? const <int>{}
        : {
            for (final d in calendar.value!.protectedDates)
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
              final shielded = protectedDays.contains(day);
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
                      : shielded
                          ? Border.all(
                              color: DauVietColors.heritageGreen,
                              width: 1.4,
                            )
                          : null,
                ),
                alignment: Alignment.center,
                child: shielded
                    ? const Icon(Icons.shield_rounded,
                        size: 14, color: Colors.white)
                    : Text(
                        '$day',
                        style: DauVietTypography.bodySmall.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: studied
                              ? Colors.white
                              : DauVietColors.inkText,
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
