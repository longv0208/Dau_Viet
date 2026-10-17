import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// MULTIPLE_CHOICE — radio khi `multiSelect=false`, checkbox khi true.
/// Submit `{selectedOptionIds:[...]}`; client KHÔNG biết đáp án đúng.
class MultipleChoiceRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const MultipleChoiceRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<MultipleChoiceRenderer> createState() => _MultipleChoiceRendererState();
}

class _MultipleChoiceRendererState extends State<MultipleChoiceRenderer> {
  final Set<String> _selected = {};

  bool get _multi => widget.activity.config['multiSelect'] == true;

  void _tap(String id) {
    setState(() {
      if (_multi) {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      } else {
        _selected
          ..clear()
          ..add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? question = configText(config, ['question', 'prompt', 'text']);
    final options = configList(config, 'options');

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
        const SizedBox(height: 10),
        for (final opt in options)
          _OptionTile(
            id: opt['id'] as String? ?? '',
            label: (opt['label'] ?? opt['text'] ?? '') as String,
            selected: _selected.contains(opt['id']),
            multi: _multi,
            enabled: !widget.submitting,
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
  final VoidCallback onTap;

  const _OptionTile({
    required this.id,
    required this.label,
    required this.selected,
    required this.multi,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? DauVietColors.cinnabarRed.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                multi
                    ? (selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank)
                    : (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off),
                size: 20,
                color: selected
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.inkMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: DauVietColors.inkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
