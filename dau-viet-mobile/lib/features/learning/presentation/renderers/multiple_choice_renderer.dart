import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/dau_viet_typography.dart';
import '../../../../core/widgets/tactile_3d_card.dart';
import '../../../../core/widgets/heritage_design_components.dart';
import '../../data/attempt_dtos.dart';
import 'renderer_base.dart';

/// MULTIPLE_CHOICE — Trắc nghiệm chuẩn UI/UX Pro Max
/// Tự động thích ứng 2 phong cách từ bản thiết kế:
/// 1. Dạng Trắc nghiệm 4 lựa chọn (Screen 2): Thẻ lựa chọn có icon danh mục, viền 3D, tích xanh khi chọn.
/// 2. Dạng Đúng / Sai (Screen 5): Có tranh minh hoạ lịch sử, thẻ nhận định, và 2 nút bấm lớn Đúng / Sai.
class MultipleChoiceRenderer extends StatefulWidget {
  final ActivityRefDto activity;
  final bool submitting;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final void Function(bool hasUnsentInput)? onInputChanged;
  /// Evaluation mới nhất khi retry-in-place (nullable).
  final EvaluationDto? lastEvaluation;
  final SubmitSpecCallback? onSubmitSpec;

  const MultipleChoiceRenderer({
    super.key,
    required this.activity,
    required this.submitting,
    required this.onSubmit,
    this.onInputChanged,
    this.lastEvaluation,
    this.onSubmitSpec,
  });

  @override
  State<MultipleChoiceRenderer> createState() => _MultipleChoiceRendererState();
}

class _MultipleChoiceRendererState extends State<MultipleChoiceRenderer> {
  final Set<String> _selected = {};

  bool get _multi => widget.activity.config['multiSelect'] == true;

  bool _isTrueFalse(List<Map<String, dynamic>> options) {
    if (options.length != 2) return false;
    final l0 = (options[0]['label'] ?? options[0]['text'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final l1 = (options[1]['label'] ?? options[1]['text'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    const tfTokens = {'đúng', 'sai', 'true', 'false', 'yes', 'no'};
    return tfTokens.contains(l0) && tfTokens.contains(l1) && l0 != l1;
  }

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
    notifySubmitSpec(
      callback: widget.onSubmitSpec,
      spec: RendererSubmitSpec(
        enabled: _selected.isNotEmpty,
        label: 'GỬI CÂU TRẢ LỜI',
        payload: () => {'selectedOptionIds': _selected.toList()},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.activity.config;
    final String? question = configText(config, ['question', 'prompt', 'text']);
    final options = configList(config, 'options');
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // Spec nút submit — player pin SubmitBar đáy màn hình.
    emitSubmitSpec(
      callback: widget.onSubmitSpec,
      spec: RendererSubmitSpec(
        enabled: _selected.isNotEmpty,
        label: 'GỬI CÂU TRẢ LỜI',
        payload: () => {'selectedOptionIds': _selected.toList()},
      ),
    );

    // Kiểm tra xem có phải là dạng câu hỏi Đúng / Sai (Screen 5)
    if (_isTrueFalse(options)) {
      return _buildTrueFalseLayout(question, options, reduceMotion);
    }

    // Mặc định: Giao diện trắc nghiệm đa lựa chọn chuẩn Screen 2
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImperialScrollFrame(
          plaqueTitle: 'TRẮC NGHIỆM • TƯ LIỆU',
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (question != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    question,
                    textAlign: TextAlign.left,
                    style: DauVietTypography.headlineMedium.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2B1F17),
                      height: 1.32,
                    ),
                  ),
                ),
              if (_multi)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 2),
                  child: Text(
                    'Chọn tất cả đáp án đúng (đã chọn ${_selected.length})',
                    style: DauVietTypography.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: const Color(0xFF6B5B4B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              for (int i = 0; i < options.length; i++)
                _OptionTile(
                  id: options[i]['id'] as String? ?? '',
                  label:
                      (options[i]['label'] ?? options[i]['text'] ?? '')
                          as String,
                  index: i,
                  selected: _selected.contains(options[i]['id']),
                  multi: _multi,
                  enabled: !widget.submitting,
                  reduceMotion: reduceMotion,
                  onTap: () => _tap(options[i]['id'] as String? ?? ''),
                ),
            ],
          ),
        ),
        if (widget.onSubmitSpec == null) ...[
          const SizedBox(height: 8),
          SubmitBar(
            enabled: _selected.isNotEmpty,
            submitting: widget.submitting,
            onPressed: () =>
                widget.onSubmit({'selectedOptionIds': _selected.toList()}),
          ),
        ],
      ],
    );
  }

  /// Giao diện đặc sắc cho câu hỏi Đúng / Sai (Screen 5 theo mockup)
  Widget _buildTrueFalseLayout(
    String? question,
    List<Map<String, dynamic>> options,
    bool reduceMotion,
  ) {
    // Tìm ID của nút Đúng và Sai
    String trueId = options[0]['id'] as String? ?? '';
    String falseId = options[1]['id'] as String? ?? '';
    final l0 = (options[0]['label'] ?? options[0]['text'] ?? '')
        .toString()
        .toLowerCase();
    if (l0.contains('sai') || l0 == 'false') {
      trueId = options[1]['id'] as String? ?? '';
      falseId = options[0]['id'] as String? ?? '';
    }

    final isTrueSelected = _selected.contains(trueId);
    final isFalseSelected = _selected.contains(falseId);

    final String? imagePath =
        (widget.activity.config['image'] as String?) ??
        (widget.activity.config['illustration'] as String?) ??
        (widget.activity.config['sceneImage'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Tranh minh hoạ di sản sinh động của câu hỏi (nếu có trong config)
        if (imagePath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8C8B0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFF3ECE0),
                    child: const Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Thẻ nhận định lịch sử trang trọng (Parchment Card)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5DAC6), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B4513).withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            question ?? widget.activity.instruction ?? '',
            textAlign: TextAlign.center,
            style: DauVietTypography.headlineMedium.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2421),
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Hai nút xúc giác lớn: Đúng (Xanh lá) và Sai (Đỏ son)
        Row(
          children: [
            // Nút Đúng
            Expanded(
              child: Semantics(
                button: true,
                selected: isTrueSelected,
                enabled: !widget.submitting,
                label: 'Đúng',
                child: GestureDetector(
                  onTap: widget.submitting ? null : () => _tap(trueId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isTrueSelected
                          ? const Color(0xFF2D6A4F)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isTrueSelected
                            ? const Color(0xFF1B4332)
                            : const Color(0xFFA5D6A7),
                        width: isTrueSelected ? 2.2 : 1.2,
                      ),
                      boxShadow: isTrueSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF2D6A4F,
                                ).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: isTrueSelected
                              ? Colors.white
                              : const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Đúng',
                          style: DauVietTypography.labelLarge.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isTrueSelected
                                ? Colors.white
                                : const Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nút Sai
            Expanded(
              child: Semantics(
                button: true,
                selected: isFalseSelected,
                enabled: !widget.submitting,
                label: 'Sai',
                child: GestureDetector(
                  onTap: widget.submitting ? null : () => _tap(falseId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isFalseSelected
                          ? const Color(0xFFC2410C)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFalseSelected
                            ? const Color(0xFF9A3412)
                            : const Color(0xFFFFCDD2),
                        width: isFalseSelected ? 2.2 : 1.2,
                      ),
                      boxShadow: isFalseSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFC2410C,
                                ).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          size: 20,
                          color: isFalseSelected
                              ? Colors.white
                              : const Color(0xFFC62828),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sai',
                          style: DauVietTypography.labelLarge.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isFalseSelected
                                ? Colors.white
                                : const Color(0xFFB71C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4. Thẻ mẹo nhỏ của Kabi phía dưới
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5DAC6), width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hãy suy nghĩ dựa trên những gì bạn đã học nhé!',
                  style: DauVietTypography.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: const Color(0xFF5E6963),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onSubmitSpec == null)
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
  final int index;
  final bool selected;
  final bool multi;
  final bool enabled;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _OptionTile({
    required this.id,
    required this.label,
    required this.index,
    required this.selected,
    required this.multi,
    required this.enabled,
    required this.reduceMotion,
    required this.onTap,
  });

  // Chọn icon minh hoạ phù hợp theo ngữ cảnh hoặc vị trí lựa chọn
  IconData _iconForOption(String label, int idx) {
    final l = label.toLowerCase();
    if (l.contains('sông') ||
        l.contains('nước') ||
        l.contains('thuyền') ||
        l.contains('biển')) {
      return Icons.waves_rounded;
    }
    if (l.contains('núi') || l.contains('rừng') || l.contains('đồi')) {
      return Icons.terrain_rounded;
    }
    if (l.contains('làng') ||
        l.contains('nhà') ||
        l.contains('thành') ||
        l.contains('ấp')) {
      return Icons.cottage_rounded;
    }
    if (l.contains('hang') || l.contains('động')) {
      return Icons.landscape_rounded;
    }
    const fallbackIcons = [
      Icons.cottage_rounded,
      Icons.terrain_rounded,
      Icons.waves_rounded,
      Icons.landscape_rounded,
      Icons.account_balance_rounded,
      Icons.flare_rounded,
    ];
    return fallbackIcons[idx % fallbackIcons.length];
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForOption(label, index);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Tactile3DCard(
          isSelected: selected,
          isEnabled: enabled,
          depth: 3.5,
          borderRadius: BorderRadius.circular(16),
          backgroundColor: selected ? const Color(0xFFF0FDF4) : Colors.white,
          borderColor: selected
              ? const Color(0xFF2D6A4F)
              : const Color(0xFFE5DDD0),
          bottomColor: selected
              ? const Color(0xFF1B4332)
              : const Color(0xFFD6CFC7),
          borderWidth: selected ? 2.0 : 1.2,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon minh hoạ danh mục (chuẩn Screen 2 trong mockup)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2D6A4F).withValues(alpha: 0.15)
                      : const Color(0xFFF5EEDB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2D6A4F)
                        : const Color(0xFFE5DAC6),
                    width: 1,
                  ),
                ),
                child: Icon(
                  iconData,
                  size: 20,
                  color: selected
                      ? const Color(0xFF2D6A4F)
                      : const Color(0xFF8B4513),
                ),
              ),
              const SizedBox(width: 12),

              // Nhãn nội dung đáp án
              Expanded(
                child: Text(
                  label,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: selected
                        ? const Color(0xFF1B4332)
                        : (enabled
                              ? const Color(0xFF1F2421)
                              : const Color(0xFF75807A)),
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),

              // Dấu tích chọn (Checkmark circle)
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: multi ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: multi ? BorderRadius.circular(6) : null,
                  color: selected
                      ? const Color(0xFF2D6A4F)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF2D6A4F)
                        : const Color(0xFFD8C8B0),
                    width: selected ? 2.0 : 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
