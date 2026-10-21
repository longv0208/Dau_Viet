import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// REFLECTION_PROMPT — `{text}` (non-empty, <=4000) hoặc `{optionId}` nếu
/// config có `options[]`. Ưu tiên options khi có (contract handler).
class ReflectionRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;

  const ReflectionRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<ReflectionRenderer> createState() => _ReflectionRendererState();
}

class _ReflectionRendererState extends State<ReflectionRenderer> {
  final _textCtrl = TextEditingController();
  String? _optionId;

  void _reportDirty() => widget.onInputChanged?.call(
    _textCtrl.text.trim().isNotEmpty || _optionId != null,
  );

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? prompt = configText(config, ['prompt', 'question', 'text']);
    final options = configList(config, 'options');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prompt != null)
          ActivityCard(
            child: Text(
              prompt,
              style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        const SizedBox(height: 10),
        if (options.isNotEmpty)
          RadioGroup<String>(
            groupValue: _optionId,
            onChanged: widget.submitting
                ? (_) {}
                : (v) => setState(() {
                    _optionId = v;
                    _reportDirty();
                  }),
            child: Column(
              children: [
                for (final opt in options)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      (opt['label'] ?? opt['text'] ?? opt['id']) as String,
                      style: DauVietTypography.bodySmall,
                    ),
                    value: opt['id'] as String? ?? '',
                    activeColor: DauVietColors.cinnabarRed,
                  ),
              ],
            ),
          )
        else
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            maxLength: 4000,
            enabled: !widget.submitting,
            onChanged: (_) => setState(_reportDirty),
            decoration: InputDecoration(
              hintText: 'Chia sẻ suy nghĩ của bạn...',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: DauVietColors.outlineVariant,
                ),
              ),
            ),
            style: DauVietTypography.bodyMedium,
          ),
        const SizedBox(height: 14),
        SubmitBar(
          enabled: options.isNotEmpty
              ? _optionId != null
              : _textCtrl.text.trim().isNotEmpty,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit(
            options.isNotEmpty
                ? {'optionId': _optionId}
                : {'text': _textCtrl.text.trim()},
          ),
        ),
      ],
    );
  }
}
