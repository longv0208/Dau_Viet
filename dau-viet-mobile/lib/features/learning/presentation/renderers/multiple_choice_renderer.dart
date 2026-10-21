import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// MULTIPLE_CHOICE — radio khi `multiSelect=false`, checkbox khi true.
/// Submit `{selectedOptionIds:[...]}`; client KHÔNG biết đáp án đúng.
/// Tile có animation chọn nhẹ, touch target >= 48dp, trạng thái rõ ràng
/// cho single vs multi-select. Giữ nguyên selection khi feedback hiện.
class MultipleChoiceRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;

  const MultipleChoiceRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<MultipleChoiceRenderer> createState() => _MultipleChoiceRendererState();
}

class _MultipleChoiceRendererState extends State<MultipleChoiceRenderer> {
  final Set<String> _selected = {};

  bool get _multi => widget.activity.config['multiSelect'] == true;

  void _tap(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_multi) {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      } else {
        _selected
          ..clear()
          ..add(id);
      }
      widget.onInputChanged?.call(_selected.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? question = configText(config, ['question', 'prompt', 'text']);
    final options = configList(config, 'options');
    // Giảm motion khi người dùng bật reduce-motion — AnimatedContainer
    // duration vẫn giữ 0 vì duration không animate được tự động.
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question != null)
          ActivityCard(
            child: Text(
              question,
              style: DauVietTypography.headlineMedium.copyWith(
                fontSize: 16,
                color: DauVietColors.inkText,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _multi
                ? 'Chọn tất cả đáp án đúng (đã chọn ${_selected.length})'
                : 'Chọn một đáp án',
            style: DauVietTypography.bodySmall.copyWith(
              fontSize: 11,
              color: DauVietColors.inkMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        for (final opt in options)
          _OptionTile(
            id: opt['id'] as String? ?? '',
            label: (opt['label'] ?? opt['text'] ?? '') as String,
            selected: _selected.contains(opt['id']),
            multi: _multi,
            enabled: !widget.submitting,
            reduceMotion: reduceMotion,
            onTap: () => _tap(opt['id'] as String? ?? ''),
          ),
        const SizedBox(height: 14),
        SubmitBar(
          enabled: _selected.isNotEmpty,
          submitting: widget.submitting,
          onPressed: () =>
              widget.onSubmit({'selectedOptionIds': _selected.toList()}),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final bool multi;
  final bool enabled;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _OptionTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.multi,
    required this.enabled,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? DauVietColors.cinnabarRed.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: enabled ? 0.85 : 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.outlineVariant,
                width: selected ? 1.7 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  child: Icon(
                    multi
                        ? (selected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank)
                        : (selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off),
                    key: ValueKey(selected),
                    size: 21,
                    color: selected
                        ? DauVietColors.cinnabarRed
                        : DauVietColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: DauVietTypography.bodyMedium.copyWith(
                      color: enabled
                          ? DauVietColors.inkText
                          : DauVietColors.inkText.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
