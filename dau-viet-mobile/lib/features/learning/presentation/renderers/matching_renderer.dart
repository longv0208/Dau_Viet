import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// MATCHING — ghép `leftItems[]` với `rightItems[]` (đã derange phía server).
/// Tap left → tap right để nối; tap lại để hủy. Submit `{pairs:[{leftId,rightId}]}`.
/// KHÔNG dùng `config.pairs` (đã bị strip khỏi learner projection).
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
    setState(() {
      if (_pairs.containsKey(id)) {
        _pairs.remove(id); // unmatch
      } else {
        _activeLeft = id;
      }
      _dirty();
    });
  }

  void _tapRight(String id) {
    if (_activeLeft == null) return;
    setState(() {
      _pairs.removeWhere((_, r) => r == id); // right chỉ thuộc 1 cặp
      _pairs[_activeLeft!] = id;
      _activeLeft = null;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('CHẠM MỤC TRÁI RỒI CHẠM MỤC PHẢI ĐỂ GHÉP'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final item in left)
                    _MatchTile(
                      label:
                          (item['label'] ?? item['text'] ?? item['id'])
                              as String,
                      selected: _activeLeft == item['id'],
                      paired: _pairs.containsKey(item['id']),
                      enabled: !widget.submitting,
                      onTap: () => _tapLeft(item['id'] as String? ?? ''),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final item in right)
                    _MatchTile(
                      label:
                          (item['label'] ?? item['text'] ?? item['id'])
                              as String,
                      selected: false,
                      paired: usedRight.contains(item['id']),
                      alignEnd: true,
                      enabled:
                          !widget.submitting && _activeLeft != null ||
                          usedRight.contains(item['id']),
                      onTap: () {
                        if (usedRight.contains(item['id']) &&
                            _activeLeft == null) {
                          setState(() {
                            _pairs.removeWhere((_, r) => r == item['id']);
                            _dirty();
                          });
                        } else {
                          _tapRight(item['id'] as String? ?? '');
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Đã ghép ${_pairs.length}/${left.length}',
          textAlign: TextAlign.center,
          style: DauVietTypography.bodySmall.copyWith(
            color: DauVietColors.inkMuted,
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
  final VoidCallback onTap;

  const _MatchTile({
    required this.label,
    required this.selected,
    required this.paired,
    required this.enabled,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? DauVietColors.imperialGold.withValues(alpha: 0.15)
                : paired
                ? DauVietColors.cinnabarRed.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 1.8 : 1.1),
          ),
          child: Text(
            label,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkText,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
