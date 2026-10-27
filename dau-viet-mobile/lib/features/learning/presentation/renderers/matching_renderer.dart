import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// MATCHING — Hoạt động ghép cặp kiến thức (Screen 3 chuẩn UI/UX Pro Max)
/// Hiển thị cột trái các nhân vật/hiện vật với tranh chân dung nhỏ,
/// cột phải là các thông tin mô tả kèm điểm neo nối trực quan.
class MatchingRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;

  const MatchingRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<MatchingRenderer> createState() => _MatchingRendererState();
}

class _MatchingRendererState extends State<MatchingRenderer> {
  String? _activeLeft;
  final Map<String, String> _pairs = {}; // leftId -> rightId

  void _dirty() => widget.onInputChanged?.call(_pairs.isNotEmpty);

  void _tapLeft(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_pairs.containsKey(id)) {
        _pairs.remove(id); // unmatch
      } else {
        _activeLeft = _activeLeft == id ? null : id;
      }
      _dirty();
    });
  }

  void _tapRight(String id) {
    if (_activeLeft == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pairs.removeWhere((_, r) => r == id); // right chỉ thuộc 1 cặp
      _pairs[_activeLeft!] = id;
      _activeLeft = null;
      _dirty();
    });
  }

  void _unpairRight(String rightId) {
    setState(() {
      _pairs.removeWhere((_, r) => r == rightId);
      _dirty();
    });
  }

  String? _imageForLeft(String label, String id) {
    final t = (label + ' ' + id).toLowerCase();
    if (t.contains('lạc long quân') || t.contains('long quan')) {
      return 'assets/images/matching_lac_long_quan.png';
    }
    if (t.contains('âu cơ') || t.contains('au co')) {
      return 'assets/images/matching_au_co.png';
    }
    if (t.contains('trống') || t.contains('trong dong')) {
      return 'assets/images/matching_trong_dong.png';
    }
    if (t.contains('văn lang') || t.contains('van lang')) {
      return 'assets/images/matching_van_lang.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final left = configList(config, 'leftItems');
    final right = configList(config, 'rightItems');
    if (left.isEmpty || right.isEmpty) {
      return const ActivityCard(
        child: Text('Hoạt động ghép đôi chưa có dữ liệu.'),
      );
    }
    final Set<String> usedRight = _pairs.values.toSet();
    final bool locked = widget.submitting;
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Right column "snap-to-row": slot i = right da noi voi left[i]
    // (null = cho trong); right chua noi xep duoi giu nguyen thu tu goc —
    // cap nhom gon, de nhin quan he 1-1.
    final rightById = {for (final r in right) (r['id'] as String? ?? ''): r};
    final int rowCount = left.length > right.length
        ? left.length
        : right.length;
    final List<Map<String, dynamic>?> orderedRight =
        List<Map<String, dynamic>?>.filled(rowCount, null);
    for (var i = 0; i < left.length; i++) {
      final rid = _pairs[left[i]['id']];
      if (rid != null && rightById.containsKey(rid)) {
        orderedRight[i] = rightById[rid];
      }
    }
    var nextFree = 0;
    for (final r in right) {
      if (usedRight.contains(r['id'])) continue;
      while (nextFree < rowCount && orderedRight[nextFree] != null) {
        nextFree++;
      }
      if (nextFree < rowCount) orderedRight[nextFree] = r;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            'Ghép mỗi nhân vật, hiện vật với thông tin phù hợp',
            textAlign: TextAlign.center,
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2421),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Danh sách các hàng ghép đôi: 2 thẻ nối chạy lên ngang hàng nhau, tự co giãn theo độ dài văn bản
        for (var i = 0; i < rowCount; i++) ...[
          _buildMatchRow(
            index: i,
            leftItem: i < left.length ? left[i] : null,
            rightItem: orderedRight[i],
            locked: locked,
            reduceMotion: reduceMotion,
            usedRight: usedRight,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Text(
          'Đã ghép ${_pairs.length}/${left.length}',
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            color: _pairs.length == left.length
                ? const Color(0xFF2D6A4F)
                : const Color(0xFF75807A),
            fontWeight: _pairs.length == left.length
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        SubmitBar(
          enabled: _pairs.length == left.length,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({
            'pairs': [
              for (final e in _pairs.entries)
                {'leftId': e.key, 'rightId': e.value},
            ],
          }),
        ),
      ],
    );
  }

  Widget _buildMatchRow({
    required int index,
    required Map<String, dynamic>? leftItem,
    required Map<String, dynamic>? rightItem,
    required bool locked,
    required bool reduceMotion,
    required Set<String> usedRight,
  }) {
    final String? leftId = leftItem?['id'] as String?;
    final String? rightId = rightItem?['id'] as String?;

    // Hàng này được xem là đã ghép nối nếu leftId và rightId đã kết nối với nhau
    final bool isRowPaired =
        leftId != null && rightId != null && _pairs[leftId] == rightId;

    final bool isLeftSelected = leftId != null && _activeLeft == leftId;
    final bool isRightUsed = rightId != null && usedRight.contains(rightId);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thẻ bên trái: Nhân vật / Hiện vật
          Expanded(
            flex: 4,
            child: leftItem != null
                ? _LeftMatchCard(
                    label:
                        (leftItem['label'] ??
                                leftItem['text'] ??
                                leftItem['id'])
                            as String,
                    imageAsset: _imageForLeft(
                      (leftItem['label'] ?? leftItem['text'] ?? '') as String,
                      (leftItem['id'] ?? '') as String,
                    ),
                    selected: isLeftSelected,
                    paired: isRowPaired,
                    enabled: !locked,
                    reduceMotion: reduceMotion,
                    onTap: () {
                      if (leftId != null) _tapLeft(leftId);
                    },
                  )
                : const SizedBox.shrink(),
          ),

          // 2. Điểm neo kết nối giữa hai thẻ trong cùng một hàng
          _ConnectorDot(isPaired: isRowPaired, isActive: isLeftSelected),

          // 3. Thẻ bên phải: Thông tin mô tả đã snap lên ngang hàng với thẻ trái
          Expanded(
            flex: 5,
            child: rightItem != null
                ? _RightMatchCard(
                    label:
                        (rightItem['label'] ??
                                rightItem['text'] ??
                                rightItem['id'])
                            as String,
                    selected: false,
                    paired: isRowPaired,
                    enabled: !locked && (_activeLeft != null || isRightUsed),
                    reduceMotion: reduceMotion,
                    onTap: () {
                      if (rightId == null) return;
                      if (isRightUsed && _activeLeft == null) {
                        _unpairRight(rightId);
                      } else {
                        _tapRight(rightId);
                      }
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ConnectorDot extends StatelessWidget {
  final bool isPaired;
  final bool isActive;

  const _ConnectorDot({required this.isPaired, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final Color dotColor = isPaired
        ? const Color(0xFF2D6A4F)
        : (isActive ? const Color(0xFFC2410C) : const Color(0xFFD8C8B0));

    return SizedBox(
      width: 22,
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: isPaired
                ? [
                    BoxShadow(
                      color: const Color(0xFF2D6A4F).withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _LeftMatchCard extends StatelessWidget {
  final String label;
  final String? imageAsset;
  final bool selected;
  final bool paired;
  final bool enabled;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _LeftMatchCard({
    required this.label,
    this.imageAsset,
    required this.selected,
    required this.paired,
    required this.enabled,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color border = const Color(0xFFE5DAC6);

    if (paired) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFF2D6A4F);
    } else if (selected) {
      bg = const Color(0xFFFFF3E0);
      border = const Color(0xFFE65100);
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border,
            width: (selected || paired) ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B4513).withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ảnh nhân vật/hiện vật hoặc icon thay thế
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 38,
                height: 38,
                child: imageAsset != null
                    ? Image.asset(
                        imageAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackIcon(),
                      )
                    : _fallbackIcon(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: DauVietTypography.bodyMedium.copyWith(
                  fontWeight: (selected || paired)
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontSize: 12.5,
                  color: const Color(0xFF1F2421),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: const Color(0xFFF5EEDB),
      child: const Icon(
        Icons.account_balance_rounded,
        size: 20,
        color: Color(0xFFB45309),
      ),
    );
  }
}

class _RightMatchCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool paired;
  final bool enabled;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _RightMatchCard({
    required this.label,
    required this.selected,
    required this.paired,
    required this.enabled,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color border = const Color(0xFFE5DAC6);

    if (paired) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFF2D6A4F);
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: paired ? 1.8 : 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B4513).withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: DauVietTypography.bodySmall.copyWith(
            fontWeight: paired ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11.5,
            color: paired ? const Color(0xFF1B4332) : const Color(0xFF3D4842),
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
