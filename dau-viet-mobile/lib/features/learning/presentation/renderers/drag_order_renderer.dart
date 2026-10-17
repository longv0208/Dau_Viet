import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// DRAG_ORDER — sắp xếp `items[]` theo đúng trình tự lịch sử.
/// Items đến đã được server shuffle deterministic (learner presentation).
/// ReorderableListView + nút lên/xuống accessibility. Submit `{orderedIds}`.
/// KHÔNG sort lại theo answer key; không expose expectedOrder/acceptedSequences.
class DragOrderRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const DragOrderRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<DragOrderRenderer> createState() => _DragOrderRendererState();
}

class _DragOrderRendererState extends State<DragOrderRenderer> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    // Giữ nguyên thứ tự server gửi — KHÔNG sort lại.
    _items = List.of(configList(widget.activity.config, 'items'));
  }

  void _move(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
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
            setState(() {
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
          },
          itemBuilder: (context, i) {
            final item = _items[i];
            final String id = item['id'] as String? ?? 'item-$i';
            return _OrderTile(
              key: ValueKey(id),
              index: i,
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
  final String label;
  final bool enabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _OrderTile({
    super.key,
    required this.index,
    required this.label,
    required this.enabled,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DauVietColors.outlineVariant),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            enabled: enabled,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: DauVietColors.inkMuted,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
            color: DauVietColors.cinnabarRed,
            onPressed: enabled ? onUp : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'Đưa lên',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
            color: DauVietColors.cinnabarRed,
            onPressed: enabled ? onDown : null,
            visualDensity: VisualDensity.compact,
            tooltip: 'Đưa xuống',
          ),
        ],
      ),
    );
  }
}
