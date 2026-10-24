package com.dauviet.learning.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import com.dauviet.common.api.PageResponse;
import com.dauviet.learning.api.dto.AttemptProgressResponse;
import com.dauviet.learning.api.dto.AttemptStartResponse;
import com.dauviet.learning.api.dto.AttemptSummaryResponse;
import com.dauviet.learning.api.dto.CompleteAttemptResponse;
import com.dauviet.learning.api.dto.CurrentActivityResponse;
import com.dauviet.learning.api.dto.LessonResultResponse;
import com.dauviet.learning.api.dto.SubmitActivityResponse;
import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.learning.contract.LessonCompletion;
import com.dauviet.learning.domain.ActivityAttempt;
import com.dauviet.learning.domain.ActivityNotAvailableException;
import com.dauviet.learning.domain.AttemptAlreadyCompletedException;
import com.dauviet.learning.domain.AttemptIncompleteException;
import com.dauviet.learning.domain.AttemptNotFoundException;
import com.dauviet.learning.domain.AttemptNotInProgressException;
import com.dauviet.learning.domain.AttemptNotOwnedException;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.domain.LearnerAttempt;
import com.dauviet.learning.domain.LearnerAttemptStatus;
import com.dauviet.learning.domain.LessonResult;
import com.dauviet.learning.domain.ResultNotFoundException;
import com.dauviet.learning.handler.ActivityHandler;
import com.dauviet.learning.handler.ActivityHandlerRegistry;
import com.dauviet.learning.infrastructure.persistence.ActivityAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.learning.resolver.LessonCompletionEvaluator;
import com.dauviet.learning.resolver.StageTransitionResolver;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.dauviet.lesson.api.dto.LearnerLessonContent;
import com.dauviet.lesson.application.LearnerProjectionService;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonNotFoundException;
import com.dauviet.lesson.domain.LessonNotPublishedException;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.dauviet.lesson.domain.VersionNotFoundException;
import com.dauviet.lesson.draft.ActivityType;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import jakarta.persistence.EntityManager;

/**
 * Server-authoritative attempt runtime (LEARNING_ENGINE_DESIGN §8).
 * Start/resume pins the attempt to lessons.current_version_id; submits
 * evaluate through the pinned snapshot only — republishing never mutates a
 * running attempt. Completion is REPORTED in responses but does not flip
 * status or write lesson_results (TASK-0012 owns that transition).
 */
@Service
public class LearnerAttemptService {

    private static final Logger log = LoggerFactory.getLogger(LearnerAttemptService.class);

    private final LearnerAttemptRepository attempts;
    private final ActivityAttemptRepository activityAttempts;
    private final LessonResultRepository lessonResults;
    private final LessonRepository lessons;
    private final LessonVersionRepository versions;
    private final ActivityHandlerRegistry handlers;
    private final StageTransitionResolver transitionResolver;
    private final LessonCompletionEvaluator completionEvaluator;
    private final LearnerProjectionService projection;
    private final IdempotencyService idempotency;
    private final com.dauviet.collection.application.EvidenceCollectionRecorder collectionRecorder;
    private final com.dauviet.collection.application.EventMilestoneRecorder eventMilestones;
    private final com.dauviet.reward.application.RewardGrantService rewardGrants;
    private final com.dauviet.reward.application.ItemUnlockService itemUnlocks;
    private final com.dauviet.reward.application.RewardService rewardService;
    private final com.dauviet.energy.application.EnergyService energyService;
    private final GradedActivityClassifier gradedClassifier;
    private final ObjectMapper mapper;
    private final TransactionTemplate txTemplate;
    private final EntityManager entityManager;

    public LearnerAttemptService(LearnerAttemptRepository attempts,
                                 ActivityAttemptRepository activityAttempts,
                                 LessonResultRepository lessonResults,
                                 LessonRepository lessons,
                                 LessonVersionRepository versions,
                                 ActivityHandlerRegistry handlers,
                                 StageTransitionResolver transitionResolver,
                                 LessonCompletionEvaluator completionEvaluator,
                                 LearnerProjectionService projection,
                                 IdempotencyService idempotency,
                                 com.dauviet.collection.application
                                         .EvidenceCollectionRecorder collectionRecorder,
                                 com.dauviet.collection.application
                                         .EventMilestoneRecorder eventMilestones,
                                 com.dauviet.reward.application
                                         .RewardGrantService rewardGrants,
                                 com.dauviet.reward.application
                                         .ItemUnlockService itemUnlocks,
                                 com.dauviet.reward.application
                                         .RewardService rewardService,
                                 com.dauviet.energy.application
                                         .EnergyService energyService,
                                 GradedActivityClassifier gradedClassifier,
                                 ObjectMapper mapper,
                                 org.springframework.transaction
                                         .PlatformTransactionManager txManager,
                                 EntityManager entityManager) {
        this.attempts = attempts;
        this.activityAttempts = activityAttempts;
        this.lessonResults = lessonResults;
        this.lessons = lessons;
        this.versions = versions;
        this.handlers = handlers;
        this.transitionResolver = transitionResolver;
        this.completionEvaluator = completionEvaluator;
        this.projection = projection;
        this.idempotency = idempotency;
        this.collectionRecorder = collectionRecorder;
        this.eventMilestones = eventMilestones;
        this.rewardGrants = rewardGrants;
        this.itemUnlocks = itemUnlocks;
        this.rewardService = rewardService;
        this.energyService = energyService;
        this.gradedClassifier = gradedClassifier;
        this.mapper = mapper;
        this.txTemplate = new TransactionTemplate(txManager);
        this.entityManager = entityManager;
    }

    /**
     * Start a new attempt or resume the IN_PROGRESS one FOR THE LESSON —
     * resume is scoped to the lesson, not the version (TASK-0012): an
     * in-flight attempt pinned to v1 is returned even after a v2 republish,
     * so progress survives republishing and a second attempt is never
     * created for the same lesson.
     */
    /**
     * Two explicit transactions via TransactionTemplate (avoids self-invocation
     * pitfalls): a concurrent start that loses the partial-unique-index race
     * rolls its tx back aborted, so the resume re-query must run in a FRESH tx.
     */
    public AttemptStartResponse startOrResume(UUID userId, UUID lessonId) {
        try {
            return txTemplate.execute(tx -> doStartOrResume(userId, lessonId));
        } catch (org.springframework.dao.DataIntegrityViolationException dup) {
            // ux_attempt_active_user_version fired on the loser's insert — the
            // winner's row is committed; resume it in a new tx, never a 500.
            return txTemplate.execute(tx -> resumeAfterRace(userId, lessonId, dup));
        }
    }

    private AttemptStartResponse doStartOrResume(UUID userId, UUID lessonId) {
        // Per-(user, lesson) advisory lock for the WHOLE tx (TASK-0012 review):
        // the partial unique index only covers (user_id, lesson_version_id),
        // so two concurrent starts racing a republish could each pin a
        // different version and create TWO IN_PROGRESS attempts for one
        // lesson. The lock serializes check+insert for this pair; version
        // pinning is unchanged — whichever current_version_id is read under
        // the lock is what the single attempt pins to.
        entityManager.createNativeQuery(
                "select pg_advisory_xact_lock(hashtextextended(:k, 0::bigint))")
                .setParameter("k", userId + "|" + lessonId)
                .getSingleResult();

        Lesson lesson = lessons.findById(lessonId)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + lessonId));

        var existing = attempts.findInProgressByUserIdAndLessonId(userId, lessonId);
        if (existing.isPresent()) {
            LearnerAttempt a = existing.get();
            return new AttemptStartResponse(a.getId(), a.getLessonVersionId(),
                    a.getStatus().name(), true,
                    a.getCurrentStageId(), a.getCurrentActivityId());
        }

        if (lesson.getStatus() != LessonStatus.PUBLISHED || lesson.getCurrentVersionId() == null) {
            throw new LessonNotPublishedException("lesson is not published: " + lessonId);
        }
        UUID versionId = lesson.getCurrentVersionId();

        SnapshotModel model = snapshotOf(versionId);
        AttemptState state = new AttemptState();
        state.setCurrentStageId(model.entryStageId());
        state.setCurrentActivityId(model.firstRequiredActivityId(model.entryStageId()));
        LearnerAttempt attempt = LearnerAttempt.start(userId, versionId);
        attempt.recordProgress(state);
        attempts.saveAndFlush(attempt);
        return new AttemptStartResponse(attempt.getId(), versionId,
                attempt.getStatus().name(), false,
                state.currentStageId(), state.currentActivityId());
    }

    /** Re-query after a lost start race; rethrows if the row is truly absent. */
    private AttemptStartResponse resumeAfterRace(UUID userId, UUID lessonId,
                                                 org.springframework.dao
                                                         .DataIntegrityViolationException dup) {
        return attempts.findInProgressByUserIdAndLessonId(userId, lessonId)
                .map(a -> new AttemptStartResponse(a.getId(),
                        a.getLessonVersionId(), a.getStatus().name(), true,
                        a.getCurrentStageId(), a.getCurrentActivityId()))
                .orElseThrow(() -> dup);
    }

    /** Attempt progress + completion verdict; owner only. */
    @Transactional(readOnly = true)
    public AttemptProgressResponse getAttempt(UUID userId, UUID attemptId) {
        LearnerAttempt a = loadOwned(userId, attemptId);
        SnapshotModel model = snapshotOf(a.getLessonVersionId());
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
        return new AttemptProgressResponse(a.getId(), a.getLessonVersionId(),
                a.getStatus().name(), state.currentStageId(), state.currentActivityId(),
                progressOf(model, state), completionEvaluator.evaluate(model, state));
    }

    /** Learner-safe view of the activity the cursor points at. */
    @Transactional(readOnly = true)
    public CurrentActivityResponse getCurrent(UUID userId, UUID attemptId) {
        LearnerAttempt a = loadOwned(userId, attemptId);
        SnapshotModel model = snapshotOf(a.getLessonVersionId());
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));

        JsonNode stage = state.currentStageId() == null
                ? null : model.stageById(state.currentStageId());
        JsonNode activity = state.currentActivityId() == null
                ? null : model.activityById(state.currentActivityId());

        CurrentActivityResponse.Stage stageDto = stage == null ? null
                : new CurrentActivityResponse.Stage(
                        stage.path("id").asText(),
                        stage.path("type").asText(null),
                        stage.hasNonNull("title") ? stage.get("title").asText() : null);
        CurrentActivityResponse.Activity activityDto = null;
        if (activity != null) {
            ObjectNode projected = projection.projectActivity(activity, state.outputs());
            activityDto = new CurrentActivityResponse.Activity(
                    activity.path("id").asText(),
                    activity.path("type").asText(null),
                    activity.hasNonNull("instruction")
                            ? activity.get("instruction").asText() : null,
                    projected.get("config"), projected.get("feedback"));
        }
        return new CurrentActivityResponse(stageDto, activityDto,
                progressOf(model, state));
    }

    /**
     * Evaluate one submission inside a pessimistic-locked transaction.
     * Accepts the activity at the cursor, or any OPTIONAL activity inside the
     * current stage (submittable without moving the cursor — optional work is
     * experienced or skipped freely). A retried submit after advancement past
     * a required activity reads as ACTIVITY_NOT_AVAILABLE; required activity
     * submits that stay incomplete keep the cursor so retries are possible.
     */
    @Transactional
    public SubmitActivityResponse submit(UUID userId, UUID attemptId,
                                         String activityId, JsonNode answer,
                                         String idempotencyKey) {
        // Lock the attempt row BEFORE touching idempotency_records so a
        // concurrent duplicate blocks on the lock, then sees the committed
        // response — never a double-write (brief §3/§7).
        LearnerAttempt a = attempts.findForUpdate(attemptId)
                .orElseThrow(() -> new AttemptNotFoundException("attempt not found: " + attemptId));
        if (!a.getUserId().equals(userId)) {
            throw new AttemptNotOwnedException("attempt not owned by user: " + attemptId);
        }
        String operation = "SUBMIT_ACTIVITY";
        String fingerprint = attemptId + "|" + activityId + "|"
                + idempotency.canonical(answer);
        return idempotency.execute(userId, operation, idempotencyKey, fingerprint,
                () -> doSubmit(userId, a, activityId, answer, idempotencyKey),
                SubmitActivityResponse.class);
    }

    private SubmitActivityResponse doSubmit(UUID userId, LearnerAttempt a,
                                            String activityId, JsonNode answer,
                                            String idempotencyKey) {
        if (a.getStatus() == LearnerAttemptStatus.COMPLETED) {
            // Dedicated code (plan decision #6): completed is terminal —
            // submits get 409 ATTEMPT_ALREADY_COMPLETED, not the generic
            // not-in-progress signal.
            throw new AttemptAlreadyCompletedException(
                    "attempt " + a.getId() + " is COMPLETED");
        }
        if (a.getStatus() != LearnerAttemptStatus.IN_PROGRESS) {
            throw new AttemptNotInProgressException(
                    "attempt " + a.getId() + " is " + a.getStatus());
        }
        SnapshotModel model = snapshotOf(a.getLessonVersionId());
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
        JsonNode activity = model.activityById(activityId);
        boolean onCursor = activityId != null
                && activityId.equals(state.currentActivityId());
        // Optional activities in the CURRENT stage are submittable without
        // moving the cursor — learners experience them or skip past freely.
        boolean optionalInStage = !onCursor && activity != null
                && !activity.path("required").asBoolean(false)
                && state.currentStageId() != null
                && state.currentStageId().equals(model.stageIdOf(activityId));
        if (!onCursor && !optionalInStage) {
            throw new ActivityNotAvailableException(
                    "activity " + activityId + " is not the current activity");
        }
        if (activity == null) {
            throw new SnapshotCorruptException(
                    "current activity missing from pinned snapshot: " + activityId);
        }

        ActivityType type = ActivityType.valueOf(activity.path("type").asText());
        // GAME-02: zero-energy gate chỉ áp cho activity có chấm điểm — chạy
        // sau khi xác định activity hợp lệ + trước evaluate (lazy-recover
        // đã tính bên trong; replay idempotent không bao giờ tới đây vì
        // idempotency.execute trả stored response trước). Ungraded/passive
        // không bao giờ bị chặn.
        boolean graded = gradedClassifier.isGraded(activity);
        if (graded) {
            energyService.gateForGradedSubmit(userId);
        }
        ActivityHandler handler = handlers.handlerFor(type);
        AttemptContext ctx = new AttemptContext(a.getId(), userId,
                a.getLessonVersionId(), state.currentStageId(), activityId,
                state.currentActivityId(),
                activity, model.root(), state.outputs(), state.attemptCounts());
        ActivityResult result = handler.evaluate(ctx,
                new ActivitySubmission(a.getId(), activityId, answer, idempotencyKey));

        state.bumpAttemptCount(activityId);
        state.recordOutput(activityId, result.output());
        if (result.completed()) {
            state.markCompleted(activityId);
        } else {
            // FIX 2 (TASK-0020): a re-submission graded incomplete must drop
            // the stale completion mark — a completed flag referring to a
            // since-overwritten output is a correctness leak (lesson could
            // complete while required work is actually unfinished).
            // Incorrect-but-exhausted still reports completed=true via the
            // handler contract, so this branch only fires for genuinely
            // incomplete evaluations.
            state.removeCompleted(activityId);
        }
        invalidateDependents(model, state, activityId);
        // TASK-0022: collect evidence đã chọn & validate sau khi submission
        // được chấp nhận — cùng transaction, upsert idempotent. Chỉ
        // EVIDENCE_SELECT (EXPLORE_MAP/clue chưa có evidence reference tường
        // minh trong contract → không suy diễn markerId).
        if (result.completed() && type == ActivityType.EVIDENCE_SELECT
                && result.output() != null) {
            LessonVersion pinned = versions.findById(a.getLessonVersionId())
                    .orElse(null);
            collectionRecorder.record(userId, a.getId(),
                    result.output().get("selectedEvidenceIds"), model,
                    pinned == null ? null : pinned.getLessonId());
            // TASK-0023: COLLECTION_COUNT rules đánh giá ngay trong tx của
            // submit — vật phẩm mở khóa commit cùng evidence vừa collect.
            itemUnlocks.evaluateAfterEvidenceCollected(userId,
                    pinned == null ? null : pinned.getLessonId(), a.getId());
        }
        int attemptNo = activityAttempts
                .countByLearnerAttemptIdAndActivityId(a.getId(), activityId) + 1;
        // GAME-02: penalty debit TRONG cùng transaction — verdict INCORRECT
        // của activity có chấm điểm trừ min(penalty, current). cause_key theo
        // (attempt, activity, attemptNo) nên retry hợp lệ trừ một lần/lần
        // submit; PARTIAL/CONTRADICTED/payload lỗi (đã throw ở evaluate) và
        // idempotent replay không trừ. Lỗi ở đây rollback cả submission.
        int energyDeducted = gradedClassifier.penalizableIncorrect(activity, result)
                ? energyService.settleAfterSubmission(userId, a.getId(),
                        activityId, attemptNo)
                : 0;
        // FIX 7: snapshot energy SAU settle (cùng row-lock đã giữ) — client
        // biết balance mới kể cả khi server vừa lazy-recover trước submit,
        // không phải suy từ energyDeducted. Đọc lại trong tx rẻ.
        var energySnapshot = energyService.snapshot(userId);
        activityAttempts.save(ActivityAttempt.of(a.getId(), activityId, attemptNo,
                answer == null ? "{}" : answer.toString(), resultJson(result)));

        StageTransitionResolver.Transition transition = optionalInStage ? null
                : transitionResolver.resolve(model, state, activityId, result.outcome());
        if (!optionalInStage && transition != null && transition.nextStage() != null) {
            state.setCurrentStageId(transition.nextStage().stageId());
            state.setCurrentActivityId(
                    model.firstRequiredActivityId(transition.nextStage().stageId()));
        } else if (!optionalInStage && transition != null && transition.nextActivity() != null) {
            state.setCurrentActivityId(transition.nextActivity().activityId());
        }
        // transition == null or optional submit: keep cursor unchanged.
        a.recordProgress(state);
        attempts.save(a);

        LessonCompletion completion = completionEvaluator.evaluate(model, state);
        SubmitActivityResponse.Next next = nextDto(model, state, transition, optionalInStage);
        return new SubmitActivityResponse("ACCEPTED", result, result.completed(),
                progressOf(model, state), next, completion, energyDeducted,
                energySnapshot);
    }

    /**
     * Server-authoritative completion (brief §5): re-evaluates the published
     * completion config against persisted state; refuses incomplete attempts
     * with 409 ATTEMPT_INCOMPLETE; on success flips status to COMPLETED and
     * writes exactly one lesson_results row in the same transaction.
     * Repeated/concurrent calls are idempotent — the pessimistic lock
     * serializes them and the second caller reads the stored result.
     */
    @Transactional
    public CompleteAttemptResponse complete(UUID userId, UUID attemptId,
                                            String idempotencyKey) {
        LearnerAttempt a = attempts.findForUpdate(attemptId)
                .orElseThrow(() -> new AttemptNotFoundException("attempt not found: " + attemptId));
        if (!a.getUserId().equals(userId)) {
            throw new AttemptNotOwnedException("attempt not owned by user: " + attemptId);
        }
        String operation = "COMPLETE_ATTEMPT";
        return idempotency.execute(userId, operation, idempotencyKey,
                attemptId.toString(),
                () -> doComplete(userId, a), CompleteAttemptResponse.class);
    }

    private CompleteAttemptResponse doComplete(UUID userId, LearnerAttempt a) {
        SnapshotModel model = snapshotOf(a.getLessonVersionId());
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
        var progress = progressOf(model, state);

        if (a.getStatus() == LearnerAttemptStatus.COMPLETED) {
            // Idempotent repeat: return the stored facts, never rewrite.
            LessonCompletion verdict = completionEvaluator.evaluate(model, state);
            return CompleteAttemptResponse.of(a.getId(), a.getStatus().name(),
                    true, a.getCompletedAt(), verdict, progress);
        }
        if (a.getStatus() != LearnerAttemptStatus.IN_PROGRESS) {
            throw new AttemptNotInProgressException(
                    "attempt " + a.getId() + " is " + a.getStatus());
        }

        LessonCompletion verdict = completionEvaluator.evaluate(model, state);
        if (!verdict.complete()) {
            throw new AttemptIncompleteException(
                    "attempt " + a.getId() + " is not complete", verdict.detail());
        }

        a.markCompleted();
        attempts.save(a);
        BigDecimal score = scoreOf(progress);
        BigDecimal knowledgeScore = knowledgeScoreOf(model, state);
        String resultJson = resultJsonOf(a, verdict, progress, score, knowledgeScore);
        lessonResults.save(LessonResult.of(a.getId(), score, resultJson,
                a.getCompletedAt()));
        // TASK-0023: thưởng + vật phẩm mở khóa ghi TRONG cùng transaction —
        // attempt chưa coi là hoàn thành nếu phần thưởng chưa ghi được,
        // và rollback của bất kỳ phần nào trả cả về trạng thái chưa hoàn
        // thành. Idempotent: repeat complete vào nhánh alreadyCompleted ở
        // trên, không chạm tới đây; cause_key/UNIQUE(user,item) chặn race.
        LessonVersion completedVersion = versions.findById(a.getLessonVersionId())
                .orElse(null);
        java.util.Set<UUID> newlyUnlockedDossiers = java.util.Set.of();
        if (completedVersion != null) {
            UUID lessonId = completedVersion.getLessonId();
            rewardGrants.grantFirstCompletion(userId, lessonId, a.getId());
            // GAME-04 + GAME-05 ordering: ghi milestone event TRƯỚC khi đánh
            // giá item rules — leaf EVENT_COMPLETED/EVENT_MASTERED/
            // TOTAL_EVENTS_* phải nhìn thấy milestone vừa ghi trong cùng
            // tx, không thể đọc snapshot cũ (bug ordering V1: item chạy
            // trước milestone → rule event-scoped không bao giờ grant cùng
            // lượt complete cuối). Lesson không gắn event → bỏ qua.
            UUID eventId = lessons.findById(lessonId)
                    .map(Lesson::getEventId).orElse(null);
            if (eventId != null) {
                // Truyền lessonId/attemptId đang complete: item grant qua
                // leaf EVENT_* trong cùng tx này ghi source_attempt_id đúng
                // → GET /attempts/{id}/result hiển thị đúng (FIX FINAL-1).
                newlyUnlockedDossiers = eventMilestones.recordIfEarned(
                        userId, eventId, lessonId, a.getId());
            }
            itemUnlocks.evaluateAfterLessonCompletion(userId, lessonId,
                    a.getId());
        }
        return new CompleteAttemptResponse(a.getId(), a.getStatus().name(),
                false, a.getCompletedAt(), verdict, progress,
                List.copyOf(newlyUnlockedDossiers));
    }

    /**
     * Learner-safe projected content of the attempt's PINNED lesson version
     * (TASK-0018): unlike GET /lessons/{id}/content which always serves the
     * current published version, this keeps a resumed attempt consistent after
     * an admin republish — evidence[]/assets[] embeds and stage config all
     * come from the same snapshot the submissions are graded against.
     */
    @Transactional(readOnly = true)
    public LearnerLessonContent getContent(UUID userId, UUID attemptId) {
        LearnerAttempt a = loadOwned(userId, attemptId);
        LessonVersion v = versions.findById(a.getLessonVersionId())
                .orElseThrow(() -> new VersionNotFoundException(
                        "lesson version missing: " + a.getLessonVersionId()));
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
        return new LearnerLessonContent(v.getLessonId(), v.getId(),
                v.getVersionNo(),
                projection.project(parse(v.getSnapshotJson()), state.outputs()));
    }

    /** Persisted lesson_results for an owned, completed attempt. */
    @Transactional(readOnly = true)
    public LessonResultResponse getResult(UUID userId, UUID attemptId) {
        LearnerAttempt a = loadOwned(userId, attemptId);
        LessonResult r = lessonResults.findByLearnerAttemptId(a.getId())
                .orElseThrow(() -> new ResultNotFoundException(
                        "no result for attempt: " + attemptId));
        // TASK-0023 additive: thưởng + vật phẩm attempt này đã kích hoạt —
        // đọc từ ledger/inventory thật, rỗng nếu attempt chưa cấp gì.
        return new LessonResultResponse(a.getId(), a.getLessonVersionId(),
                a.getStatus().name(), r.getScore(), parse(r.getResultJson()),
                r.getCompletedAt(), a.getStartedAt(),
                rewardService.rewardsOfAttempt(a.getId()),
                rewardService.itemsUnlockedByAttempt(a.getId()));
    }

    /**
     * Learner's own attempt history/resume list — paged, newest activity
     * first; IN_PROGRESS rows carry the resume cursor for the mobile client.
     */
    @Transactional(readOnly = true)
    public PageResponse<AttemptSummaryResponse> listMyAttempts(UUID userId,
                                                             LearnerAttemptStatus status,
                                                             Pageable pageable) {
        var page = status == null
                ? attempts.findByUserIdOrderByLastActiveAtDesc(userId, pageable)
                : attempts.findByUserIdAndStatusOrderByLastActiveAtDesc(
                        userId, status, pageable);
        return PageResponse.from(page.map(a -> summaryOf(userId, a)));
    }

    /**
     * Mobile resume surface: IN_PROGRESS attempts (bounded at 50 — one per
     * lesson makes unbounded growth unlikely, but the cap keeps the payload
     * predictable) + completed count.
     */
    @Transactional(readOnly = true)
    public com.dauviet.learning.api.dto.MyProgressResponse myProgress(UUID userId) {
        List<LearnerAttempt> inProgress = attempts
                .findByUserIdAndStatusOrderByLastActiveAtDesc(
                        userId, LearnerAttemptStatus.IN_PROGRESS,
                        org.springframework.data.domain.PageRequest.of(0, 50))
                .getContent();
        long completed = attempts.countByUserIdAndStatus(
                userId, LearnerAttemptStatus.COMPLETED);
        return new com.dauviet.learning.api.dto.MyProgressResponse(
                inProgress.stream().map(a -> summaryOf(userId, a)).toList(),
                completed);
    }

    private AttemptSummaryResponse summaryOf(UUID userId, LearnerAttempt a) {
        AttemptProgressResponse.Progress progress;
        UUID lessonId = null;
        try {
            LessonVersion v = versions.findById(a.getLessonVersionId()).orElse(null);
            lessonId = v == null ? null : v.getLessonId();
            SnapshotModel model = v == null ? null
                    : SnapshotModel.parse(parse(v.getSnapshotJson()));
            AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
            progress = model == null
                    ? new AttemptProgressResponse.Progress(0, 0)
                    : progressOf(model, state);
        } catch (RuntimeException corrupt) {
            progress = new AttemptProgressResponse.Progress(0, 0);
        }
        return new AttemptSummaryResponse(a.getId(), lessonId,
                a.getLessonVersionId(), a.getStatus().name(),
                a.getCurrentStageId(), a.getCurrentActivityId(), progress,
                a.getStartedAt(), a.getLastActiveAt(), a.getCompletedAt());
    }

    /**
     * Completion percentage (0-100, 2 decimals), NOT an assessment score:
     * completedRequired counts activities marked completed — including ones
     * exhausted on incorrect retries — over totalRequired. BA does not define
     * a separate assessment metric; do not reinterpret this field.
     */
    private BigDecimal scoreOf(AttemptProgressResponse.Progress p) {
        if (p.totalRequired() == 0) return BigDecimal.ZERO.setScale(2);
        return BigDecimal.valueOf(p.completedRequired() * 100.0 / p.totalRequired())
                .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * Knowledge score (0-100) = mean per-activity correctness over REQUIRED
     * GRADED activities only — deliberately separate from `score` (progress %).
     * A required activity contributes to the metric only when it carries a
     * real grading rule (config.graded:true, or a CER_CHOICE conclusion that
     * is graded by contract); ungraded required work (READ, HYPOTHESIS_CHOICE,
     * DRAG_ORDER, EXPLORE_MAP, REFLECTION, legacy count-only EVIDENCE_SELECT)
     * never inflates the denominator. Per-activity contribution: graded output
     * `score` (0..1) when present, else `correct` (1/0); exhausted work keeps
     * its partial score — never free credit. A lesson with zero graded
     * required activities reports 0 — there is no measured knowledge to claim.
     */
    private BigDecimal knowledgeScoreOf(SnapshotModel model, AttemptState state) {
        double sum = 0.0;
        int total = 0;
        for (JsonNode stage : model.stages()) {
            for (JsonNode act : model.requiredActivities(stage.path("id").asText())) {
                if (!isGradedActivity(act)) continue;
                total++;
                String id = act.path("id").asText();
                JsonNode out = state.outputs().get(id);
                if (out != null && out.hasNonNull("score")) {
                    sum += out.get("score").asDouble(0.0);
                } else if (out != null && out.hasNonNull("correct")) {
                    sum += out.get("correct").asBoolean(false) ? 1.0 : 0.0;
                }
            }
        }
        if (total == 0) return BigDecimal.ZERO.setScale(2);
        return BigDecimal.valueOf(sum * 100.0 / total)
                .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * True when an activity has a real grading rule feeding knowledgeScore.
     * Two classes (FIX 3, TASK-0020):
     *  - contract-graded types whose evaluation contract emits a `correct`
     *    verdict on every submission: MULTIPLE_CHOICE (vs correctOptionIds),
     *    MATCHING (vs correctPairs), DRAG_ORDER (vs expectedOrder/accepted
     *    sequences), CER_CHOICE (vs acceptedCombos);
     *  - opt-in graded mode: config.graded:true (EVIDENCE_SELECT,
     *    REASONING_CONNECT — the flag is what turns their evaluation into a
     *    correctness judgement; ungraded they stay count-/syntax-only).
     * Excluded: READ/VIEW_IMAGE/EXPLORE_MAP/HYPOTHESIS_CHOICE/
     * REFLECTION_PROMPT (no correctness), legacy CER (length-only), and
     * VERIFICATION — it emits a hypothesis-support verdict
     * (SUPPORTED/PARTIAL/CONTRADICTED) against requiredEvidenceIds, not a
     * learner-answer correctness score.
     */
    private boolean isGradedActivity(JsonNode act) {
        return gradedClassifier.isGraded(act);
    }

    private String resultJsonOf(LearnerAttempt a, LessonCompletion verdict,
                                AttemptProgressResponse.Progress progress,
                                BigDecimal score, BigDecimal knowledgeScore) {
        ObjectNode node = mapper.createObjectNode();
        node.put("attemptId", a.getId().toString());
        node.put("lessonVersionId", a.getLessonVersionId().toString());
        node.put("reason", verdict.reason());
        node.put("score", score.doubleValue());
        node.put("knowledgeScore", knowledgeScore.doubleValue());
        node.put("completedRequired", progress.completedRequired());
        node.put("totalRequired", progress.totalRequired());
        if (verdict.detail() != null) node.set("detail", verdict.detail());
        return node.toString();
    }

    /**
     * Build the learner-facing `next` pointer: for optional off-cursor submits
     * the cursor did not move, so `next` echoes the unchanged cursor; for
     * on-cursor submits it mirrors the resolver transition.
     */
    private SubmitActivityResponse.Next nextDto(SnapshotModel model, AttemptState state,
                                                StageTransitionResolver.Transition transition,
                                                boolean optionalInStage) {
        if (optionalInStage) {
            if (state.currentActivityId() == null) return null;
            return cursorNext(model, state.currentStageId(), state.currentActivityId());
        }
        if (transition == null) return null;
        if (transition.nextActivity() != null) {
            var na = transition.nextActivity();
            return cursorNext(model, na.stageId(), na.activityId());
        }
        return new SubmitActivityResponse.Next(
                transition.nextStage().stageId(),
                model.firstRequiredActivityId(transition.nextStage().stageId()),
                null, null);
    }

    private SubmitActivityResponse.Next cursorNext(SnapshotModel model,
                                                   String stageId, String activityId) {
        JsonNode act = model.activityById(activityId);
        JsonNode projectedConfig = act == null ? null
                : projection.projectActivity(act).get("config");
        return new SubmitActivityResponse.Next(stageId, activityId,
                act == null ? null : act.path("type").asText(null),
                projectedConfig);
    }

    /* ---------- internals ---------- */

    private LearnerAttempt loadOwned(UUID userId, UUID attemptId) {
        LearnerAttempt a = attempts.findById(attemptId)
                .orElseThrow(() -> new AttemptNotFoundException("attempt not found: " + attemptId));
        if (!a.getUserId().equals(userId)) {
            throw new AttemptNotOwnedException("attempt not owned by user: " + attemptId);
        }
        return a;
    }

    private SnapshotModel snapshotOf(UUID versionId) {
        LessonVersion v = versions.findById(versionId)
                .orElseThrow(() -> new VersionNotFoundException(
                        "lesson version missing: " + versionId));
        return SnapshotModel.parse(parse(v.getSnapshotJson()));
    }

    /**
     * Dependency-aware transitive invalidation (Learning Flow 2.0 §P1):
     * re-submitting an upstream activity voids outputs + completion marks of
     * every activity that can consume the revised output — directly or
     * through a downstream chain — so a revised evidence selection forces
     * re-verification of dependent Reasoning/Hypothesis/Verification/
     * Conclusion work instead of leaving stale credit behind.
     *
     * Dependency edges (target depends on source):
     *  - explicit source refs: config.priorEvidenceSource / evidenceSource
     *    name the exact activity whose output is consumed;
     *  - ordered propagation: the first activity of a stage depends on the
     *    previous stage boundary, and each later activity depends on its
     *    predecessor — priorOutputs can carry any earlier output forward.
     *
     * REVISION hops (onPartial/onContradicted) are deliberately NOT edges:
     * they are navigation transitions, not data dependencies — treating
     * "learner may go back and redo stage X" as "X consumes my output"
     * creates a cycle (hc → do → vf1 → hc) where resubmitting downstream
     * work voids the earlier answers that work depends on.
     *
     * Traversal is BFS over those edges — transitive, visited-guarded
     * (cycle-safe even on hand-edited snapshots), and never touches the
     * revised activity itself. Activity-attempt history rows are immutable
     * by design and stay untouched.
     */
    private void invalidateDependents(SnapshotModel model, AttemptState state,
                                      String activityId) {
        String stageId = model.stageIdOf(activityId);
        if (stageId == null) return;

        java.util.Map<String, java.util.Set<String>> deps = dependencyEdges(model);
        java.util.Set<String> tainted = new java.util.LinkedHashSet<>();
        java.util.Deque<String> queue = new java.util.ArrayDeque<>();
        queue.add(activityId);
        while (!queue.isEmpty()) {
            String src = queue.poll();
            for (String dep : deps.getOrDefault(src, java.util.Set.of())) {
                if (dep.equals(activityId) || !tainted.add(dep)) continue;
                queue.add(dep);
            }
        }
        for (String id : tainted) {
            if (state.isCompleted(id) || state.outputs().containsKey(id)) {
                log.info("invalidating dependent output activity={} after re-submit of {}",
                        id, activityId);
                state.removeCompleted(id);
                state.removeOutput(id);
            }
        }
    }

    /**
     * Build the activity-level dependency edges for a snapshot —
     * source -> {consumers}:
     *  (a) explicit refs: config.priorEvidenceSource / config.evidenceSource;
     *  (b) order propagation: stage prev-boundary -> first activity, and
     *      each activity -> its next sibling.
     * onPartial/onContradicted are navigation-only and never become edges
     * (see invalidateDependents javadoc — they must not form cycles).
     */
    private java.util.Map<String, java.util.Set<String>> dependencyEdges(SnapshotModel model) {
        java.util.Map<String, java.util.Set<String>> edges = new java.util.LinkedHashMap<>();
        java.util.Map<String, String> lastActByStage = new java.util.HashMap<>();
        for (JsonNode stage : model.stages()) {
            String sid = stage.path("id").asText(null);
            if (sid == null) continue;
            String prevId = null;
            for (JsonNode act : model.activitiesOf(sid)) {
                String id = act.path("id").asText(null);
                if (id == null) continue;
                if (prevId != null) addEdge(edges, prevId, id);
                else {
                    // first declared activity consumes the stage boundary
                    addEdge(edges, "stage:" + sid, id);
                }
                prevId = id;
            }
            if (prevId != null) lastActByStage.put(sid, prevId);
        }
        // stage boundary pseudo-node: last activity of each predecessor
        // stage feeds this stage's first activity.
        for (JsonNode stage : model.stages()) {
            String sid = stage.path("id").asText(null);
            if (sid == null) continue;
            for (JsonNode up : model.stages()) {
                String upId = up.path("id").asText(null);
                if (upId == null) continue;
                if (!model.nextStageIds(upId).contains(sid)) continue;
                String last = lastActByStage.get(upId);
                if (last != null) addEdge(edges, last, "stage:" + sid);
            }
        }
        // (a) explicit source refs only — revision hops (onPartial/
        // onContradicted) are navigation, NOT data dependencies; adding them
        // would turn hc → do → vf1 → hp hop into a dependency cycle that
        // voids the hypothesis whenever downstream work is resubmitted.
        for (JsonNode stage : model.stages()) {
            for (JsonNode act : model.activitiesOf(stage.path("id").asText())) {
                String id = act.path("id").asText(null);
                if (id == null) continue;
                JsonNode config = act.get("config");
                if (config != null && config.isObject()) {
                    for (String field : java.util.List.of("priorEvidenceSource", "evidenceSource")) {
                        JsonNode src = config.get(field);
                        if (src != null && src.isTextual()
                                && model.activityById(src.asText()) != null) {
                            addEdge(edges, src.asText(), id);
                        }
                    }
                }
            }
        }
        return edges;
    }

    private void addEdge(java.util.Map<String, java.util.Set<String>> edges,
                         String from, String to) {
        edges.computeIfAbsent(from, k -> new java.util.LinkedHashSet<>()).add(to);
    }

    private AttemptProgressResponse.Progress progressOf(SnapshotModel model, AttemptState state) {
        int total = 0;
        int done = 0;
        for (JsonNode stage : model.stages()) {
            for (JsonNode act : model.requiredActivities(stage.path("id").asText())) {
                total++;
                if (state.isCompleted(act.path("id").asText())) done++;
            }
        }
        return new AttemptProgressResponse.Progress(done, total);
    }

    private JsonNode parse(String json) {
        try {
            return mapper.readTree(json == null ? "{}" : json);
        } catch (Exception e) {
            throw new SnapshotCorruptException("unparseable json payload: " + e.getMessage());
        }
    }

    private String resultJson(ActivityResult result) {
        ObjectNode node = mapper.createObjectNode();
        node.put("outcome", result.outcome());
        node.put("completed", result.completed());
        if (result.output() != null) node.set("output", result.output());
        if (result.feedbackCode() != null) node.put("feedbackCode", result.feedbackCode());
        return node.toString();
    }
}
