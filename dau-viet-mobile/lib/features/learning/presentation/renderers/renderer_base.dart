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
