import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/dong_son_button.dart';
import '../../../../core/widgets/parchment_card.dart';
import '../../data/attempt_dtos.dart';

/// Helpers chia sẻ cho các activity renderer — giữ file nhỏ, DRY.

/// Đọc text an toàn từ config: thử nhiều key phổ biến theo draft schema.
String? configText(Map<String, dynamic> config, List<String> keys) {
  for (final k in keys) {
    final v = config[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

List<Map<String, dynamic>> configList(Map<String, dynamic> config, String key) {
  final Object? raw = config[key];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

List<String> configIdList(Map<String, dynamic> config, String key) {
  final Object? raw = config[key];
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

/// Nút submit chuẩn của player — disable khi đang submit hoặc chưa đủ input.
class SubmitBar extends StatelessWidget {
  final bool enabled;
  final bool submitting;
  final String label;
  final VoidCallback onPressed;

  const SubmitBar({
    super.key,
    required this.enabled,
    required this.submitting,
    required this.onPressed,
    this.label = 'GỬI CÂU TRẢ LỜI',
  });

  @override
  Widget build(BuildContext context) {
    final String effectiveLabel = submitting ? 'ĐANG KIỂM TRA...' : label;
    return Semantics(
      button: true,
      enabled: enabled && !submitting,
      label: effectiveLabel,
      child: DongSonButton(
        label: effectiveLabel,
        icon: Icons.send_rounded,
        variant: DongSonButtonVariant.primaryCinnabar,
        height: 50,
        onPressed: (enabled && !submitting) ? onPressed : null,
      ),
    );
  }
}

/// Thẻ parchment chuẩn bọc nội dung học.
class ActivityCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ActivityCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ParchmentCard(
      backgroundColor: DauVietColors.parchmentContainer,
      borderColor: DauVietColors.imperialGold,
      borderWidth: 1.2,
      padding: padding,
      child: child,
    );
  }
}

/// Title nhỏ kiểu label của section trong activity.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: DauVietTypography.labelSmall.copyWith(
        color: DauVietColors.inkMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Base state cho renderer có selection — quản lý `submitting` từ parent.
abstract class ActivityRendererState<W extends StatefulWidget>
    extends State<W> {
  Map<String, dynamic>? buildAnswer();
}

/// Helper lấy instruction an toàn.
String activityInstruction(ActivityRefDto activity) =>
    activity.instruction ?? '';

/// Issue #35: banner inline "Đúng k/n mục · Còn x/y lượt" — đọc
/// EvaluationDto trả về sau một submit retry-in-place. Trả SizedBox.shrink()
/// khi không có gì để nói (lần render đầu, hoặc outcome COMPLETED/SUPPORTED).
class InlineGradingHint extends StatelessWidget {
  final EvaluationDto? evaluation;
  final int? maxAttempts;

  const InlineGradingHint({super.key, this.evaluation, this.maxAttempts});

  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    if (e == null) return const SizedBox.shrink();
    // Chỉ gợi ý khi chưa hoàn thành thật (retry đường PARTIAL/INCORRECT).
    final outcome = e.outcome;
    if (outcome == 'COMPLETED' || outcome == 'SUPPORTED') {
      return const SizedBox.shrink();
    }
    final cp = e.correctPositions;
    final ti = e.totalItems;
    final pc = e.partsCorrect;
    final cc = e.correctCount;
    final fc = e.falseCount;
    final sc = e.score;
    final used = e.attemptCount;
    final isExhausted = e.exhausted || e.budgetExhausted;
    final parts = <String>[];
    if (cp != null && ti != null && ti > 0) {
      parts.add('Đúng $cp/$ti mục');
    } else if (pc != null && pc > 0) {
      parts.add('Đúng $pc/3 phần');
    } else if (cc != null) {
      if (fc != null && fc > 0) {
        parts.add('Đúng $cc · sai $fc dấu vết đã chọn');
      } else if (cc > 0) {
        parts.add('Đúng $cc dấu vết (còn thiếu)');
      } else {
        parts.add('Chưa chọn đúng dấu vết liên quan');
      }
    } else if (sc != null) {
      if (sc > 0) {
        final pct = (sc * 100).round();
        parts.add('Kết quả một phần (điểm $pct%)');
      } else {
        parts.add('Kết quả chưa chính xác');
      }
    }
    if (isExhausted) {
      parts.add('Đã hết lượt — bước này được tính hoàn thành');
    } else if (maxAttempts != null && used != null) {
      final left = maxAttempts! - used;
      if (left >= 0) parts.add('còn $left/$maxAttempts lượt');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.imperialGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.imperialGold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: DauVietColors.cinnabarRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
