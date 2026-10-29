import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_colors.dart';
import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/chapter_number_badge.dart';
import '../../../../core/widgets/clue_tag.dart';
import '../../../../core/widgets/section_eyebrow.dart';
import '../../../../core/widgets/stamp_seal_badge.dart';
import '../../../../core/widgets/tactile_card.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// REASONING_CONNECT — nối các `nodes[]` bằng quan hệ nhân quả trong
/// `allowedRelations[]`. Submit `{relations:[{from,to,relation}]}`.
class ReasoningConnectRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;

  const ReasoningConnectRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
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

  void _dirty() => widget.onInputChanged?.call(
    _relations.isNotEmpty || _from != null || _to != null || _relation != null,
  );

  void _add() {
    if (_from == null || _to == null || _relation == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _relations.add({'from': _from!, 'to': _to!, 'relation': _relation!});
      _from = null;
      _to = null;
      _relation = null;
      _dirty();
    });
  }

  void _tapNode(String id, List<Map<String, dynamic>> rels) {
    if (widget.submitting) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_from == null) {
        _from = id;
      } else if (_from == id) {
        _from = null;
      } else {
        _to = id;
        if (_relation == null && rels.isNotEmpty) {
          _relation =
              rels.first['id'] as String? ?? rels.first['label'] as String?;
        }
      }
      _dirty();
    });
  }

  bool get _hasWrongEval {
    final eval = widget.lastEvaluation;
    if (eval == null || eval.completed) return false;
    final outcome = eval.outcome;
    return outcome == 'INCORRECT' || outcome == 'PARTIAL';
  }

  bool _isNodeConnected(String id) {
    for (final r in _relations) {
      if (r['from'] == id || r['to'] == id) return true;
    }
    return false;
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

    String relLabel(String? id) {
      for (final r in rels) {
        final rId = r['id'] as String? ?? r['label'] as String?;
        if (rId == id) return (r['label'] ?? r['text'] ?? id) as String;
      }
      return id ?? '';
    }

    if (nodes.isEmpty || rels.isEmpty) {
      return const ActivityCard(
        child: Text('Hoạt động kết nối lập luận chưa có dữ liệu.'),
      );
    }

    final bool wrong = _hasWrongEval;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: SectionEyebrow('MỐI LIÊN HỆ · SUY LUẬN'),
        ),
        const SizedBox(height: 10),
        if (prompt != null) ...[
          ActivityCard(
            child: Text(
              prompt,
              style: DauVietTypography.bodyMedium.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Danh sách các Node suy luận
        const SectionLabel('CÁC MẤU CHỐT SỰ KIỆN (NODES)'),
        const SizedBox(height: 8),
        for (int i = 0; i < nodes.length; i++) ...[
          Builder(
            builder: (context) {
              final n = nodes[i];
              final String id = n['id'] as String? ?? 'node-$i';
              final String label = (n['label'] ?? n['text'] ?? id) as String;
              final bool connected = _isNodeConnected(id);
              final bool isFrom = _from == id;
              final bool isTo = _to == id;
              final bool active = isFrom || isTo;

              Color borderColor = DauVietColors.outlineVariant;
              if (wrong && connected) {
                borderColor = DauVietColors.cinnabarRed;
              } else if (active || connected) {
                borderColor = DauVietColors.jade;
              }

              return TactileCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                borderRadius: 12,
                enabled: !widget.submitting,
                backgroundColor: (active || connected)
                    ? DauVietColors.paperCardHi
                    : DauVietColors.paperCard,
                borderColor: borderColor,
                borderWidth: (active || connected || wrong) ? 1.8 : 1.4,
                onTap: () => _tapNode(id, rels),
                child: Row(
                  children: [
                    ChapterNumberBadge(
                      (i + 1).toString().padLeft(2, '0'),
                      size: 32,
                      color: wrong && connected
                          ? DauVietColors.cinnabarRed
                          : (active || connected
                                ? DauVietColors.jade
                                : DauVietColors.chapterGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: DauVietColors.inkText,
                          fontWeight: (active || connected)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isFrom)
                      const ClueTag('Từ', color: DauVietColors.jade)
                    else if (isTo)
                      const ClueTag(
                        'Đến',
                        color: DauVietColors.imperialGoldDark,
                      ),
                    if (connected) ...[
                      const SizedBox(width: 6),
                      StampSealBadge(
                        '✓',
                        size: 24,
                        color: wrong
                            ? DauVietColors.cinnabarRed
                            : DauVietColors.jade,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 8),
        TactileCard(
          padding: const EdgeInsets.all(14),
          backgroundColor: DauVietColors.paperCard,
          borderColor: wrong
              ? DauVietColors.cinnabarRed
              : DauVietColors.outlineVariant,
          borderWidth: wrong ? 1.8 : 1.4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('TẠO LIÊN KẾT LẬP LUẬN'),
              const SizedBox(height: 8),
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
                onChanged: (v) => setState(() {
                  _from = v;
                  _dirty();
                }),
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
                onChanged: (v) => setState(() {
                  _relation = v;
                  _dirty();
                }),
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
                onChanged: (v) => setState(() {
                  _to = v;
                  _dirty();
                }),
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
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_relations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionLabel('CÁC MỐI LIÊN HỆ ĐÃ NỐI'),
          const SizedBox(height: 6),
          for (int i = 0; i < _relations.length; i++)
            TactileCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderRadius: 12,
              backgroundColor: DauVietColors.paperCardHi,
              borderColor: wrong
                  ? DauVietColors.cinnabarRed
                  : DauVietColors.jade,
              borderWidth: 1.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StampSealBadge(
                        '✓',
                        size: 24,
                        color: wrong
                            ? DauVietColors.cinnabarRed
                            : DauVietColors.jade,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${nodeLabel(_relations[i]['from'])} '
                          '—${relLabel(_relations[i]['relation'])}→ '
                          '${nodeLabel(_relations[i]['to'])}',
                          style: DauVietTypography.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DauVietColors.inkText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: DauVietColors.inkMuted,
                        tooltip: 'Xóa liên kết',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: widget.submitting
                            ? null
                            : () => setState(() {
                                _relations.removeAt(i);
                                _dirty();
                              }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 12,
                    child: CustomPaint(
                      painter: _RelationEdgePainter(
                        color: wrong
                            ? DauVietColors.cinnabarRed
                            : DauVietColors.jade,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        InlineGradingHint(
          evaluation: widget.lastEvaluation,
          maxAttempts: widget.activity.maxAttempts,
        ),
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
        fillColor: DauVietColors.paperCardHi,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DauVietColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: DauVietColors.outlineVariant),
        ),
      ),
      items: items,
      onChanged: widget.submitting ? null : onChanged,
    );
  }
}

/// CustomPainter vẽ đường nối quan hệ nhân quả 2px màu `jade` kèm mũi tên.
class _RelationEdgePainter extends CustomPainter {
  final Color color;
  const _RelationEdgePainter({this.color = DauVietColors.jade});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final double cy = size.height / 2;
    canvas.drawLine(Offset(4, cy), Offset(size.width - 4, cy), paint);
    final Path arrow = Path()
      ..moveTo(size.width - 10, cy - 4)
      ..lineTo(size.width - 4, cy)
      ..lineTo(size.width - 10, cy + 4);
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(covariant _RelationEdgePainter oldDelegate) =>
      oldDelegate.color != color;
}
