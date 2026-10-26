import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// DRAG_ORDER — Sắp xếp sự kiện theo đúng trình tự thời gian (Screen 4 chuẩn UI/UX Pro Max)
/// Hiển thị huy hiệu số xanh lá tròn, thumbnail sự kiện, tay kéo thả `⋮⋮` và nút điều hướng tiếp cận.
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
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            'Kéo thả hoặc dùng mũi tên để sắp xếp theo trình tự thời gian',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5E6963),
            ),
          ),
        ),
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
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            shadowColor: const Color(0xFF8B4513).withValues(alpha: 0.25),
            color: Colors.white,
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
        const SizedBox(height: 16),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5DAC6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Huy hiệu số thứ tự tròn xanh lá (Screen 4 theo mockup)
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2D6A4F),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Nội dung sự kiện
          Expanded(
            child: Text(
              label,
              style: DauVietTypography.bodyMedium.copyWith(
                color: const Color(0xFF1F2421),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),

          // 3. Phím điều hướng Accessibility (Lên / Xuống)
          if (total > 1) ...[
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: index > 0 && enabled
                  ? const Color(0xFF5E6963)
                  : Colors.black12,
              tooltip: 'Di chuyển lên',
              onPressed: index > 0 && enabled ? onUp : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: index < total - 1 && enabled
                  ? const Color(0xFF5E6963)
                  : Colors.black12,
              tooltip: 'Di chuyển xuống',
              onPressed: index < total - 1 && enabled ? onDown : null,
            ),
          ],

          // 4. Biểu tượng tay nắm kéo thả `⋮⋮`
          ReorderableDragStartListener(
            index: index,
            enabled: enabled,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: const Icon(
                Icons.drag_indicator_rounded,
                size: 22,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
