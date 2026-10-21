import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// DRAG_ORDER — sắp xếp `items[]` theo đúng trình tự lịch sử.
/// Items đến đã được server shuffle deterministic (learner presentation).
/// ReorderableListView + nút lên/xuống accessibility + số thứ tự rõ.
/// Submit `{orderedIds}`. KHÔNG sort lại theo answer key; không expose
/// expectedOrder/acceptedSequences.
class DragOrderRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;

  const DragOrderRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<DragOrderRenderer> createState() => _DragOrderRendererState();
}

class _DragOrderRendererState extends State<DragOrderRenderer> {
  late List<Map<String, dynamic>> _items;
  late final List<String> _initialOrder;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // Giữ nguyên thứ tự server gửi — KHÔNG sort lại.
    _items = List.of(configList(widget.activity.config, 'items'));
    _initialOrder = [for (final it in _items) it['id'] as String? ?? ''];
  }

  /// Dirty = thứ tự hiện tại khác thứ tự server gửi lúc đầu.
  void _reportDirty() {
    final now = [for (final it in _items) it['id'] as String? ?? ''];
    _dirty = !_listEq(now, _initialOrder);
    widget.onInputChanged?.call(_dirty);
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _move(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= _items.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
      _reportDirty();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const ActivityCard(
        child: Text('Hoạt động sắp xếp chưa có dữ liệu.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('KÉO THẢ HOẶC DÙNG MŨI TÊN ĐỂ SẮP XẾP ĐÚNG THỨ TỰ'),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _items.length,
          onReorderItem: (oldIndex, newIndex) {
            HapticFeedback.mediumImpact();
            setState(() {
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
              _reportDirty();
            });
          },
          proxyDecorator: (child, index, animation) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            color: DauVietColors.parchmentContainer,
            child: child,
          ),
          itemBuilder: (context, i) {
            final item = _items[i];
            final String id = item['id'] as String? ?? 'item-$i';
            return _OrderTile(
              key: ValueKey(id),
              index: i,
              total: _items.length,
              label: (item['label'] ?? item['text'] ?? id) as String,
              enabled: !widget.submitting,
              onUp: () => _move(i, -1),
              onDown: () => _move(i, 1),
            );
          },
        ),
        const SizedBox(height: 12),
        SubmitBar(
          enabled: true,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({
            'orderedIds': [for (final it in _items) it['id'] as String? ?? ''],
          }),
        ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  final int index;
  final int total;
  final String label;
  final bool enabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _OrderTile({
    super.key,
    required this.index,
    required this.total,
    required this.label,
    required this.enabled,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle — vùng chạm rộng, icon rõ.
          ReorderableDragStartListener(
            index: index,
            enabled: enabled,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: enabled
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.inkMuted,
                size: 22,
              ),
            ),
          ),
          // Số thứ tự.
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DauVietColors.imperialGold.withValues(alpha: 0.15),
              border: Border.all(
                color: DauVietColors.imperialGold.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              '${index + 1}',
              style: DauVietTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: DauVietColors.inkText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                height: 1.35,
                fontSize: 13.5,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ArrowBtn(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: 'Đưa lên',
                enabled: enabled && index > 0,
                onPressed: onUp,
              ),
              _ArrowBtn(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Đưa xuống',
                enabled: enabled && index < total - 1,
                onPressed: onDown,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _ArrowBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 21),
      color: DauVietColors.cinnabarRed,
      disabledColor: DauVietColors.inkMuted.withValues(alpha: 0.4),
      onPressed: enabled ? onPressed : null,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      tooltip: tooltip,
    );
  }
}
