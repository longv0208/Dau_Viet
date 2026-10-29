import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'learning_asset_image.dart';
import 'renderer_base.dart';

/// CER — Claim (Luận điểm) + Evidence (Bằng chứng) + Reasoning (Lập luận).
/// Submit `{claim, evidenceIds[], reasoning}`; server yêu cầu claim+reasoning
/// >= 20 ký tự — client validate tối thiểu đó (server vẫn authoritative).
/// Text giữ nguyên khi chọn/bỏ chọn evidence và khi lỗi mạng (controller
/// không bị reset).
class CerRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;

  const CerRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
  });

  @override
  State<CerRenderer> createState() => _CerRendererState();
}

class _CerRendererState extends State<CerRenderer> {
  final _claimCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _claimFocus = FocusNode();
  final _reasonFocus = FocusNode();
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
    _claimFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  bool get _valid =>
      _claimCtrl.text.trim().length >= 20 &&
      _reasonCtrl.text.trim().length >= 20;

  @override
  Widget build(BuildContext context) {
    final evidence = widget.content.evidence;
    final bool locked = widget.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          label: 'LUẬN ĐIỂM (CLAIM)',
          hint: 'Bạn kết luận điều gì? (tối thiểu 20 ký tự)',
          controller: _claimCtrl,
          focusNode: _claimFocus,
          nextFocus: _reasonFocus,
          locked: locked,
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
          // Evidence chips — chọn/bỏ chọn không đụng vào text đã viết.
          Column(
            children: [for (final e in evidence) _evidenceTile(e, locked)],
          ),
        const SizedBox(height: 12),
        _field(
          label: 'LẬP LUẬN (REASONING)',
          hint: 'Vì sao bằng chứng đó ủng hộ luận điểm? (tối thiểu 20 ký tự)',
          controller: _reasonCtrl,
          focusNode: _reasonFocus,
          maxLines: 5,
          locked: locked,
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

  String? _imageAssetId(Map<String, dynamic> e) {
    final raw = e['imageAssetId'] ?? e['assetId'] ?? e['imageId'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  Widget _evidenceTile(Map<String, dynamic> e, bool locked) {
    final String id = e['id'] as String? ?? '';
    final bool selected = _evidenceIds.contains(id);
    final String title = (e['title'] as String?) ?? id;
    final String? assetId = _imageAssetId(e);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: locked
            ? null
            : () => setState(() {
                selected ? _evidenceIds.remove(id) : _evidenceIds.add(id);
                _reportDirty();
              }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? DauVietColors.cinnabarRed.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (assetId != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: LearningAssetImage(
                      assetId: assetId,
                      altText: title,
                      height: 40,
                      fit: BoxFit.cover,
                      tappable: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? DauVietColors.cinnabarRed
                    : DauVietColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool locked,
    FocusNode? nextFocus,
    int maxLines = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: maxLines,
          enabled: !locked,
          textInputAction: nextFocus != null
              ? TextInputAction.next
              : TextInputAction.done,
          onSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              focusNode.unfocus();
            }
          },
          onChanged: (_) => setState(_reportDirty),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DauVietTypography.bodySmall.copyWith(
              color: DauVietColors.inkMuted,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: locked ? 0.6 : 0.9),
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
          style: DauVietTypography.bodyMedium.copyWith(height: 1.55),
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
