package com.dauviet.learning.application;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.learning.api.dto.AttemptProgressResponse;
import com.dauviet.learning.api.dto.AttemptStartResponse;
import com.dauviet.learning.api.dto.CurrentActivityResponse;
import com.dauviet.learning.api.dto.SubmitActivityResponse;
import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.ActivitySubmission;
import com.dauviet.learning.contract.AttemptContext;
import com.dauviet.learning.contract.LessonCompletion;
import com.dauviet.learning.domain.ActivityAttempt;
import com.dauviet.learning.domain.ActivityNotAvailableException;
import com.dauviet.learning.domain.AttemptNotFoundException;
import com.dauviet.learning.domain.AttemptNotInProgressException;
import com.dauviet.learning.domain.AttemptNotOwnedException;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.domain.LearnerAttempt;
import com.dauviet.learning.domain.LearnerAttemptStatus;
import com.dauviet.learning.handler.ActivityHandler;
import com.dauviet.learning.handler.ActivityHandlerRegistry;
import com.dauviet.learning.infrastructure.persistence.ActivityAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.resolver.LessonCompletionEvaluator;
import com.dauviet.learning.resolver.StageTransitionResolver;
import com.dauviet.learning.snapshot.SnapshotModel;
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
    private final LessonRepository lessons;
    private final LessonVersionRepository versions;
    private final ActivityHandlerRegistry handlers;
    private final StageTransitionResolver transitionResolver;
    private final LessonCompletionEvaluator completionEvaluator;
    private final LearnerProjectionService projection;
    private final ObjectMapper mapper;

    public LearnerAttemptService(LearnerAttemptRepository attempts,
                                 ActivityAttemptRepository activityAttempts,
                                 LessonRepository lessons,
                                 LessonVersionRepository versions,
                                 ActivityHandlerRegistry handlers,
                                 StageTransitionResolver transitionResolver,
                                 LessonCompletionEvaluator completionEvaluator,
                                 LearnerProjectionService projection,
                                 ObjectMapper mapper) {
        this.attempts = attempts;
        this.activityAttempts = activityAttempts;
        this.lessons = lessons;
        this.versions = versions;
        this.handlers = handlers;
        this.transitionResolver = transitionResolver;
        this.completionEvaluator = completionEvaluator;
        this.projection = projection;
        this.mapper = mapper;
    }

    /** Start a new attempt or resume the existing IN_PROGRESS one. */
    @Transactional
    public AttemptStartResponse startOrResume(UUID userId, UUID lessonId) {
        Lesson lesson = lessons.findById(lessonId)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + lessonId));
        if (lesson.getStatus() != LessonStatus.PUBLISHED || lesson.getCurrentVersionId() == null) {
            throw new LessonNotPublishedException("lesson is not published: " + lessonId);
        }
        UUID versionId = lesson.getCurrentVersionId();

        var existing = attempts.findByUserIdAndLessonVersionIdAndStatus(
                userId, versionId, LearnerAttemptStatus.IN_PROGRESS);
        if (existing.isPresent()) {
            LearnerAttempt a = existing.get();
            return new AttemptStartResponse(a.getId(), a.getLessonVersionId(),
                    a.getStatus().name(), true,
                    a.getCurrentStageId(), a.getCurrentActivityId());
        }

        SnapshotModel model = snapshotOf(versionId);
        AttemptState state = new AttemptState();
        state.setCurrentStageId(model.entryStageId());
        state.setCurrentActivityId(model.firstRequiredActivityId(model.entryStageId()));
        LearnerAttempt attempt = LearnerAttempt.start(userId, versionId);
        attempt.recordProgress(state);
        attempts.save(attempt);
        return new AttemptStartResponse(attempt.getId(), versionId,
                attempt.getStatus().name(), false,
                state.currentStageId(), state.currentActivityId());
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
            ObjectNode projected = projection.projectActivity(activity);
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
     * The cursor check (activityId == state.currentActivityId) prevents
     * skipping; a retried submit after advancement reads as
     * ACTIVITY_NOT_AVAILABLE rather than double-applying.
     */
    @Transactional
    public SubmitActivityResponse submit(UUID userId, UUID attemptId,
                                         String activityId, JsonNode answer,
                                         String idempotencyKey) {
        if (idempotencyKey != null && log.isDebugEnabled()) {
            log.debug("submit idempotency-key={} attempt={}", idempotencyKey, attemptId);
        }
        LearnerAttempt a = attempts.findForUpdate(attemptId)
                .orElseThrow(() -> new AttemptNotFoundException("attempt not found: " + attemptId));
        if (!a.getUserId().equals(userId)) {
            throw new AttemptNotOwnedException("attempt not owned by user: " + attemptId);
        }
        if (a.getStatus() != LearnerAttemptStatus.IN_PROGRESS) {
            throw new AttemptNotInProgressException(
                    "attempt " + attemptId + " is " + a.getStatus());
        }
        SnapshotModel model = snapshotOf(a.getLessonVersionId());
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
        if (activityId == null || !activityId.equals(state.currentActivityId())) {
            throw new ActivityNotAvailableException(
                    "activity " + activityId + " is not the current activity");
        }
        JsonNode activity = model.activityById(activityId);
        if (activity == null) {
            throw new SnapshotCorruptException(
                    "current activity missing from pinned snapshot: " + activityId);
        }

        ActivityType type = ActivityType.valueOf(activity.path("type").asText());
        ActivityHandler handler = handlers.handlerFor(type);
        AttemptContext ctx = new AttemptContext(a.getId(), userId,
                a.getLessonVersionId(), state.currentStageId(), activityId,
                activity, model.root(), state.outputs());
        ActivityResult result = handler.evaluate(ctx,
                new ActivitySubmission(attemptId, activityId, answer, idempotencyKey));

        state.recordOutput(activityId, result.output());
        if (result.completed()) {
            state.markCompleted(activityId);
        }
        int attemptNo = activityAttempts
                .countByLearnerAttemptIdAndActivityId(a.getId(), activityId) + 1;
        activityAttempts.save(ActivityAttempt.of(a.getId(), activityId, attemptNo,
                answer == null ? "{}" : answer.toString(), resultJson(result)));

        var transition = transitionResolver.resolve(model, state, activityId, result.outcome());
        if (transition != null && transition.nextStage() != null) {
            state.setCurrentStageId(transition.nextStage().stageId());
            state.setCurrentActivityId(
                    model.firstRequiredActivityId(transition.nextStage().stageId()));
        } else if (transition != null && transition.nextActivity() != null) {
            state.setCurrentActivityId(transition.nextActivity().activityId());
        }
        // transition == null: keep cursor — lesson is finished by progression.
        a.recordProgress(state);
        attempts.save(a);

        LessonCompletion completion = completionEvaluator.evaluate(model, state);
        SubmitActivityResponse.Next next = transition == null ? null
                : transition.nextActivity() != null
                ? new SubmitActivityResponse.Next(
                        transition.nextActivity().stageId(),
                        transition.nextActivity().activityId(),
                        transition.nextActivity().activityType(),
                        transition.nextActivity().learnerConfig() == null ? null
                                : projection.projectActivity(
                                        model.activityById(transition.nextActivity().activityId()))
                                        .get("config"))
                : new SubmitActivityResponse.Next(
                        transition.nextStage().stageId(),
                        model.firstRequiredActivityId(transition.nextStage().stageId()),
                        null, null);
        return new SubmitActivityResponse("ACCEPTED", result, result.completed(),
                progressOf(model, state), next, completion);
    }

    /** Completion verdict only — does not flip status (TASK-0012). */
    @Transactional(readOnly = true)
    public LessonCompletion complete(UUID userId, UUID attemptId) {
        LearnerAttempt a = loadOwned(userId, attemptId);
        SnapshotModel model = snapshotOf(a.getLessonVersionId());
        AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
        return completionEvaluator.evaluate(model, state);
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
