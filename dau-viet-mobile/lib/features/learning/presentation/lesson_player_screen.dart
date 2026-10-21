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

/// Mức độ feedback sau submit — map đúng outcome backend trả về.
enum _FeedbackTone { success, info, warning, error }

class _Feedback {
  final String text;
  final _FeedbackTone tone;
  const _Feedback(this.text, this.tone);
}

/// Trạng thái nội bộ của Lesson Player.
class _PlayerState {
  final CurrentActivityDto current;
  final LessonContentDto content;
  final bool submitting;
  final _Feedback? feedback;

  /// Đã submit và server báo next/cursor nhảy — đang chờ learner bấm
  /// "Tiếp tục" trước khi fetch activity kế. Không auto-advance.
  final bool awaitingContinue;
  final bool completionReady;

  const _PlayerState({
    required this.current,
    required this.content,
    this.submitting = false,
    this.feedback,
    this.awaitingContinue = false,
    this.completionReady = false,
  });

  _PlayerState copyWith({
    CurrentActivityDto? current,
    bool? submitting,
    _Feedback? Function()? feedback,
    bool? awaitingContinue,
    bool? completionReady,
  }) => _PlayerState(
    current: current ?? this.current,
    content: content,
    submitting: submitting ?? this.submitting,
    feedback: feedback == null ? this.feedback : feedback(),
    awaitingContinue: awaitingContinue ?? this.awaitingContinue,
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
    if (st == null ||
        st.submitting ||
        st.awaitingContinue ||
        st.current.activity == null) {
      return;
    }

    // Answer mới → key mới; cùng answer retry → giữ nguyên key.
    if (_pendingAnswer == null || !_sameAnswer(_pendingAnswer!, answer)) {
      _pendingAnswer = answer;
      _pendingKey = _uuid.v4();
    }

    setState(() {
      _state = st.copyWith(submitting: true, feedback: () => null);
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
      _applyResult(res);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.error.code == 'IDEMPOTENCY_CONFLICT') {
        // Key đã dùng cho payload khác → mint key mới và retry 1 lần.
        _pendingKey = _uuid.v4();
        try {
          final res = await _call(
            () => _repo.submit(
              widget.attemptId,
              st.current.activity!.id,
              answer,
              idempotencyKey: _pendingKey,
            ),
          );
          if (!mounted) return;
          _applyResult(res);
          return;
        } on ApiException catch (e2) {
          if (!mounted) return;
          _showSubmitError(e2);
          return;
        }
      }
      _showSubmitError(e);
    }
  }

  void _showSubmitError(ApiException e) {
    setState(() {
      _state = _state!.copyWith(
        submitting: false,
        feedback: () => _Feedback(
          e.isNetworkError ? 'Không kết nối được. Thử lại.' : e.error.message,
          _FeedbackTone.error,
        ),
      );
    });
  }

  bool _sameAnswer(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a.toString() == b.toString();

  /// Map outcome backend → (text, tone). Không tự chấm — chỉ diễn giải
  /// `evaluation.outcome` + `feedbackCode` từ server.
  _Feedback _feedbackFor(SubmitResultDto res, ActivityRefDto? activity) {
    final String? authored = activity?.feedbackText(res.evaluation.feedbackCode);
    switch (res.evaluation.outcome) {
      case 'COMPLETED':
      case 'SUPPORTED':
        return _Feedback(authored ?? 'Chính xác!', _FeedbackTone.success);
      case 'PARTIAL':
        return _Feedback(
          authored ?? 'Đúng một phần — xem lại rồi thử tiếp.',
          _FeedbackTone.warning,
        );
      case 'CONTRADICTED':
        return _Feedback(
          authored ?? 'Chưa thuyết phục — kiểm tra lại lập luận.',
          _FeedbackTone.warning,
        );
      case 'INCORRECT':
        return _Feedback(
          authored ?? 'Chưa đúng, hãy thử lại.',
          _FeedbackTone.error,
        );
      default:
        return _Feedback(authored ?? 'Đã ghi nhận.', _FeedbackTone.info);
    }
  }

  void _applyResult(SubmitResultDto res) {
    final st = _state!;
    final fb = _feedbackFor(res, st.current.activity);

    if (res.completion.complete) {
      setState(() {
        _state = st.copyWith(
          submitting: false,
          feedback: () => fb,
          awaitingContinue: false,
          completionReady: true,
        );
      });
      return;
    }
    if (res.activityCompleted || res.next != null) {
      // Cursor đã nhảy phía server nhưng giữ activity hiện tại + feedback
      // trên màn cho tới khi learner bấm "Tiếp tục" (không auto-advance).
      setState(() {
        _state = st.copyWith(
          submitting: false,
          feedback: () => fb,
          awaitingContinue: true,
        );
        _pendingAnswer = null;
      });
    } else {
      // Chưa complete, không next → giữ cursor, cho retry.
      setState(() {
        _state = st.copyWith(submitting: false, feedback: () => fb);
      });
    }
  }

  /// Chỉ chạy khi `awaitingContinue` — fetch current activity từ server.
  Future<void> _onContinue() async {
    final st = _state;
    if (st == null || !st.awaitingContinue || st.submitting) return;
    setState(() {
      _state = st.copyWith(submitting: true);
    });
    try {
      final cur = await _call(() => _repo.getCurrent(widget.attemptId));
      if (!mounted) return;
      setState(() {
        _state = _PlayerState(current: cur, content: st.content);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = st.copyWith(
          submitting: false,
          feedback: () => const _Feedback(
            'Không tải được hoạt động tiếp theo. Thử lại.',
            _FeedbackTone.error,
          ),
        );
      });
    }
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
        _state = _state?.copyWith(
          feedback: () => _Feedback(e.error.message, _FeedbackTone.error),
        );
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
                    submitting: st.submitting || st.awaitingContinue,
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
          if (st.feedback != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _feedbackCard(st.feedback!),
            ),
          if (st.submitting)
            Text(
              'Đang kiểm tra...',
              textAlign: TextAlign.center,
              style: DauVietTypography.bodySmall.copyWith(
                color: DauVietColors.inkMuted,
              ),
            ),
          if (st.awaitingContinue && !st.submitting)
            DongSonButton(
              label: 'TIẾP TỤC ›',
              icon: Icons.arrow_forward_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 50,
              onPressed: _onContinue,
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

  /// Thẻ feedback theo `_FeedbackTone` — không dùng xanh lá cho mọi outcome.
  Widget _feedbackCard(_Feedback fb) {
    final (bg, border, fg) = switch (fb.tone) {
      _FeedbackTone.success => (
        const Color(0xFFEAF3E5),
        const Color(0xFF4C7C44),
        const Color(0xFF2F5A2B),
      ),
      _FeedbackTone.info => (
        DauVietColors.parchmentContainer,
        DauVietColors.outlineVariant,
        DauVietColors.inkText,
      ),
      _FeedbackTone.warning => (
        const Color(0xFFFDF3E0),
        DauVietColors.imperialGold,
        const Color(0xFF7A5B18),
      ),
      _FeedbackTone.error => (
        DauVietColors.cinnabarRed.withValues(alpha: 0.08),
        DauVietColors.cinnabarRed,
        DauVietColors.cinnabarRed,
      ),
    };
    return ParchmentCard(
      backgroundColor: bg,
      borderColor: border,
      borderWidth: 1,
      padding: const EdgeInsets.all(10),
      child: Text(
        fb.text,
        style: DauVietTypography.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
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
