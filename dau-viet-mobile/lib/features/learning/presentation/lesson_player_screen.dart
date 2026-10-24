import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/parchment_card.dart';
import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../collection/data/collection_providers.dart';
import '../../map/data/map_providers.dart';
import '../../rewards/data/reward_providers.dart';
import '../data/attempt_dtos.dart';
import '../data/attempt_repository.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/activity_renderer.dart';
import 'stage-guidance.dart';

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

  /// Idempotency lifecycle:
  /// - Retry sau lỗi network mơ hồ → CÙNG key + CÙNG payload.
  /// - Một submission MỚI (answer đổi, hoặc server đã trả response
  ///   authoritative trước đó) → key MỚI, kể cả answer giống hệt.
  String _submissionKey = '';
  Map<String, dynamic>? _pendingAnswer;
  String _pendingKey = '';
  final _uuid = const Uuid();

  /// true sau khi server đã trả BẤT KỲ response authoritative nào cho
  /// submission trước — mọi submit tiếp theo là attempt MỚI và cần key mới
  /// dù payload trùng (kể cả submit lại cùng answer sai).
  bool _needsFreshKey = false;

  /// true khi renderer báo có input chưa gửi (CER text, reflection...).
  /// Điều khiển canPop của PopScope + exit-confirmation.
  bool _hasUnsentInput = false;

  /// Chống re-entrant: chỉ 1 dialog thoát tồn tại cùng lúc.
  bool _exitDialogOpen = false;

  /// Phase-1 gate: server đã xác nhận POST /complete → đánh dấu để không
  /// gọi lại completion POST khi learner retry fetch result. Không reset
  /// vì attempt đã COMPLETED trên backend.
  bool _completionAcknowledged = false;

  /// Phase-2 gate: đang fetch GET /result — chặn retry trùng lặp.
  bool _fetchingResult = false;

  /// Renderer báo input thay đổi — chỉ nhận khi còn được phép sửa.
  /// setState để PopScope rebuild và cập nhật canPop; sau khi server đã
  /// ghi nhận answer, edit mới sẽ bật dirty trở lại.
  void _onInputChanged(bool hasInput) {
    if (_state?.awaitingContinue == true || _state?.submitting == true) return;
    if (_hasUnsentInput == hasInput) return;
    setState(() => _hasUnsentInput = hasInput);
  }

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
        st.completionReady ||
        st.current.activity == null) {
      return;
    }

    // Submission MỚI (answer đổi hoặc response trước đã được ghi nhận)
    // → mint key mới. Retry network cùng payload → giữ nguyên key.
    if (_needsFreshKey ||
        _pendingAnswer == null ||
        !_sameAnswer(_pendingAnswer!, answer)) {
      _pendingAnswer = answer;
      _pendingKey = _uuid.v4();
      _needsFreshKey = false;
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
      // Response authoritative đã về: submission này kết thúc — submit kế
      // (kể cả cùng payload) là attempt mới, cần key mới.
      _needsFreshKey = true;
      // TASK-0023: submit EVIDENCE_SELECT cập nhật collection trong cùng
      // transaction và evaluator có thể đã mở vật phẩm COLLECTION_COUNT —
      // invalidate catalog/summary để Túi Đồ phản ánh unlock mới nhất.
      ref.invalidate(collectionListProvider);
      ref.invalidate(rewardSummaryProvider);
      ref.invalidate(inventoryCatalogProvider);
      ref.invalidate(inventoryItemsProvider);
      _applyResult(res);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.error.code == 'IDEMPOTENCY_CONFLICT') {
        // Key đã gắn với payload khác phía server. Đây KHÔNG phải lỗi
        // network mơ hồ: không auto-resubmit — server state đã authoritative.
        // Learner bấm lại sẽ là attempt mới với key mới.
        _needsFreshKey = true;
        _showSubmitError(
          const ApiException(
            ApiError(
              code: 'IDEMPOTENCY_CONFLICT',
              message:
                  'Lượt trả lời trước đã được ghi nhận. Kiểm tra lại rồi gửi lại.',
            ),
          ),
        );
        return;
      }
      _showSubmitError(e);
    }
  }

  void _showSubmitError(ApiException e) {
    setState(() {
      _state = _state!.copyWith(
        submitting: false,
        feedback: () => _Feedback(
          // IDEMPOTENCY_CONFLICT phải hiện message riêng — nó không có HTTP
          // status nên isNetworkError=true, không được nhầm là lỗi mạng.
          e.error.code == 'IDEMPOTENCY_CONFLICT'
              ? e.error.message
              : e.isNetworkError
              ? 'Không kết nối được. Thử lại.'
              : e.error.message,
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
    final String? authored = activity?.feedbackText(
      res.evaluation.feedbackCode,
    );
    switch (res.evaluation.outcome) {
      case 'COMPLETED':
      case 'SUPPORTED':
        return _Feedback(authored ?? 'Chính xác!', _FeedbackTone.success);
      case 'PARTIAL':
        // Reviewed-exhausted terminal (TASK-0020 final): verification spent
        // its budget on a non-SUPPORTED verdict → completed-for-progress,
        // never promoted. Learner finished the lesson; knowledge is partial.
        if (res.evaluation.output?['exhausted'] == true) {
          return _Feedback(
            authored ??
                'Bạn đã hoàn thành lượt học, nhưng chưa kiểm chứng thành công.',
            _FeedbackTone.warning,
          );
        }
        return _Feedback(
          authored ?? 'Đúng một phần — xem lại rồi thử tiếp.',
          _FeedbackTone.warning,
        );
      case 'CONTRADICTED':
        if (res.evaluation.output?['exhausted'] == true) {
          return _Feedback(
            authored ??
                'Bạn đã hoàn thành lượt học, nhưng chưa kiểm chứng thành công.',
            _FeedbackTone.warning,
          );
        }
        return _Feedback(
          authored ?? 'Chưa thuyết phục — kiểm tra lại lập luận.',
          _FeedbackTone.warning,
        );
      case 'INCORRECT':
        // Retry đã cạn (output.exhausted) → không hứa "thử lại" — server
        // sẽ advance cursor; learner chỉ được đi tiếp.
        final bool exhausted = res.evaluation.output?['exhausted'] == true;
        return _Feedback(
          authored ??
              (exhausted
                  ? 'Chưa chính xác — đã hết lượt thử. Đi tiếp nhé.'
                  : 'Chưa đúng, hãy thử lại.'),
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
        _hasUnsentInput = false;
      });
      return;
    }
    // INCORRECT retry path: server giữ cursor ở activity hiện tại — next
    // đến cùng activity đó, không phải sang activity mới. Không chuyển
    // awaitingContinue (renderer bị lock khi đó) để learner sửa ngay.
    final bool retryInPlace =
        !res.evaluation.completed &&
        res.next != null &&
        res.next!.activityId == st.current.activity?.id;
    if ((res.activityCompleted || res.next != null) && !retryInPlace) {
      // Cursor đã nhảy phía server nhưng giữ activity hiện tại + feedback
      // trên màn cho tới khi learner bấm "Tiếp tục" (không auto-advance).
      setState(() {
        _state = st.copyWith(
          submitting: false,
          feedback: () => fb,
          awaitingContinue: true,
        );
        _pendingAnswer = null;
        _hasUnsentInput = false; // input đã được server chấp nhận
      });
    } else {
      // Chưa complete, không next → giữ cursor, cho retry. Input hiện tại
      // đã được server ghi nhận → không còn "unsent".
      setState(() {
        _state = st.copyWith(submitting: false, feedback: () => fb);
        _hasUnsentInput = false;
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
        _hasUnsentInput = false;
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

  /// Phase 1 — POST /complete. Chỉ chạy 1 lần; sau khi server xác nhận
  /// (_completionAcknowledged) mọi retry chỉ đi qua Phase 2.
  Future<void> _complete() async {
    if (_completing || _fetchingResult) return;
    if (_completionAcknowledged) {
      // Đã hoàn thành server-side — learner chỉ cần lấy kết quả.
      await _fetchResult();
      return;
    }
    setState(() => _completing = true);
    try {
      await _call(
        () => _repo.complete(widget.attemptId, idempotencyKey: _submissionKey),
      );
      if (!mounted) return;
      // Server đã ghi COMPLETED — backend là authoritative, không được
      // re-POST complete dù learner bấm lại.
      _completionAcknowledged = true;
      // Attempt đã xong → progress cache cũ (IN_PROGRESS) không còn đúng.
      ref.invalidate(myProgressProvider);
      // Trạng thái mở khoá bản đồ có thể đổi ngay sau completion.
      // Invalidate ở đây (không đợi remount /map) vì route Map thường đã
      // unmount sau pushReplacement/context.go.
      ref.invalidate(mapLocationsProvider);
      // Bộ sưu tập có thể vừa nhận bằng chứng mới (EVIDENCE_SELECT
      // submissions vừa hoàn thành trong bài này) — invalidate mọi
      // family instance để lần mở /collection sau refetch.
      ref.invalidate(collectionListProvider);
      // TASK-0023: thưởng + vật phẩm có thể vừa được cấp trong cùng
      // transaction complete — invalidate để Túi Đồ/summary refetch lần
      // mở sau (không fetch lại ngay để không chậm điều hướng).
      ref.invalidate(rewardSummaryProvider);
      ref.invalidate(inventoryCatalogProvider);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(rewardTransactionsProvider);
      await _fetchResult();
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

  /// Phase 2 — GET /result. Thất bại KHÔNG reset _completionAcknowledged
  /// và KHÔNG bao giờ re-POST complete — chỉ retry GET khi learner bấm
  /// "THỬ TẢI KẾT QUẢ".
  Future<void> _fetchResult() async {
    if (_fetchingResult) return;
    setState(() => _fetchingResult = true);
    try {
      final LessonResultDto result = await _call(
        () => _repo.getResult(widget.attemptId),
      );
      if (!mounted) return;
      context.pushReplacement(
        '/learning/result/${widget.attemptId}',
        extra: result,
      );
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _fetchingResult = false;
        _completing = false;
        _state = _state?.copyWith(
          feedback: () => const _Feedback(
            'Bài học đã hoàn thành. Chưa tải được kết quả.',
            _FeedbackTone.error,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _state;
    return PopScope(
      // Dirty → chặn pop để hỏi xác nhận; sạch → pop ngay lập tức.
      canPop: !_hasUnsentInput,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
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
              // viewInsets.bottom để bàn phím không che ô đang nhập (CER/
              // Reflection) — phần còn lại của layout giữ nguyên.
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Giai đoạn điều tra hiện tại + gợi ý cách làm (P1-04).
                  if (cur.stage?.type != null) ...[
                    StageGuidanceChip(stageType: cur.stage!.type),
                    const SizedBox(height: 10),
                  ],
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
                    // completionReady: khóa tương tác renderer — chỉ còn
                    // nút hoàn thành; chặn submit trùng activity cuối.
                    submitting:
                        st.submitting ||
                        st.awaitingContinue ||
                        st.completionReady,
                    onSubmit: _submit,
                    onInputChanged: _onInputChanged,
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
              label: _completing || _fetchingResult
                  ? 'ĐANG TỔNG KẾT...'
                  : _completionAcknowledged
                  ? 'THỬ TẢI KẾT QUẢ'
                  : 'HOÀN THÀNH BÀI HỌC',
              icon: Icons.emoji_events_rounded,
              variant: DongSonButtonVariant.primaryCinnabar,
              height: 50,
              onPressed: _completing || _fetchingResult ? () {} : _complete,
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
          if (st.feedback != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _feedbackCard(st.feedback!),
            ),
          DongSonButton(
            label: _completing || _fetchingResult
                ? 'ĐANG TỔNG KẾT...'
                : _completionAcknowledged
                ? 'THỬ TẢI KẾT QUẢ'
                : 'HOÀN THÀNH BÀI HỌC',
            icon: Icons.emoji_events_rounded,
            variant: DongSonButtonVariant.primaryCinnabar,
            height: 50,
            onPressed: _completing || _fetchingResult ? () {} : _complete,
          ),
        ],
      ),
    );
  }

  /// Thoát player: submission đã submit xong là an toàn (server-side);
  /// chỉ hỏi xác nhận khi renderer báo còn input chưa gửi (draft sẽ mất).
  /// Android Back và nút back góc trên đi chung đường này.
  Future<void> _confirmExit() async {
    // Không có input chưa gửi → thoát thẳng, không cần hỏi.
    if (!_hasUnsentInput) {
      _exitNow();
      return;
    }
    if (_exitDialogOpen) return; // chặn dialog chồng nhau
    _exitDialogOpen = true;
    try {
      final bool leave =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Thoát bài học?'),
              content: const Text(
                'Câu trả lời chưa gửi sẽ mất. Tiến độ đã lưu trên máy chủ '
                'vẫn được giữ.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Ở LẠI'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('THOÁT'),
                ),
              ],
            ),
          ) ??
          false;
      if (!leave || !mounted) return;
      // Mở khóa PopScope: sau rebuild canPop=true → pop thật không quay
      // lại handler này (tránh recursion). Pop phải đợi frame kế vì
      // PopScope chỉ nhận canPop mới sau khi rebuild.
      setState(() => _hasUnsentInput = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _exitNow();
      });
    } finally {
      _exitDialogOpen = false;
    }
  }

  void _exitNow() {
    if (!mounted) return;
    // Rời lesson dù chỉ mới partial progress → dashboard phải refetch
    // progress thay vì dùng cache cũ (đã invalidate sẵn ở _complete khi
    // lesson hoàn thành; đây là nhánh thoát giữa chừng).
    ref.invalidate(myProgressProvider);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }
}
