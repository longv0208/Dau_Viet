import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../collection/presentation/unlock_celebration_dialog.dart';
import '../../../core/widgets/kabi_mascot_widget.dart';
import '../../streak/data/streak_dto.dart';
import '../data/attempt_dtos.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/renderer_base.dart';

Duration? _noRetry(int retryCount, Object error) => null;

final _resultProvider = FutureProvider.autoDispose
    .family<LessonResultDto, String>(retry: _noRetry, (ref, attemptId) async {
      final repo = ref.watch(attemptRepositoryProvider);
      if (ApiConfig.useMock) return repo.getResult(attemptId);
      return ref
          .read(authRepositoryProvider)
          .withAuth(() => repo.getResult(attemptId));
    });

final _recapContentProvider = FutureProvider.autoDispose
    .family<LessonContentDto?, String>((ref, attemptId) async {
      try {
        final repo = ref.watch(attemptRepositoryProvider);
        if (ApiConfig.useMock) {
          return await repo.getAttemptContent(attemptId);
        }
        return await ref
            .read(authRepositoryProvider)
            .withAuth(() => repo.getAttemptContent(attemptId));
      } catch (_) {
        return null;
      }
    });

/// Màn hình Kết quả bài học (Screen 6 chuẩn UI/UX Pro Max)
/// Hiển thị linh vật Rùa Kabi giương cờ ăn mừng, 3 thẻ chỉ số (Điểm số, XP, Năng lượng),
/// lời chúc mừng từ Mascot, danh mục phần thưởng di sản và nút tiếp tục.
class LessonResultScreen extends ConsumerWidget {
  final String attemptId;
  final LessonResultDto? initialResult;

  const LessonResultScreen({
    super.key,
    required this.attemptId,
    this.initialResult,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialResult != null) {
      return _ResultView(
        result: initialResult!,
        recapContent: ref.watch(_recapContentProvider(attemptId)).value,
      );
    }
    final asyncResult = ref.watch(_resultProvider(attemptId));
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      body: SafeArea(
        child: asyncResult.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: DauVietColors.heritageGreen,
            ),
          ),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(_resultProvider(attemptId)),
          ),
          data: (r) => _ResultView(
            result: r,
            recapContent: ref.watch(_recapContentProvider(attemptId)).value,
          ),
        ),
      ),
    );
  }
}

/// Body thực tế của _ResultView — tách riêng để StatefulWidget cha chịu
/// trách nhiệm một-việc: bắn unlock popup đúng 1 lần khi mount.
class _ResultBody extends StatelessWidget {
  final LessonResultDto result;
  final LessonContentDto? recapContent;

  const _ResultBody({required this.result, this.recapContent});

  @override
  Widget build(BuildContext context) {
    final bool completed = result.status.toUpperCase() == 'COMPLETED';
    final score = result.score;
    final scoreStr = score != null
        ? (score == score.roundToDouble()
              ? '${score.toInt()}'
              : score.toStringAsFixed(1))
        : '90';
    final summaryRaw = result.result['summary'] ?? result.result['message'];
    final summary = summaryRaw is String ? summaryRaw : null;
    final title =
        _str(recapContent?.content ?? const {}, ['title', 'lessonTitle']) ??
        'Bài 1: Nguồn gốc dân tộc';

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              // 1. Tiêu đề chúc mừng
              Text(
                completed ? 'HOÀN THÀNH BÀI HỌC' : 'KẾT THÚC LƯỢT HỌC',
                textAlign: TextAlign.center,
                style: DauVietTypography.headlineMedium.copyWith(
                  color: const Color(0xFF1F2421),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn thật tuyệt vời! 🎉',
                textAlign: TextAlign.center,
                style: DauVietTypography.bodyMedium.copyWith(
                  color: const Color(0xFF5E6963),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 12),

              // 2. Linh vật Rùa Kabi đội nón lá giương tay ăn mừng chiến thắng
              Center(
                child: SizedBox(
                  width: 150,
                  height: 140,
                  child: Image.asset(
                    'assets/images/kabi_celebration_victory.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const KabiMascotWidget(
                      mood: KabiMood.victory,
                      width: 140,
                      height: 140,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Khung tóm tắt bài học & 3 thẻ chỉ số (Score, XP, Energy)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE5DAC6),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B4513).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tên bài học
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: DauVietTypography.headlineSmall.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2421),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hàng 3 chỉ số đạt được chuẩn Screen 6
                    Row(
                      children: [
                        // Điểm số
                        Expanded(
                          child: _buildResultBadge(
                            icon: Icons.stars_rounded,
                            iconColor: const Color(0xFFD97706),
                            value: scoreStr,
                            subValue: '/100',
                            label: 'Điểm số',
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Kinh nghiệm XP
                        Expanded(
                          child: _buildResultBadge(
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFF2D6A4F),
                            value: '+50 XP',
                            label: 'Kinh nghiệm',
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Năng lượng
                        Expanded(
                          child: _buildResultBadge(
                            icon: Icons.favorite_rounded,
                            iconColor: const Color(0xFFC2410C),
                            value: '+1',
                            label: 'Năng lượng',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Lời thoại khích lệ từ Linh vật Kabi
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5DAC6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const ClipOval(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: KabiMascotWidget(
                                mood: KabiMood.guiding,
                                width: 32,
                                height: 32,
                                headOnly: true,
                                enableSound: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bạn đã hoàn thành bài học! Hành trình khám phá lịch sử Việt Nam vẫn còn rất nhiều điều thú vị đang chờ bạn!',
                              style: DauVietTypography.bodySmall.copyWith(
                                color: const Color(0xFF3D4842),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
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

              // Tóm tắt từ server (nếu có)
              if (summary != null && summary.isNotEmpty) ...[
                const SizedBox(height: 14),
                ActivityCard(
                  child: Text(
                    summary,
                    textAlign: TextAlign.center,
                    style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
                  ),
                ),
              ],

              // TASK-0023: thưởng + vật phẩm attempt này ĐÃ được server
              // cấp trong transaction complete() — chỉ hiển thị thật,
              // không phát thêm request "nhận thưởng" nào.
              if (result.rewards.isNotEmpty ||
                  result.itemsUnlocked.isNotEmpty) ...[
                const SizedBox(height: 14),
                _RewardsSection(result: result),
              ],

              // GAME-04: cue một lần — chỉ render khi player truyền
              // `newlyUnlockedDossiers` qua extra (deep-link/reload có
              // list rỗng → không re-show). Điều hướng tới Bộ Sưu Tập.
              if (result.newlyUnlockedDossiers.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DossierUnlockBanner(
                  count: result.newlyUnlockedDossiers.length,
                ),
              ],

              // STREAK-01: animation ngọn lửa — chỉ khi server vừa công
              // nhận một ngày học MỚI (newlyRecordedStreak từ complete
              // response qua extra). Replay/deep-link: field null → không
              // phát lại, không gọi thêm API.
              if (result.newlyRecordedStreak != null) ...[
                const SizedBox(height: 14),
                _StreakFlameBanner(streak: result.newlyRecordedStreak!),
              ],

              // Ôn lại bài học & Tư liệu
              if (recapContent != null) ...[
                const SizedBox(height: 14),
                _RecapSection(content: recapContent!),
              ],
              const SizedBox(height: 20),

              // 4. Hai nút hành động: Tiếp tục và Ôn tập lại
              DongSonButton(
                label: 'TIẾP TỤC ›',
                icon: Icons.arrow_forward_rounded,
                variant: DongSonButtonVariant.natureGreen,
                height: 52,
                onPressed: () => context.go('/dashboard'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/learning/lesson/${result.attemptId}'),
                icon: const Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: Color(0xFF5E6963),
                ),
                label: Text(
                  'Ôn tập lại',
                  style: DauVietTypography.labelLarge.copyWith(
                    color: const Color(0xFF1F2421),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Color(0xFFD8C8B0), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBadge({
    required IconData icon,
    required Color iconColor,
    required String value,
    String? subValue,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5DAC6), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: DauVietTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: const Color(0xFF1F2421),
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: DauVietTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: const Color(0xFF75807A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 9.5,
              color: const Color(0xFF75807A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chuyển _ResultView thành StatefulWidget để bắn unlock-popup ĐÚNG MỘT LẦN
/// khi màn được mở từ player (extra non-null). Deep-link/reload (initialResult
/// null → fetch lại) không trigger popup vì newlyUnlockedDossiers rỗng và
/// itemsUnlocked trên replay đã được hiển thị bình thường bên dưới.
class _ResultView extends StatefulWidget {
  final LessonResultDto result;

  /// Pinned lesson content (nullable — khi không fetch được thì chỉ hiện
  /// phần result-only).
  final LessonContentDto? recapContent;

  const _ResultView({required this.result, this.recapContent});

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  /// Chặn double-fire nếu widget rebuild (post-frame chỉ gọi một lần).
  bool _popupShown = false;

  @override
  void initState() {
    super.initState();
    // Chỉ bắn popup khi có item hoặc dossier MỚI — màn được mở với extra
    // từ player (fresh complete). Deep-link giữ nguyên view list bên dưới.
    if (widget.result.itemsUnlocked.isNotEmpty ||
        widget.result.newlyUnlockedDossiers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPopups());
    }
  }

  Future<void> _showPopups() async {
    if (!mounted || _popupShown) return;
    _popupShown = true;
    // await tuần tự — item trước, dossier sau; learner đóng từng cái.
    await UnlockCelebrationDialog.show(
      context,
      items: widget.result.itemsUnlocked,
      dossierIds: widget.result.newlyUnlockedDossiers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ResultBody(
      result: widget.result,
      recapContent: widget.recapContent,
    );
  }
}

/// Section thưởng + vật phẩm mới mở khóa của chính attempt (TASK-0023).
/// Dữ liệu đã được server ghi trong transaction complete(); đọc lại màn
/// này (deep-link) vẫn hiện đúng những gì attempt kích hoạt — KHÔNG
/// hiện lại như "thưởng mới" lần hai vì nguồn là ledger/inventory,
/// không phải client flag.
class _RewardsSection extends StatelessWidget {
  final LessonResultDto result;
  const _RewardsSection({required this.result});

  static const _typeLabels = {
    'EXP': 'Kinh nghiệm Sĩ Tử',
    'HISTORY_POINTS': 'Điểm Sử Ký',
  };

  static const _typeIcons = {
    'EXP': Icons.auto_awesome_rounded,
    'HISTORY_POINTS': Icons.history_edu_rounded,
  };

  static const _typeColors = {
    'EXP': DauVietColors.riverBlue,
    'HISTORY_POINTS': DauVietColors.imperialGold,
  };

  @override
  Widget build(BuildContext context) {
    return ActivityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('PHẦN THƯỞNG ĐÃ NHẬN'),
          const SizedBox(height: 10),
          for (final tx in result.rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _typeIcons[tx.rewardType] ?? Icons.card_giftcard_rounded,
                    size: 20,
                    color:
                        _typeColors[tx.rewardType] ??
                        DauVietColors.imperialGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _typeLabels[tx.rewardType] ?? tx.rewardType,
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '+${tx.amount}',
                    style: DauVietTypography.labelMedium.copyWith(
                      color:
                          _typeColors[tx.rewardType] ??
                          DauVietColors.imperialGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          if (result.itemsUnlocked.isNotEmpty) ...[
            const SizedBox(height: 4),
            const SectionLabel('VẬT PHẨM VỪA MỞ KHÓA'),
            const SizedBox(height: 8),
            for (final item in result.itemsUnlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: DauVietColors.cinnabarRed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: DauVietColors.imperialGold,
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: DauVietTypography.bodySmall.copyWith(
                          color: DauVietColors.inkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Vật phẩm học tập — xem trong Túi Đồ Sĩ Tử.',
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// STREAK-01: banner ngọn lửa chuỗi ngày — số đếm từ N-1 → N bằng
/// TweenAnimationBuilder, phát đúng một lần khi màn mở với ngày học mới.
/// Không gọi API, không re-show trên replay (field chỉ đi qua route extra).
class _StreakFlameBanner extends StatelessWidget {
  final StreakInfoDto streak;
  const _StreakFlameBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    final int current = streak.currentStreak;
    final int previous = current > 0 ? current - 1 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DauVietColors.cinnabarRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DauVietColors.cinnabarRed, width: 1.4),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 30,
                color: DauVietColors.cinnabarRed,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NGỌN LỬA HÀO KHÍ',
                  style: DauVietTypography.labelSmall.copyWith(
                    color: DauVietColors.cinnabarRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: previous.toDouble(),
                    end: current.toDouble(),
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    'Chuỗi ${value.round()} ngày học liên tiếp',
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (streak.longestStreak > current) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Kỷ lục: ${streak.longestStreak} ngày',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.inkMuted,
                      fontSize: 11,
                    ),
                  ),
                ] else if (current > 1) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Kỷ lục mới!',
                    style: DauVietTypography.bodySmall.copyWith(
                      color: DauVietColors.imperialGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// GAME-04: banner báo hồ sơ lịch sử vừa mở khoá — tappable, dẫn tới
/// màn Bộ Sưu Tập (/collection, tab dossier). Chỉ hiện một lần trong phiên
/// vì nguồn là field additive trên complete-response, không phải state bền.
class _DossierUnlockBanner extends StatelessWidget {
  final int count;
  const _DossierUnlockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/collection'),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DauVietColors.imperialGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DauVietColors.imperialGold, width: 1.4),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 22,
                color: DauVietColors.imperialGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐÃ MỞ KHÓA $count HỒ SƠ LỊCH SỬ',
                      style: DauVietTypography.labelSmall.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xem trong Bộ Sưu Tập của bạn',
                      style: DauVietTypography.bodySmall.copyWith(
                        color: DauVietColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DauVietColors.imperialGold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recap lịch sử gọn — chỉ dùng field có thật trong pinned snapshot:
/// title/centralQuestion của content, objectives[], stage titles,
/// evidence titles + source. Không bịa narrative, không hiển thị answer key.
class _RecapSection extends StatelessWidget {
  final LessonContentDto content;
  const _RecapSection({required this.content});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> c = content.content;
    final String? title = _str(c, ['title', 'lessonTitle']);
    final String? question = _str(c, ['centralQuestion', 'central_question']);
    final List<String> objectives = [
      for (final o in (c['objectives'] as List? ?? const []))
        if (o is String && o.isNotEmpty) o,
    ];
    final stages = content.stages;
    final evidence = content.evidence;
    final String? reading = _firstReadingExcerpt(c, stages);

    final bool hasContent =
        title != null ||
        question != null ||
        objectives.isNotEmpty ||
        stages.isNotEmpty ||
        evidence.isNotEmpty ||
        reading != null;
    if (!hasContent) return const SizedBox.shrink();

    return ActivityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('ÔN LẠI BÀI HỌC'),
          const SizedBox(height: 10),
          if (title != null)
            Text(
              title,
              style: DauVietTypography.headlineMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
              ),
            ),
          if (question != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: DauVietColors.imperialGold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    question,
                    style: DauVietTypography.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                      color: DauVietColors.inkText,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (objectives.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('MỤC TIÊU'),
            const SizedBox(height: 4),
            for (final o in objectives)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(
                        o,
                        style: DauVietTypography.bodySmall.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (reading != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DauVietColors.imperialGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: DauVietColors.imperialGold, width: 3),
                ),
              ),
              child: Text(
                reading,
                style: DauVietTypography.bodySmall.copyWith(
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  color: DauVietColors.inkText,
                ),
              ),
            ),
          ],
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('HÀNH TRÌNH'),
            const SizedBox(height: 4),
            Text(
              stages
                  .map((s) => s['title'] as String? ?? '')
                  .where((t) => t.isNotEmpty)
                  .join(' → '),
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
                height: 1.5,
              ),
            ),
          ],
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionLabel('TƯ LIỆU TRONG BÀI HỌC'),
            const SizedBox(height: 4),
            for (final e in evidence.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${e['title'] ?? e['id'] ?? ''}'
                  '${_srcSuffix(e)}',
                  style: DauVietTypography.bodySmall.copyWith(height: 1.45),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String? _str(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String _srcSuffix(Map<String, dynamic> e) {
  final src = e['source'];
  String? text;
  if (src is String) {
    text = src;
  } else if (src is Map) {
    // V30+ embeds source as object {title, author, url, citation} — pick title.
    text = (src['title'] ?? src['author']) as String?;
  }
  return (text != null && text.trim().isNotEmpty) ? ' (${text.trim()})' : '';
}

String? _firstReadingExcerpt(
  Map<String, dynamic> content,
  List<Map<String, dynamic>> stages,
) {
  for (final s in stages) {
    final acts = s['activities'] as List? ?? const [];
    for (final a in acts) {
      if (a is Map<String, dynamic> && a['type'] == 'READ') {
        final cfg = a['config'] as Map<String, dynamic>? ?? const {};
        final body = cfg['body'] as String?;
        if (body != null && body.trim().isNotEmpty) {
          final t = body.trim();
          return t.length > 200 ? '${t.substring(0, 197)}...' : t;
        }
      }
    }
  }
  return null;
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
              'Không tải được kết quả',
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
