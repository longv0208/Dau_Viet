import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/audio/dau_viet_audio_service.dart';
import '../../../core/theme/dau_viet_colors.dart';
import '../../../core/theme/dau_viet_typography.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../../core/widgets/dong_son_button.dart';
import '../../../core/widgets/gold_confetti_overlay.dart';
import '../../../core/widgets/kabi_mascot_widget.dart';
import '../../../core/widgets/tactile_3d_button.dart';

import '../../../core/widgets/shimmer_progress_bar.dart';
import '../../../core/widgets/sound_toggle_button.dart';
import '../../collection/data/collection_providers.dart';
import '../../collection/data/dossier_providers.dart';
import '../../energy/data/energy_dto.dart';
import '../../energy/data/energy_providers.dart';
import '../../learning_path/data/learning_path_providers.dart';
import '../../map/data/map_providers.dart';
import '../../rewards/data/reward_providers.dart';
import '../../streak/data/streak_dto.dart';
import '../../streak/data/streak_providers.dart';
import '../data/attempt_dtos.dart';
import '../data/attempt_repository.dart';
import '../data/learning_dtos.dart';
import '../data/learning_providers.dart';
import 'renderers/activity_renderer.dart';
import '../../../core/widgets/mascot_speech_bubble.dart';

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

  /// GAME-04: dossier ids mở MỚI từ response complete của LẦN này —
  /// truyền vào result screen để hiện cue đúng một lần. Không reset.
  List<String> _newlyUnlockedDossiers = const [];

  /// STREAK-01: ngày học MỚI được công nhận trong lần complete này —
  /// truyền vào result screen để phát animation ngọn lửa đúng một lần.
  /// Null khi ngày đã có (replay, bài thứ hai cùng ngày) → không phát lại.
  StreakInfoDto? _newStreakInfo;

  /// MAP-V2 (E5): địa điểm di sản vừa mở khóa MỚI trong lần complete này —
  /// truyền vào LessonResultScreen qua extra để hiện banner đúng một lần.
  List<UnlockedLocationCueDto> _newlyUnlockedLocations = const [];

  /// Event của lesson đang chơi — resolve lúc _load để invalidate đúng
  /// eventProgressProvider sau complete (null = lesson không gắn event).
  String? _lessonEventId;


  /// Entry toast trừ Thể lực đang hiển thị — hủy ngay khi submit mới hoặc thoát.
  OverlayEntry? _energyToastEntry;

  void _dismissEnergyPenaltyToast() {
    _energyToastEntry?.remove();
    _energyToastEntry = null;
  }

  @override
  void dispose() {
    _dismissEnergyPenaltyToast();
    super.dispose();
  }
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

  /// Event chứa lesson — resolve một lần lúc load (không block UI).
  Future<String?> _resolveEventId(String lessonId) async {
    if (lessonId.isEmpty) return null;
    try {
      final meta = await _call(() => _repo.getLessonMetadata(lessonId));
      return meta.eventId.isEmpty ? null : meta.eventId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _call(() => _repo.getCurrent(widget.attemptId)),
        _call(() => _repo.getAttemptContent(widget.attemptId)),
      ]);
      if (!mounted) return;
      final content = results[1] as LessonContentDto;
      // Resolve event từ lesson metadata (không block load — lỗi → null).
      _lessonEventId = await _resolveEventId(content.lessonId);
      setState(() {
        _state = _PlayerState(
          current: results[0] as CurrentActivityDto,
          content: content,
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

    _dismissEnergyPenaltyToast();
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
      // GAME-03: đồng bộ Thể lực từ snapshot server — KHÔNG suy từ
      // energyDeducted (server có thể đã lazy-recover trước khi trừ).
      if (res.energy != null) {
        ref.read(energyProvider.notifier).applySnapshot(res.energy!);
      }
      // GAME-03: khi server thực sự trừ Thể lực (>0) — báo ngay kiểu game:
      // toast "-N Thể lực" trượt lên + rung nhẹ. Chỉ chạy sau khi mounted
      // và trước khi feedback/continue render lại.
      if (res.energyDeducted > 0) {
        _showEnergyPenaltyToast(res.energyDeducted);
      }
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
      if (e.error.code == 'ENERGY_DEPLETED') {
        _handleEnergyDepleted(e);
        return;
      }
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

  /// GAME-03 §8.5 — 409 ENERGY_DEPLETED: submission KHÔNG được ghi nhận.
  /// Giữ nguyên input/cursor/progress; đồng bộ provider từ error details;
  /// dialog thân thiện có countdown từ server + lối sang Viện Thái Y.
  /// Submit trước đã trả response authoritative (hoặc đây là lần submit
  /// đầu bị từ chối) → submission kế cần key mới khi learner retry.
  void _handleEnergyDepleted(ApiException e) {
    _needsFreshKey = true;
    final details = e.error.details;
    final prev = ref.read(energyProvider).value;
    bool hasDetails = false;
    if (details is Map) {
      final m = details.cast<String, dynamic>();
      if (m['currentEnergy'] is num) {
        hasDetails = true;
        // FIX-5: giữ metadata đã biết từ state hiện tại — 409 details chỉ
        // xác nhận current/nextRecoveryAt/serverTime, KHÔNG xác nhận
        // max/recovery*. Chỉ dùng default khi chưa từng có state.
        ref
            .read(energyProvider.notifier)
            .applySnapshot(
              EnergyStateDto(
                current: (m['currentEnergy'] as num).toInt(),
                max: prev?.max ?? 100,
                recoveryAmount: prev?.recoveryAmount ?? 0,
                recoveryIntervalSeconds: prev?.recoveryIntervalSeconds ?? 0,
                nextRecoveryAt: m['nextRecoveryAt'] is String
                    ? DateTime.tryParse(m['nextRecoveryAt'] as String)
                    : null,
                serverTime: m['serverTime'] is String
                    ? DateTime.tryParse(m['serverTime'] as String)
                    : null,
                canSubmitGraded: false,
              ),
            );
      }
    }
    // Provider chưa từng có state VÀ details thiếu/trống → không tự bịa
    // số: refresh GET /me/energy lấy trạng thái authoritative. Lỗi đã
    // nằm trong AsyncError (refresh swallow) — UI pill/screen tự hiển thị.
    if (prev == null && !hasDetails) {
      ref.read(energyProvider.notifier).refresh();
    }
    _dismissEnergyPenaltyToast();
    setState(() {
      _state = _state!.copyWith(submitting: false);
    });
    _showEnergyDepletedDialog(e.error.details);
  }

  void _showEnergyDepletedDialog(Object? details) {
    String waitLine = 'Thể lực sẽ tự hồi sau ít phút.';
    if (details is Map) {
      final m = details.cast<String, dynamic>();
      final nextRaw = m['nextRecoveryAt'];
      final serverRaw = m['serverTime'];
      if (nextRaw is String) {
        final next = DateTime.tryParse(nextRaw);
        final serverNow = serverRaw is String
            ? DateTime.tryParse(serverRaw)
            : null;
        if (next != null) {
          // Ưu tiên serverTime để bù skew thiết bị; fallback đồng hồ máy.
          final base = serverNow ?? DateTime.now().toUtc();
          final remain = next.difference(base.toUtc());
          final secs = remain.isNegative ? 0 : remain.inSeconds;
          final mm = secs ~/ 60;
          final ss = secs % 60;
          waitLine = mm > 0
              ? 'Hệ thống sẽ tự hồi +5 Thể lực sau khoảng $mm phút '
                    '${ss > 0 ? '$ss giây ' : ''}nữa.'
              : 'Hệ thống sẽ tự hồi +5 Thể lực sau $ss giây nữa.';
        }
      }
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hết Thể lực'),
        content: Text(
          'Bạn đã hết Thể lực cho các câu hỏi được chấm điểm.\n\n'
          '$waitLine\n\n'
          'Bạn vẫn có thể xem lại tư liệu và các hoạt động không chấm '
          'điểm trong lúc chờ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ở LẠI XEM TIẾP'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/energy');
            },
            child: const Text('VIỆN THÁI Y'),
          ),
        ],
      ),
    );
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
        final String base =
            authored ??
            (exhausted
                ? 'Chưa chính xác — đã hết lượt thử. Đi tiếp nhé.'
                : 'Chưa đúng, hãy thử lại.');
        // GAME-03: chỉ nối mức trừ khi server thực sự debit (>0) —
        // có thể <10 nếu clamp ở số dư thấp; PARTIAL/flag tắt → 0 →
        // không hiển thị phạt.
        return _Feedback(
          res.energyDeducted > 0
              ? '$base −${res.energyDeducted} Thể lực'
              : base,
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
      // Khi hoàn thành bài học: chỉ phát chuông sfxCorrect (không voice) rồi phát victoryVoice.
      // Tuyệt đối không phát voice câu đúng thông thường để tránh trùng lặp âm thanh.
      DauVietAudioService.instance.playCorrect(withVoice: false);
      if (!DauVietAudioService.isTestEnvironment) {
        Future.delayed(const Duration(milliseconds: 320), () {
          DauVietAudioService.instance.playVictoryVoice();
        });
      } else {
        DauVietAudioService.instance.playVictoryVoice();
      }
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

    // Micro-SFX chuẩn Duolingo cho phản hồi đúng / sai từng câu thông thường
    if (fb.tone == _FeedbackTone.success) {
      DauVietAudioService.instance.playCorrect();
    } else if (fb.tone == _FeedbackTone.error) {
      DauVietAudioService.instance.playWrong();
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
      final complete = await _call(
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
      // Issue #36: trục học trên Bản Đồ Dấu Ấn là learning-path — mở khóa
      // bài kế xảy ra trong cùng transaction complete → invalidate ngay.
      ref.invalidate(learningPathProvider);
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
      // GAME-04: dossier + event progress có thể vừa mở trong cùng tx —
      // invalidate mọi family instance để lần mở /collection hoặc campaign
      // sau refetch đúng trạng thái mới.
      ref.invalidate(dossierListProvider);
      ref.invalidate(dossierDetailProvider);
      if (_lessonEventId != null) {
        ref.invalidate(eventProgressProvider(_lessonEventId!));
      }
      // Cue một lần: chỉ khi response complete có dossier MỚI (replay
      // trả rỗng → không re-show). Lưu vào state để _fetchResult truyền
      // tiếp cho LessonResultScreen qua extra.
      if (complete.newlyUnlockedDossiers.isNotEmpty) {
        _newlyUnlockedDossiers = complete.newlyUnlockedDossiers;
      }
      if (complete.newlyUnlockedLocations.isNotEmpty) {
        _newlyUnlockedLocations = complete.newlyUnlockedLocations;
      }
      // STREAK-01: ngày học mới được công nhận → áp snapshot vào provider
      // ngay (dashboard/detail cập nhật không cần refetch) và giữ lại để
      // LessonResultScreen phát animation ngọn lửa đúng một lần.
      final StreakInfoDto? streakInfo = complete.streak;
      if (streakInfo != null) {
        ref.read(streakProvider.notifier).applyStreakInfo(streakInfo);
        _newStreakInfo = streakInfo;
      }
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
      // GAME-04: truyền dossier mới mở qua result object — LessonResultScreen
      // hiện cue đúng một lần, deep-link/reload (extra null) không re-show.
      final enriched = LessonResultDto(
        attemptId: result.attemptId,
        lessonVersionId: result.lessonVersionId,
        status: result.status,
        score: result.score,
        result: result.result,
        completedAt: result.completedAt,
        startedAt: result.startedAt,
        rewards: result.rewards,
        itemsUnlocked: result.itemsUnlocked,
        newlyUnlockedDossiers: _newlyUnlockedDossiers,
        newlyRecordedStreak: _newStreakInfo,
        newlyUnlockedLocations: _newlyUnlockedLocations,
      );
      context.pushReplacement(
        '/learning/result/${widget.attemptId}',
        extra: enriched,
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

  String _resolveMascotPrompt(_PlayerState st) {
    final cur = st.current;
    final act = cur.activity;
    if (act == null) {
      return 'Khám phá sử liệu cùng mình nhé! Bạn sẽ làm rất tốt!';
    }

    final type = act.type;
    if (type == 'MULTIPLE_CHOICE') {
      final opts = (act.config['options'] as List? ?? const []);
      final isTrueFalse =
          opts.length == 2 &&
          opts.every((o) {
            final label = (o is Map ? (o['label'] ?? o['text'] ?? '') : '')
                .toString()
                .trim()
                .toLowerCase();
            return label == 'đúng' ||
                label == 'sai' ||
                label == 'true' ||
                label == 'false';
          });
      if (isTrueFalse) {
        return 'Hãy suy nghĩ kỹ và chọn Đúng hoặc Sai nhé!';
      }
      return 'Cùng suy nghĩ nào! Bạn làm được mà! 💪';
    } else if (type == 'MATCHING') {
      return 'Ghép đúng là giỏi lắm! Hãy kết nối các thẻ với nhau nhé!';
    } else if (type == 'DRAG_ORDER') {
      return 'Hãy sắp xếp các sự kiện theo đúng trình tự thời gian nhé!';
    }
    return 'Cùng suy nghĩ nào! Bạn làm được mà! 💪';
  }

  Widget _buildPlayer(_PlayerState st) {
    final cur = st.current;
    return Column(
      children: [
        _buildTopBar(st),
        if (cur.activity == null)
          _buildFinished(st)
        else if (st.awaitingContinue && st.feedback != null)
          _buildCelebrationScreen(st)
        else ...[
          // Bong bóng thoại Mascot Rùa Kabi đội nón lá (Screen 2, 3, 4, 5)
          MascotSpeechBubble(
            message: _resolveMascotPrompt(st),
            mood: KabiMood.guiding,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cur.activity?.instruction != null) ...[
                    Text(
                      cur.activity!.instruction!,
                      style: DauVietTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: DauVietColors.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    // GAME-03: hint chi phí Thể lực TRƯỚC khi submit — chỉ hiện
                    // khi server xác nhận activity graded (additive field);
                    // activity không graded / server cũ → ẩn hoàn toàn.
                    if (cur.activity!.graded &&
                        (cur.activity!.incorrectPenalty ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EnergyCostHint(
                          penalty: cur.activity!.incorrectPenalty!,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  ActivityRenderer(
                    key: ValueKey(cur.activity!.id),
                    activity: cur.activity!,
                    content: st.content,
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
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      decoration: BoxDecoration(
        color: DauVietColors.parchmentSurface,
        border: Border(
          bottom: BorderSide(
            color: DauVietColors.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: DauVietColors.inkText,
            tooltip: 'Thoát bài học',
            onPressed: _confirmExit,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cur.stage?.title ?? 'Bài học',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DauVietTypography.headlineMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // STREAK-01: huy hiệu ngọn lửa chuỗi học — số thật từ
                    // streakProvider (server), không hard-code.
                    _StreakBadge(),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFE8DA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFD8C8B0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${cur.progress.completedRequired}/${cur.progress.totalRequired}',
                            style: DauVietTypography.labelSmall.copyWith(
                              color: const Color(0xFF5E6963),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ShimmerProgressBar(progress: cur.progress.fraction, height: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SoundToggleButton(),
        ],
      ),
    );
  }

  Widget _buildBottomBar(_PlayerState st) {
    final isSuccess = st.feedback?.tone == _FeedbackTone.success;
    final isError = st.feedback?.tone == _FeedbackTone.error;
    final isWarning = st.feedback?.tone == _FeedbackTone.warning;

    Color sheetBg = DauVietColors.parchmentSurface;
    BorderSide topBorder = BorderSide(
      color: DauVietColors.outlineVariant.withValues(alpha: 0.5),
    );

    if (st.feedback != null) {
      if (isSuccess) {
        sheetBg = const Color(0xFFE8F7ED);
        topBorder = const BorderSide(color: Color(0xFF4C7C44), width: 2.0);
      } else if (isError) {
        sheetBg = const Color(0xFFFDEEEC);
        topBorder = const BorderSide(
          color: DauVietColors.cinnabarRed,
          width: 2.0,
        );
      } else if (isWarning) {
        sheetBg = const Color(0xFFFFF7E6);
        topBorder = const BorderSide(
          color: DauVietColors.imperialGold,
          width: 2.0,
        );
      }
    }

    return GoldConfettiOverlay(
      trigger: isSuccess,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        decoration: BoxDecoration(
          color: sheetBg,
          border: Border(top: topBorder),
          borderRadius: st.feedback != null
              ? const BorderRadius.vertical(top: Radius.circular(20))
              : null,
          boxShadow: st.feedback != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (st.feedback != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _feedbackCard(st.feedback!),
              ),
            if (st.submitting)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Đang kiểm tra...',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (st.awaitingContinue && !st.submitting)
              DongSonButton(
                label: 'TIẾP TỤC ›',
                icon: Icons.arrow_forward_rounded,
                variant: isSuccess
                    ? DongSonButtonVariant.natureGreen
                    : DongSonButtonVariant.primaryCinnabar,
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
                variant: DongSonButtonVariant.imperialGold,
                height: 50,
                onPressed: _completing || _fetchingResult ? () {} : _complete,
              ),
          ],
        ),
      ),
    );
  }

  /// Màn Ăn Mừng / Động Viên riêng biệt toàn màn hình chuẩn Duolingo.
  /// Chỉ hiển thị duy nhất 1 Mascot Kabi to lớn (140x140) ở trung tâm.
  Widget _buildCelebrationScreen(_PlayerState st) {
    final isSuccess = st.feedback?.tone == _FeedbackTone.success;
    final fb = st.feedback;

    final title = isSuccess ? 'CHÍNH XÁC! XUẤT SẮC!' : 'CHƯA CHÍNH XÁC RỒI!';
    final titleColor = isSuccess
        ? const Color(0xFF1B5E20)
        : DauVietColors.cinnabarRed;
    final badgeBg = isSuccess
        ? const Color(0xFFDDF3E4)
        : const Color(0xFFFDE8E5);
    final badgeBorder = isSuccess
        ? const Color(0xFF4C7C44)
        : DauVietColors.cinnabarRed;

    return Expanded(
      child: GoldConfettiOverlay(
        trigger: isSuccess,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isSuccess
                  ? [const Color(0xFFF2FAF4), DauVietColors.parchmentSurface]
                  : [const Color(0xFFFDF4F2), DauVietColors.parchmentSurface],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // DUY NHẤT 1 LINH VẬT KABI TO LỚN Ở TRUNG TÂM (140x140)
                KabiMascotWidget(
                  mood: isSuccess ? KabiMood.cheering : KabiMood.thinking,
                  width: 140,
                  height: 140,
                  headOnly: false,
                ),
                const SizedBox(height: 18),
                // Huy hiệu trạng thái (loại bỏ hoàn toàn icon vui / buồn gây nhiễu trước mascot)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeBorder, width: 1.4),
                  ),
                  child: Text(
                    title,
                    style: DauVietTypography.headlineMedium.copyWith(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Thẻ giải thích sử liệu
                if (fb != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: DauVietColors.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      fb.text,
                      textAlign: TextAlign.center,
                      style: DauVietTypography.bodyMedium.copyWith(
                        color: DauVietColors.inkText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                const Spacer(),
                // Nút 3D Tiếp tục câu hỏi
                DongSonButton(
                  label: 'TIẾP TỤC ›',
                  icon: Icons.arrow_forward_rounded,
                  variant: isSuccess
                      ? DongSonButtonVariant.natureGreen
                      : DongSonButtonVariant.primaryCinnabar,
                  isLoading: st.submitting,
                  height: 52,
                  onPressed: st.submitting ? null : _onContinue,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thẻ feedback theo `_FeedbackTone` — Duolingo style sheet banner kèm Mascot Kabi TO RÕ.
  Widget _feedbackCard(_Feedback fb) {
    final (icon, iconColor, fgColor) = switch (fb.tone) {
      _FeedbackTone.success => (
        Icons.check_circle_rounded,
        const Color(0xFF2E7D32),
        const Color(0xFF1E5633),
      ),
      _FeedbackTone.warning => (
        Icons.info_rounded,
        DauVietColors.imperialGold,
        const Color(0xFF7A5B18),
      ),
      _FeedbackTone.error => (
        Icons.cancel_rounded,
        DauVietColors.cinnabarRed,
        DauVietColors.cinnabarRed,
      ),
      _FeedbackTone.info => (
        Icons.lightbulb_rounded,
        DauVietColors.imperialGold,
        DauVietColors.inkText,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fb.text,
              style: DauVietTypography.bodyMedium.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(_PlayerState st) {
    return Expanded(
      child: GoldConfettiOverlay(
        trigger: true,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KabiMascotWidget(
                  mood: KabiMood.victory,
                  width: 130,
                  height: 130,
                  headOnly: false,
                ),
                const SizedBox(height: 18),
                Text(
                  'HOÀN THÀNH BÀI HỌC!',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.headlineMedium.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: DauVietColors.inkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chúc mừng Sĩ Tử đã khám phá trọn vẹn sự kiện lịch sử này.',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodyMedium.copyWith(
                    color: DauVietColors.inkMuted,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã hết hoạt động bắt buộc.',
                  textAlign: TextAlign.center,
                  style: DauVietTypography.bodySmall.copyWith(
                    color: DauVietColors.inkMuted.withValues(alpha: 0.75),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 18),
                if (st.feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _feedbackCard(st.feedback!),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: Tactile3DButton(
                    label: _completing || _fetchingResult
                        ? 'ĐANG TỔNG KẾT...'
                        : _completionAcknowledged
                        ? 'THỬ TẢI KẾT QUẢ'
                        : 'HOÀN THÀNH BÀI HỌC',
                    icon: Icons.emoji_events_rounded,
                    variant: Tactile3DVariant.primaryCinnabar,
                    height: 50,
                    depth: 4.0,
                    onPressed: _completing || _fetchingResult
                        ? () {}
                        : _complete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  /// GAME-03: thông báo trừ Thể lực kiểu game — toast overlay trượt lên
  /// từ đáy (badge "-N ⚡ Thể lực") + rung nhẹ. Dùng Overlay trực tiếp thay
  /// vì SnackBar để kiểm soát animation + không bị che bởi bottom bar.
  /// Rung medium = cảm giác "bị phạt" chứ không phải lỗi hệ thống.
  void _showEnergyPenaltyToast(int amount) {
    _dismissEnergyPenaltyToast();
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _EnergyPenaltyToast(
        amount: amount,
        onDone: () {
          if (_energyToastEntry == entry) {
            _energyToastEntry = null;
          }
          entry.remove();
        },
      ),
    );
    _energyToastEntry = entry;
    overlay.insert(entry);
  }
}

/// Banner "-N Thể lực" trượt lên từ đáy màn — tự gỡ sau ~2.2s.
/// reduceMotion (MediaQuery.disableAnimations) → hiện tĩnh không trượt.
class _EnergyPenaltyToast extends StatefulWidget {
  final int amount;
  final VoidCallback onDone;

  const _EnergyPenaltyToast({required this.amount, required this.onDone});

  @override
  State<_EnergyPenaltyToast> createState() => _EnergyPenaltyToastState();
}

class _EnergyPenaltyToastState extends State<_EnergyPenaltyToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.16, curve: Curves.easeOutBack),
          ),
        );
    _fade = CurvedAnimation(
      parent: _ctrl,
      // Fade out ở 15% cuối — giữ đọc được gần hết thời gian.
      curve: const Interval(0.0, 0.85, curve: Curves.linear),
      reverseCurve: Curves.easeIn,
    );
    _ctrl.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget badge = FadeTransition(
      opacity: reduceMotion ? const AlwaysStoppedAnimation(1.0) : _fade,
      child: SlideTransition(
        position: reduceMotion
            ? const AlwaysStoppedAnimation(Offset.zero)
            : _slide,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 168),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: DauVietColors.cinnabarRed,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: DauVietColors.imperialGoldLight,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 18,
                      color: DauVietColors.imperialGoldLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '-${widget.amount} Thể lực',
                      style: DauVietTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Positioned.fill(child: IgnorePointer(child: badge));
  }
}

/// STREAK-01: huy hiệu ngọn lửa chuỗi ngày trên thanh header của player —
/// số thật từ streakProvider (được applyStreakInfo cập nhật ngay khi hoàn
/// thành bài), loading/error hiện '—' chứ không bịa số.
class _StreakBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final String value = streakAsync.when(
      data: (s) => '${s.currentStreak}',
      loading: () => '—',
      error: (_, _) => '—',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: 2),
          Text(
            value,
            style: DauVietTypography.labelSmall.copyWith(
              color: const Color(0xFFE65100),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip nhỏ báo activity có chấm điểm sẽ trừ Thể lực khi sai — đặt ngay trên
/// renderer để learner thấy chi phí trước khi quyết định. Không block UI.
class _EnergyCostHint extends StatelessWidget {
  final int penalty;
  const _EnergyCostHint({required this.penalty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DauVietColors.imperialGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DauVietColors.imperialGold.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 15,
            color: DauVietColors.imperialGold,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Hoạt động chấm điểm — trả lời sai mất $penalty Thể lực',
              style: DauVietTypography.bodySmall.copyWith(
                fontSize: 11.5,
                color: const Color(0xFF7A5B18),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
