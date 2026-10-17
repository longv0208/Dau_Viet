import 'package:flutter/material.dart';

import '../../data/attempt_dtos.dart';
import '../../data/learning_dtos.dart';
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
  final Future<void> Function(Map<String, dynamic> answer) onSubmit;

  const ActivityRenderer({
    super.key,
    required this.activity,
    required this.content,
    required this.submitting,
    required this.onSubmit,
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
        );
      case 'VIEW_IMAGE':
        return ViewImageRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'MULTIPLE_CHOICE':
        return MultipleChoiceRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'EVIDENCE_SELECT':
        return EvidenceSelectRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'MATCHING':
        return MatchingRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'DRAG_ORDER':
        return DragOrderRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'HYPOTHESIS_CHOICE':
        return HypothesisRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'VERIFICATION':
        return VerificationRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'REASONING_CONNECT':
        return ReasoningConnectRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'EXPLORE_MAP':
        return ExploreMapRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'CER':
        return CerRenderer(
          activity: activity,
          content: content,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      case 'REFLECTION_PROMPT':
        return ReflectionRenderer(
          activity: activity,
          submitting: submitting,
          onSubmit: onSubmit,
        );
      default:
        return UnsupportedRenderer(type: activity.type ?? 'UNKNOWN');
    }
  }
}
