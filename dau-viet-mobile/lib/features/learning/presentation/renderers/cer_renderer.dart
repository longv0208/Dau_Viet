import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'renderer_base.dart';

/// CER — Claim (Luận điểm) + Evidence (Bằng chứng) + Reasoning (Lập luận).
/// Submit `{claim, evidenceIds[], reasoning}`; server yêu cầu claim+reasoning
/// >= 20 ký tự — client validate tối thiểu đó (server vẫn authoritative).
class CerRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;

  const CerRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
  });

  @override
  State<CerRenderer> createState() => _CerRendererState();
}

class _CerRendererState extends State<CerRenderer> {
  final _claimCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final Set<String> _evidenceIds = {};

  /// Báo player còn input chưa gửi (text/chips) để chặn thoát vô tình.
  void _reportDirty() => widget.onInputChanged?.call(
    _claimCtrl.text.trim().isNotEmpty ||
        _reasonCtrl.text.trim().isNotEmpty ||
        _evidenceIds.isNotEmpty,
  );

  @override
  void dispose() {
    _claimCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _claimCtrl.text.trim().length >= 20 &&
      _reasonCtrl.text.trim().length >= 20;

  @override
  Widget build(BuildContext context) {
    final evidence = widget.content.evidence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          label: 'LUẬN ĐIỂM (CLAIM)',
          hint: 'Bạn kết luận điều gì? (tối thiểu 20 ký tự)',
          controller: _claimCtrl,
        ),
        const SizedBox(height: 12),
        const SectionLabel('BẰNG CHỨNG (EVIDENCE) — CHỌN CÁC NGUỒN HỖ TRỢ'),
        const SizedBox(height: 6),
        if (evidence.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('(Không có bằng chứng nhúng sẵn)'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in evidence)
                FilterChip(
                  label: Text(
                    (e['title'] as String?) ?? (e['id'] as String? ?? ''),
                    style: DauVietTypography.bodySmall,
                  ),
                  selected: _evidenceIds.contains(e['id']),
                  onSelected: widget.submitting
                      ? null
                      : (v) => setState(() {
                          v
                              ? _evidenceIds.add(e['id'] as String)
                              : _evidenceIds.remove(e['id']);
                          _reportDirty();
                        }),
                  selectedColor: DauVietColors.cinnabarRed.withValues(
                    alpha: 0.15,
                  ),
                  checkmarkColor: DauVietColors.cinnabarRed,
                ),
            ],
          ),
        const SizedBox(height: 12),
        _field(
          label: 'LẬP LUẬN (REASONING)',
          hint: 'Vì sao bằng chứng đó ủng hộ luận điểm? (tối thiểu 20 ký tự)',
          controller: _reasonCtrl,
          maxLines: 5,
        ),
        const SizedBox(height: 14),
        SubmitBar(
          enabled: _valid,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({
            'claim': _claimCtrl.text.trim(),
            'evidenceIds': _evidenceIds.toList(),
            'reasoning': _reasonCtrl.text.trim(),
          }),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: !widget.submitting,
          onChanged: (_) => setState(_reportDirty),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: DauVietColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: DauVietColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: DauVietColors.cinnabarRed,
                width: 1.4,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: DauVietTypography.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '${controller.text.trim().length}/20 ký tự tối thiểu',
          style: DauVietTypography.bodySmall.copyWith(
            fontSize: 10,
            color: controller.text.trim().length >= 20
                ? const Color(0xFF4C7C44)
                : DauVietColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
