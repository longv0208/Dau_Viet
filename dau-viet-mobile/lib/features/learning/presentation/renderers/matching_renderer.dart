import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// MATCHING — ghép `leftItems[]` với `rightItems[]` (đã derange phía server).
/// Tap left → tap right để nối; tap lại left-paired để hủy cặp; tap right
/// đã dùng khi không có left nào đang chọn → hủy cặp chứa nó.
/// Submit `{pairs:[{leftId,rightId}]}`. KHÔNG dùng `config.pairs` (đã bị
/// strip khỏi learner projection), không suy đáp án từ thứ tự hàng.
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
    // cap nhom gon, de nhin quan he 1-1. left.length == right.length.
    final rightById = {for (final r in right) (r['id'] as String? ?? ''): r};
    final int rowCount = left.length;
    final List<Map<String, dynamic>?> orderedRight =
        List<Map<String, dynamic>?>.filled(rowCount, null);
    for (var i = 0; i < rowCount; i++) {
      final rid = _pairs[left[i]['id']];
      if (rid != null) orderedRight[i] = rightById[rid];
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
        const SectionLabel('CHẠM MỤC TRÁI RỒI CHẠM MỤC PHẢI ĐỂ GHÉP'),
        const SizedBox(height: 4),
        Text(
          'Chạm lại mục đã ghép để hủy.',
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: DauVietColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        // Mot Row moi hang: left | dot | right cung truc ngang, tile cao
        // hon dinh chieu hang — cap da noi luon nam ngang nhau.
        for (var i = 0; i < rowCount; i++)
          _PairRow(
            left: _MatchTile(
              label:
                  (left[i]['label'] ?? left[i]['text'] ?? left[i]['id'])
                      as String,
              selected: _activeLeft == left[i]['id'],
              paired: _pairs.containsKey(left[i]['id']),
              enabled: !locked,
              reduceMotion: reduceMotion,
              onTap: () => _tapLeft(left[i]['id'] as String? ?? ''),
            ),
            dot: _PairDot(
              linked: _pairs.containsKey(left[i]['id']),
              seeking: _activeLeft == left[i]['id'],
              reduceMotion: reduceMotion,
            ),
            right: orderedRight[i] == null
                ? const _EmptySlot()
                : _MatchTile(
                    key: ValueKey(orderedRight[i]!['id']),
                    label:
                        (orderedRight[i]!['label'] ??
                                orderedRight[i]!['text'] ??
                                orderedRight[i]!['id'])
                            as String,
                    selected: false,
                    paired: usedRight.contains(orderedRight[i]!['id']),
                    alignEnd: true,
                    // Ngoặc bắt buộc: không có chúng, `|| usedRight` vẫn cho
                    // tap khi đang submitting (precedence fix).
                    enabled:
                        !locked &&
                        (_activeLeft != null ||
                            usedRight.contains(orderedRight[i]!['id'])),
                    reduceMotion: reduceMotion,
                    onTap: () {
                      if (usedRight.contains(orderedRight[i]!['id']) &&
                          _activeLeft == null) {
                        _unpairRight(orderedRight[i]!['id'] as String? ?? '');
                      } else {
                        _tapRight(orderedRight[i]!['id'] as String? ?? '');
                      }
                    },
                  ),
          ),
        const SizedBox(height: 10),
        Text(
          'Đã ghép ${_pairs.length}/${left.length}',
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            color: _pairs.length == left.length
                ? const Color(0xFF4C7C44)
                : DauVietColors.inkMuted,
            fontWeight: _pairs.length == left.length
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
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
}

class _MatchTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool paired;
  final bool enabled;
  final bool alignEnd;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _MatchTile({
    super.key,
    required this.label,
    required this.selected,
    required this.paired,
    required this.enabled,
    required this.reduceMotion,
    required this.onTap,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = selected
        ? DauVietColors.imperialGold
        : paired
        ? DauVietColors.cinnabarRed
        : DauVietColors.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: double.infinity,
            // height: double.infinity de tile gian bang chieu cao hang
            // (IntrinsicHeight cua _PairRow) — 2 tile cap ngang nhau.
            height: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? DauVietColors.imperialGold.withValues(alpha: 0.16)
                  : paired
                  ? DauVietColors.cinnabarRed.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: enabled ? 0.85 : 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: selected ? 1.9 : 1.1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: DauVietColors.imperialGold.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkText,
                height: 1.35,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mot hang left | dot | right — IntrinsicHeight de 2 tile cung chieu cao
/// hang, dot can giua truc doc: cap da noi luon ngang nhau ke ca khi noi
/// dung left/right chenh chieu cao.
class _PairRow extends StatelessWidget {
  final Widget left;
  final Widget dot;
  final Widget right;

  const _PairRow({required this.left, required this.dot, required this.right});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          SizedBox(width: 26, child: Center(child: dot)),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// O trong o cot phai khi left chua noi — giu dung chieu cao tile de hang
/// khong nhay khi right snap vao.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
      ),
    );
  }
}

/// Chấm nối giữa hai cột — sáng khi cặp đã link, pulse nhẹ khi đang chờ
/// chọn đầu phải.
class _PairDot extends StatelessWidget {
  final bool linked;
  final bool seeking;
  final bool reduceMotion;

  const _PairDot({
    required this.linked,
    required this.seeking,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    // Dot da duoc Center cua _PairRow can giua truc doc — khong can padding.
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      width: linked || seeking ? 12 : 8,
      height: linked || seeking ? 12 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: linked
            ? DauVietColors.cinnabarRed
            : seeking
            ? DauVietColors.imperialGold
            : DauVietColors.outlineVariant.withValues(alpha: 0.7),
        boxShadow: seeking && !reduceMotion
            ? [
                BoxShadow(
                  color: DauVietColors.imperialGold.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
