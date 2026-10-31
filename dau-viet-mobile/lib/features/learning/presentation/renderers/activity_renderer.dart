import 'package:flutter/material.dart';

import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
import 'cer_choice_renderer.dart';
import 'cer_renderer.dart';
import 'drag_order_renderer.dart';
import 'evidence_select_renderer.dart';
import 'explore_map_renderer.dart';
import 'hypothesis_renderer.dart';
import 'matching_renderer.dart';
import 'multiple_choice_renderer.dart';
import 'read_renderer.dart';
import 'reasoning_connect_renderer.dart';
import 'reflection_renderer.dart';
import 'unsupported_renderer.dart';
import 'renderer_base.dart';
import 'verification_renderer.dart';
import 'view_image_renderer.dart';

/// Dispatch activity → renderer theo `activity.type`.
/// Renderer nhận learner-safe config + snapshot embeds và gọi [onSubmit]
/// với answer payload đúng contract server. Không renderer nào chứa
/// answer key hay tự chấm điểm phía client.
class ActivityRenderer extends StatelessWidget {
  final ActivityRefDto activity;
  final LessonContentDto content;
  final bool submitting;
  final bool hasSubmitError;
  final Future<void> Function(Map<String, dynamic> answer) onSubmit;

  /// Optional — renderer báo learner có input chưa gửi (dirty) để player
  /// chặn thoát/khôi phục draft. Chỉ renderer nhập liệu tự do mới gọi.
  final void Function(bool hasUnsentInput)? onInputChanged;

  /// Issue #1-immersive: renderer báo đang ở chế độ immersive (màn
  /// "Xem hoạt ảnh" fullscreen) → player ẩn top bar/mascot/submit
  /// chrome để animation chiếm toàn màn hình. Chỉ READ có animation gọi.
  final void Function(bool immersive)? onImmersiveChanged;

  /// Evaluation mới nhất khi retry-in-place — renderer tự chọn hiển thị
  /// inline progress (k/n đúng, lượt còn) nếu có. null lần render đầu.
  final EvaluationDto? lastEvaluation;

  /// Optional — player inject quay lại HYPOTHESIS khi verification cần
  /// sửa giả thuyết (selectActivity). Null → ẩn nút "Sửa giả thuyết".
  final VoidCallback? onBackToHypothesis;

  /// Renderer emit spec nút submit để player pin `SubmitBar` đáy màn hình
  /// thay vì để nút cuộn theo nội dung. `null` → activity không có nút
  /// submit chung (EXPLORE_MAP / UNSUPPORTED / READ immersive).
  final SubmitSpecCallback? onSubmitSpec;

  const ActivityRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    this.hasSubmitError = false,
    required this.onSubmit,
    this.onInputChanged,
    this.onImmersiveChanged,
    this.lastEvaluation,
    this.onBackToHypothesis,
    this.onSubmitSpec,
  });

  @override
  Widget build(BuildContext context) {
    final type = (activity.type ?? '').toUpperCase();
    switch (type) {
      case 'READ':
        return ReadRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
          onImmersiveChanged: onImmersiveChanged,
          onSubmitSpec: onSubmitSpec,
        );
      case 'VIEW_IMAGE':
        return ViewImageRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
          onSubmitSpec: onSubmitSpec,
        );
      case 'MULTIPLE_CHOICE':
        return MultipleChoiceRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'EVIDENCE_SELECT':
        return EvidenceSelectRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'MATCHING':
        return MatchingRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'DRAG_ORDER':
        return DragOrderRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'HYPOTHESIS_CHOICE':
        return HypothesisRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'VERIFICATION':
        return VerificationRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
          lastEvaluation: lastEvaluation,
          onBackToHypothesis: onBackToHypothesis,
          onSubmitSpec: onSubmitSpec,
        );
      case 'REASONING_CONNECT':
        return ReasoningConnectRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'EXPLORE_MAP':
        return ExploreMapRenderer(
          activity: activity,
          submitting: submitting,
          hasSubmitError: hasSubmitError,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
        );
      case 'CER_CHOICE':
        return CerChoiceRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'CER':
        return CerRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      case 'REFLECTION_PROMPT':
        return ReflectionRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
          onInputChanged: onInputChanged,
          lastEvaluation: lastEvaluation,
          onSubmitSpec: onSubmitSpec,
        );
      default:
        return UnsupportedRenderer(type: activity.type ?? 'UNKNOWN');
    }
  }
}
