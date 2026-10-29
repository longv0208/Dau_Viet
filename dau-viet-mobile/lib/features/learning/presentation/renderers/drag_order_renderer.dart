import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/chapter_number_badge.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/section_eyebrow.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import 'learning_asset_image.dart';
import 'renderer_base.dart';

/// DRAG_ORDER — Timeline Chiến trận: sắp xếp sự kiện theo trình tự thời gian.
/// Mỗi mốc là [TactileCard] gắn [ChapterNumberBadge], [SectionEyebrow] mốc
/// thời gian, thumbnail [LearningAssetImage] (nếu có) và [ClueTag] báo vị trí
/// cần đổi chỗ khi nhận phản hồi retry-in-place.
class DragOrderRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;

  const DragOrderRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
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

  String? _itemTimeLabel(Map<String, dynamic> item) =>
      configText(item, const ['timeLabel', 'phase', 'epoch']);

  String? _itemAssetId(Map<String, dynamic> item) =>
      configText(item, const ['imageAssetId', 'assetId', 'imageId', 'image']);

  bool _isMisplaced(int index, String id) {
    final eval = widget.lastEvaluation;
    if (eval == null || eval.completed) return false;
    final outcome = eval.outcome;
    if (outcome == 'COMPLETED' || outcome == 'SUPPORTED') return false;
    final out = eval.output;
    if (out != null) {
      final wrongIds = out['incorrectIds'] ?? out['wrongIds'];
      if (wrongIds is List) {
        return wrongIds.whereType<String>().contains(id);
      }
      final wrongIdx = out['incorrectIndices'] ?? out['wrongPositions'];
      if (wrongIdx is List) {
        return wrongIdx.whereType<num>().map((e) => e.toInt()).contains(index);
      }
      final correctIds = out['correctIds'];
      if (correctIds is List) {
        return !correctIds.whereType<String>().contains(id);
      }
    }
    final cp = eval.correctPositions;
    final ti = eval.totalItems;
    if (cp != null && ti != null && cp < ti) {
      return index >= cp;
    }
    return outcome == 'INCORRECT' || outcome == 'PARTIAL';
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
        const Align(
          alignment: Alignment.centerLeft,
          child: SectionEyebrow('DÒNG THỜI GIAN · SẮP XẾP'),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            'Kéo thả hoặc dùng mũi tên để sắp xếp theo trình tự thời gian',
            style: DauVietTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: DauVietColors.inkSecondary,
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
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            shadowColor: DauVietColors.pixelShadowColor,
            color: DauVietColors.paperCard,
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
              timeLabel: _itemTimeLabel(item),
              assetId: _itemAssetId(item),
              misplaced: _isMisplaced(i, id),
              enabled: !widget.submitting,
              onUp: () => _move(i, -1),
              onDown: () => _move(i, 1),
            );
          },
        ),
        const SizedBox(height: 16),
        InlineGradingHint(
          evaluation: widget.lastEvaluation,
          maxAttempts: widget.activity.maxAttempts,
        ),
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
  final String? timeLabel;
  final String? assetId;
  final bool misplaced;
  final bool enabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _OrderTile({
    super.key,
    required this.index,
    required this.total,
    required this.label,
    this.timeLabel,
    this.assetId,
    this.misplaced = false,
    required this.enabled,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final String stepNumber = (index + 1).toString().padLeft(2, '0');
    return Semantics(
      container: true,
      label: 'Vị trí ${index + 1}: $label',
      child: TactileCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        backgroundColor: misplaced
            ? DauVietColors.paperCardHi
            : DauVietColors.paperCard,
        borderColor: misplaced
            ? DauVietColors.imperialGoldDark
            : DauVietColors.outlineVariant,
        borderWidth: misplaced ? 1.8 : 1.4,
        borderRadius: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Huy hiệu số bước pixel bên trái
            ChapterNumberBadge(
              stepNumber,
              size: 36,
              color: misplaced
                  ? DauVietColors.imperialGoldDark
                  : DauVietColors.chapterGreen,
            ),
            const SizedBox(width: 10),

            // 2. Thumbnail sự kiện nếu có image/assetId
            if (assetId != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: LearningAssetImage(
                    assetId: assetId!,
                    altText: label,
                    height: 44,
                    fit: BoxFit.cover,
                    tappable: false,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // 3. Nội dung mốc thời gian + sự kiện + tag phản hồi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (timeLabel != null) ...[
                    SectionEyebrow(
                      timeLabel!,
                      color: DauVietColors.jade,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      showShadow: false,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    label,
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: DauVietColors.inkText,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  if (misplaced) ...[
                    const SizedBox(height: 6),
                    const ClueTag(
                      'Cần đổi chỗ',
                      icon: Icons.swap_vert_rounded,
                      color: DauVietColors.imperialGoldDark,
                    ),
                  ],
                ],
              ),
            ),

            // 4. Phím điều hướng Accessibility (Lên / Xuống, >= 44x44dp)
            if (total > 1) ...[
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                color: index > 0 && enabled
                    ? DauVietColors.inkSecondary
                    : DauVietColors.inkLight.withValues(alpha: 0.4),
                tooltip: 'Di chuyển lên',
                onPressed: index > 0 && enabled ? onUp : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                color: index < total - 1 && enabled
                    ? DauVietColors.inkSecondary
                    : DauVietColors.inkLight.withValues(alpha: 0.4),
                tooltip: 'Di chuyển xuống',
                onPressed: index < total - 1 && enabled ? onDown : null,
              ),
            ],

            // 5. Biểu tượng tay nắm kéo thả (>= 44x44dp)
            ReorderableDragStartListener(
              index: index,
              enabled: enabled,
              child: Semantics(
                label: 'Kéo để đổi vị trí $label',
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.drag_handle,
                    size: 22,
                    color: DauVietColors.inkMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
