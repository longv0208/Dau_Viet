import 'package:flutter/material.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// REASONING_CONNECT — nối các `nodes[]` bằng quan hệ trong
/// `allowedRelations[]`. Submit `{relations:[{from,to,relation}]}`.
class ReasoningConnectRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  const ReasoningConnectRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  State<ReasoningConnectRenderer> createState() =>
      _ReasoningConnectRendererState();
}

class _ReasoningConnectRendererState extends State<ReasoningConnectRenderer> {
  String? _from;
  String? _to;
  String? _relation;
  final List<Map<String, String>> _relations = [];

  void _add() {
    if (_from == null || _to == null || _relation == null) return;
    setState(() {
      _relations.add({'from': _from!, 'to': _to!, 'relation': _relation!});
      _from = null;
      _to = null;
      _relation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? prompt = configText(config, ['prompt', 'question']);
    final nodes = configList(config, 'nodes');
    final rels = configList(config, 'allowedRelations');

    String nodeLabel(String? id) {
      for (final n in nodes) {
        if (n['id'] == id) return (n['label'] ?? n['text'] ?? id) as String;
      }
      return id ?? '';
    }

    if (nodes.isEmpty || rels.isEmpty) {
      return const ActivityCard(
        child: Text('Hoạt động kết nối lập luận chưa có dữ liệu.'),
      );
    }

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
        const SectionLabel('TẠO LIÊN KẾT LẬP LUẬN'),
        const SizedBox(height: 6),
        _dropdown(
          hint: 'Từ',
          value: _from,
          items: [
            for (final n in nodes)
              DropdownMenuItem(
                value: n['id'] as String?,
                child: Text(
                  (n['label'] ?? n['text'] ?? n['id']) as String,
                  style: DauVietTypography.bodySmall,
                ),
              ),
          ],
          onChanged: (v) => setState(() => _from = v),
        ),
        const SizedBox(height: 8),
        _dropdown(
          hint: 'Quan hệ',
          value: _relation,
          items: [
            for (final r in rels)
              DropdownMenuItem(
                value: r['id'] as String? ?? r['label'] as String?,
                child: Text(
                  (r['label'] ?? r['id']) as String,
                  style: DauVietTypography.bodySmall,
                ),
              ),
          ],
          onChanged: (v) => setState(() => _relation = v),
        ),
        const SizedBox(height: 8),
        _dropdown(
          hint: 'Đến',
          value: _to,
          items: [
            for (final n in nodes)
              DropdownMenuItem(
                value: n['id'] as String?,
                child: Text(
                  (n['label'] ?? n['text'] ?? n['id']) as String,
                  style: DauVietTypography.bodySmall,
                ),
              ),
          ],
          onChanged: (v) => setState(() => _to = v),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed:
                widget.submitting ||
                    _from == null ||
                    _to == null ||
                    _relation == null
                ? null
                : _add,
            icon: const Icon(Icons.add_link, size: 18),
            label: const Text('Thêm liên kết'),
            style: TextButton.styleFrom(
              foregroundColor: DauVietColors.cinnabarRed,
            ),
          ),
        ),
        if (_relations.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (int i = 0; i < _relations.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DauVietColors.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${nodeLabel(_relations[i]['from'])} '
                      '—${_relations[i]['relation']}→ '
                      '${nodeLabel(_relations[i]['to'])}',
                      style: DauVietTypography.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: DauVietColors.inkMuted,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.submitting
                        ? null
                        : () => setState(() => _relations.removeAt(i)),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 10),
        SubmitBar(
          enabled: _relations.isNotEmpty,
          submitting: widget.submitting,
          onPressed: () => widget.onSubmit({'relations': _relations}),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(hint, style: DauVietTypography.bodySmall),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DauVietColors.outlineVariant),
        ),
      ),
      items: items,
      onChanged: widget.submitting ? null : onChanged,
    );
  }
}
