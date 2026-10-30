import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/heritage_design_components.dart';
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
        ImperialScrollFrame(
          plaqueTitle: 'DÒNG THỜI GIAN • SẮP XẾP',
          hiddenPlaqueTestText: 'DÒNG THỜI GIAN · SẮP XẾP',
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 2),
                child: Text(
                  'Kéo thả hoặc dùng mũi tên để sắp xếp theo trình tự thời gian',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3A2E25),
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
                  borderRadius: BorderRadius.circular(14),
                  shadowColor: DauVietColors.pixelShadowColor,
                  color: const Color(0xFFFDECC8),
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
            ],
          ),
        ),
        const SizedBox(height: 12),
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
    final bool canUp = index > 0 && enabled;
    final bool canDown = index < total - 1 && enabled;

    return Semantics(
      container: true,
      label: 'Vị trí ${index + 1}: $label',
      child: TactileCard(
        usePixelShadow: false,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        backgroundColor: misplaced
            ? const Color(0xFFFDECC8)
            : const Color(0xFFFAF5E8),
        borderColor: misplaced
            ? const Color(0xFFD99A36)
            : const Color(0xFFDECBA8),
        borderWidth: misplaced ? 1.8 : 1.3,
        borderRadius: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Huy hiệu vòng tròn kép số bước bên trái (khớp ảnh mẫu #5)
            ImperialDoubleCircleBadge(
              stepNumber,
              size: 36,
              color: misplaced
                  ? const Color(0xFFB8781C)
                  : const Color(0xFF1B4332),
              filled: false,
            ),
            const SizedBox(width: 10),

            // 2. Thumbnail sự kiện nếu có image/assetId thật trong config
            if (assetId != null) ...[
              Container(
                width: 58,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD5BF98),
                    width: 1.1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: LearningAssetImage(
                  assetId: assetId!,
                  altText: label,
                  height: 44,
                  fit: BoxFit.cover,
                  tappable: false,
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
                    const SizedBox(height: 5),
                  ],
                  Text(
                    label,
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: const Color(0xFF2B1F17),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1.35,
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

            // 4. Phím điều hướng Accessibility (Lên / Xuống, >= 44x44dp, vòng tròn viền đỏ/mờ khớp ảnh mẫu #5)
            if (total > 1) ...[
              IconButton(
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canUp
                        ? const Color(0xFFFFFDF9)
                        : const Color(0xFFF3ECE0),
                    border: Border.all(
                      color: canUp
                          ? const Color(0xFFC96858)
                          : const Color(0xFFE2D6C3),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 15,
                    color: canUp
                        ? const Color(0xFFA8221B)
                        : const Color(0xFFC5B9A5),
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Di chuyển lên',
                onPressed: canUp ? onUp : null,
              ),
              IconButton(
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canDown
                        ? const Color(0xFFFFFDF9)
                        : const Color(0xFFF3ECE0),
                    border: Border.all(
                      color: canDown
                          ? const Color(0xFFC96858)
                          : const Color(0xFFE2D6C3),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    size: 15,
                    color: canDown
                        ? const Color(0xFFA8221B)
                        : const Color(0xFFC5B9A5),
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'Di chuyển xuống',
                onPressed: canDown ? onDown : null,
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
                    color: Color(0xFF5C4E42),
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
