import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../data/attempt_dtos.dart';
import '../data/attempt_repository.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/activity_renderer.dart';

/// Trạng thái nội bộ của Lesson Player.
class _PlayerState {
  final CurrentActivityDto current;
  final LessonContentDto content;
  final bool submitting;
  final String? feedbackText;
  final bool? lastCorrect; // null = chưa submit / acknowledgment
  final bool completionReady;

  const _PlayerState({
    required this.current,
    required this.content,
    this.submitting = false,
    this.feedbackText,
    this.lastCorrect,
    this.completionReady = false,
  });

  _PlayerState copyWith({
    CurrentActivityDto? current,
    bool? submitting,
    String? feedbackText,
    bool? Function()? lastCorrect,
    bool? completionReady,
  }) => _PlayerState(
    current: current ?? this.current,
    content: content,
    submitting: submitting ?? this.submitting,
    feedbackText: feedbackText,
    lastCorrect: lastCorrect == null ? this.lastCorrect : lastCorrect(),
    completionReady: completionReady ?? this.completionReady,
  );
}

/// Lesson Player — render activity theo server cursor, submit + feedback,
/// điều hướng theo `next`/`current` từ backend. Không tự tính stage/cursor.
class LessonPlayerScreen extends ConsumerStatefulWidget {
  final String attemptId;

  const LessonPlayerScreen({super.key, required this.attemptId});

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  _PlayerState? _state;
  Object? _loadError;
  bool _completing = false;

  /// Idempotency key cho logical submission hiện tại: mint mới khi answer
  /// thay đổi; retry network giữ nguyên key + payload.
  String _submissionKey = '';
  Map<String, dynamic>? _pendingAnswer;
  String _pendingKey = '';
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _submissionKey = _uuid.v4();
    _load();
  }

  AttemptRepository get _repo => ref.read(attemptRepositoryProvider);

  Future<T> _call<T>(Future<T> Function() c) =>
      ApiConfig.useMock ? c() : ref.read(authRepositoryProvider).withAuth(c);

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _call(() => _repo.getCurrent(widget.attemptId)),
        _call(() => _repo.getAttemptContent(widget.attemptId)),
      ]);
      if (!mounted) return;
      setState(() {
        _state = _PlayerState(
          current: results[0] as CurrentActivityDto,
          content: results[1] as LessonContentDto,
        );
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  /// Renderer gọi khi learner chốt câu trả lời.
  Future<void> _submit(Map<String, dynamic> answer) async {
    final st = _state;
    if (st == null || st.submitting || st.current.activity == null) return;

    // Answer mới → key mới; cùng answer retry → giữ nguyên key.
    if (_pendingAnswer == null || !_sameAnswer(_pendingAnswer!, answer)) {
      _pendingAnswer = answer;
      _pendingKey = _uuid.v4();
    }

    setState(() {
      _state = st.copyWith(submitting: true, feedbackText: null);
    });
    try {
      final SubmitResultDto res = await _call(
        () => _repo.submit(
          widget.attemptId,
          st.current.activity!.id,
          answer,
          idempotencyKey: _pendingKey,
        ),
      );
      if (!mounted) return;
      await _applyResult(res);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _state!.copyWith(
          submitting: false,
          feedbackText: e.isNetworkError
              ? 'Không kết nối được. Thử lại.'
              : e.error.message,
          lastCorrect: () => false,
        );
      });
    }
  }

  bool _sameAnswer(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a.toString() == b.toString();

  Future<void> _applyResult(SubmitResultDto res) async {
    final st = _state!;
    final String text =
        st.current.activity?.feedbackText(res.evaluation.feedbackCode) ??
        _defaultFeedback(res);
    final bool correct = res.evaluation.outcome != 'INCORRECT';

    if (res.completion.complete) {
      setState(() {
        _state = st.copyWith(
          submitting: false,
          feedbackText: text,
          lastCorrect: () => correct,
          completionReady: true,
        );
      });
      return;
    }
    if (res.activityCompleted || res.next != null) {
      // Cursor đã nhảy — fetch lại current từ server (authoritative).
      try {
        final cur = await _call(() => _repo.getCurrent(widget.attemptId));
        if (!mounted) return;
        setState(() {
          _state = _PlayerState(
            current: cur,
            content: st.content,
            feedbackText: text,
            lastCorrect: correct,
          );
          _pendingAnswer = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _state = st.copyWith(
            submitting: false,
            feedbackText: 'Đã ghi nhận câu trả lời.',
            lastCorrect: () => true,
          );
        });
      }
    } else {
      // Chưa complete, không next → giữ cursor, cho retry.
      setState(() {
        _state = st.copyWith(
          submitting: false,
          feedbackText: text,
          lastCorrect: () => correct,
        );
      });
    }
  }

  String _defaultFeedback(SubmitResultDto res) {
    if (res.evaluation.outcome == 'INCORRECT') {
      return 'Chưa đúng, hãy thử lại.';
    }
    return res.activityCompleted ? 'Chính xác!' : 'Đã ghi nhận câu trả lời.';
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await _call(
        () => _repo.complete(widget.attemptId, idempotencyKey: _submissionKey),
      );
      final LessonResultDto result = await _call(
        () => _repo.getResult(widget.attemptId),
      );
      if (!mounted) return;
      context.pushReplacement(
        '/learning/result/${widget.attemptId}',
        extra: result,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        _state = _state?.copyWith(feedbackText: e.error.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _state;
    return Scaffold(
      backgroundColor: DauVietColors.parchmentSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DauVietColors.parchmentSurface, Color(0xFFFAF2E4)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _loadError != null
                  ? AsyncStateView.error(error: _loadError!, onRetry: _load)
                  : st == null
                  ? AsyncStateView.loading()
                  : _buildPlayer(st),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(_PlayerState st) {
    final cur = st.current;
    return Column(
      children: [
        _buildTopBar(st),
        if (cur.activity == null) const Spacer(),
        if (cur.activity == null)
          _buildFinished(st)
        else ...[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cur.activity!.instruction != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        cur.activity!.instruction!,
                        style: DauVietTypography.bodyMedium.copyWith(
                          color: DauVietColors.inkMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ActivityRenderer(
                    key: ValueKey(cur.activity!.id),
                    activity: cur.activity!,
                    content: st.content,
                    submitting: st.submitting,
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(st),
        ],
      ],
    );
  }

  Widget _buildTopBar(_PlayerState st) {
    final cur = st.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: DauVietColors.inkText,
            onPressed: _confirmExit,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cur.stage?.title ?? 'Bài học',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                ShimmerProgressBar(progress: cur.progress.fraction, height: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${cur.progress.completedRequired}/${cur.progress.totalRequired}',
            style: DauVietTypography.labelSmall.copyWith(
              color: DauVietColors.inkMuted,
            ),
          ),
          const SoundToggleButton(),
        ],
      ),
    );
  }

  Widget _buildBottomBar(_PlayerState st) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          top: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (st.feedbackText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ParchmentCard(
                backgroundColor: st.lastCorrect == false
                    ? DauVietColors.cinnabarRed.withValues(alpha: 0.08)
                    : const Color(0xFFEAF3E5),
                borderColor: st.lastCorrect == false
                    ? DauVietColors.cinnabarRed
                    : const Color(0xFF4C7C44),
                borderWidth: 1,
                padding: const EdgeInsets.all(10),
                child: Text(
                  st.feedbackText!,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: st.lastCorrect == false
                        ? DauVietColors.cinnabarRed
                        : const Color(0xFF2F5A2B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (st.submitting)
            Text(
              'Đang kiểm tra...',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          if (st.completionReady)
            DongSonButton(
              label: _completing ? 'ĐANG TỔNG KẾT...' : 'HOÀN THÀNH BÀI HỌC',
              icon: Icons.emoji_events_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 50,
              onPressed: _completing ? () {} : _complete,
            ),
        ],
      ),
    );
  }

  Widget _buildFinished(_PlayerState st) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Đã hết hoạt động bắt buộc.',
            style: DauVietTypography.bodyMedium,
          ),
          const SizedBox(height: 16),
          DongSonButton(
            label: _completing ? 'ĐANG TỔNG KẾT...' : 'HOÀN THÀNH BÀI HỌC',
            icon: Icons.emoji_events_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            height: 50,
            onPressed: _completing ? () {} : _complete,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    // Submission đã ghi nhận server-side — thoát không mất tiến độ.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }
}
