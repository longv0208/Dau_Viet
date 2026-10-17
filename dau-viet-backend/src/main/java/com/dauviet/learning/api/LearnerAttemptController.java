package com.dauviet.learning.api;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.api.PageResponse;
import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.learning.api.dto.AttemptProgressResponse;
import com.dauviet.learning.api.dto.AttemptStartResponse;
import com.dauviet.learning.api.dto.AttemptSummaryResponse;
import com.dauviet.learning.api.dto.CompleteAttemptResponse;
import com.dauviet.learning.api.dto.CurrentActivityResponse;
import com.dauviet.learning.api.dto.LessonResultResponse;
import com.dauviet.learning.api.dto.MyProgressResponse;
import com.dauviet.learning.api.dto.SubmitActivityRequest;
import com.dauviet.learning.api.dto.SubmitActivityResponse;
import com.dauviet.learning.application.LearnerAttemptService;
import com.dauviet.lesson.api.dto.LearnerLessonContent;
import com.dauviet.learning.domain.LearnerAttemptStatus;

import jakarta.validation.Valid;

/**
 * Learner attempt runtime surface. All endpoints are authenticated
 * (anyRequest().authenticated() in SecurityConfig); ownership is enforced
 * server-side in the service. Submit and complete honour a persistent
 * Idempotency-Key (TASK-0012): same key + same payload replays the stored
 * response; same key + different payload -> 409 IDEMPOTENCY_CONFLICT.
 */
@RestController
@RequestMapping("/api/v1")
public class LearnerAttemptController {

    private static final int MAX_PAGE_SIZE = 50;

    private final LearnerAttemptService service;
    private final JwtSubjectExtractor subjects;

    public LearnerAttemptController(LearnerAttemptService service,
                                    JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Start a new attempt or resume the IN_PROGRESS one for this lesson. */
    @PostMapping("/lessons/{lessonId}/attempts")
    public AttemptStartResponse start(@PathVariable UUID lessonId,
                                      @AuthenticationPrincipal Jwt jwt) {
        return service.startOrResume(subjects.userId(jwt), lessonId);
    }

    /** Attempt cursor + progress + completion verdict. */
    @GetMapping("/attempts/{attemptId}")
    public AttemptProgressResponse get(@PathVariable UUID attemptId,
                                       @AuthenticationPrincipal Jwt jwt) {
        return service.getAttempt(subjects.userId(jwt), attemptId);
    }

    /** Learner-safe view of the activity the cursor points at. */
    @GetMapping("/attempts/{attemptId}/current")
    public CurrentActivityResponse current(@PathVariable UUID attemptId,
                                           @AuthenticationPrincipal Jwt jwt) {
        return service.getCurrent(subjects.userId(jwt), attemptId);
    }

    /**
     * Learner-safe content of the attempt's PINNED version (TASK-0018):
     * resume-after-republish keeps evidence[]/assets[]/stage config of the
     * version submissions are graded against; owner only.
     */
    @GetMapping("/attempts/{attemptId}/content")
    public LearnerLessonContent content(@PathVariable UUID attemptId,
                                        @AuthenticationPrincipal Jwt jwt) {
        return service.getContent(subjects.userId(jwt), attemptId);
    }

    /** Evaluate one submission against the pinned snapshot. */
    @PostMapping("/attempts/{attemptId}/activities/{activityId}/submissions")
    public SubmitActivityResponse submit(@PathVariable UUID attemptId,
                                         @PathVariable String activityId,
                                         @Valid @RequestBody SubmitActivityRequest body,
                                         @RequestHeader(name = "Idempotency-Key", required = false)
                                         String idempotencyKey,
                                         @AuthenticationPrincipal Jwt jwt) {
        return service.submit(subjects.userId(jwt), attemptId, activityId,
                body.answer(), idempotencyKey);
    }

    /**
     * Server-authoritative completion: re-evaluates, flips status and writes
     * lesson_results atomically; 409 ATTEMPT_NOT_COMPLETE when requirements
     * are unmet; repeated calls replay the stored result.
     */
    @PostMapping("/attempts/{attemptId}/complete")
    public CompleteAttemptResponse complete(@PathVariable UUID attemptId,
                                            @RequestHeader(name = "Idempotency-Key", required = false)
                                            String idempotencyKey,
                                            @AuthenticationPrincipal Jwt jwt) {
        return service.complete(subjects.userId(jwt), attemptId, idempotencyKey);
    }

    /** Persisted result of a completed attempt (owner only). */
    @GetMapping("/attempts/{attemptId}/result")
    public LessonResultResponse result(@PathVariable UUID attemptId,
                                       @AuthenticationPrincipal Jwt jwt) {
        return service.getResult(subjects.userId(jwt), attemptId);
    }

    /** Learner's own attempt list — resume info + history, newest first. */
    @GetMapping("/me/attempts")
    public PageResponse<AttemptSummaryResponse> myAttempts(
            @RequestParam(required = false) LearnerAttemptStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal Jwt jwt) {
        Pageable pageable = PageRequest.of(Math.max(0, page),
                Math.min(Math.max(1, size), MAX_PAGE_SIZE));
        return service.listMyAttempts(subjects.userId(jwt), status, pageable);
    }

    /** Mobile resume surface: IN_PROGRESS attempts + completed count. */
    @GetMapping("/me/progress")
    public MyProgressResponse myProgress(@AuthenticationPrincipal Jwt jwt) {
        return service.myProgress(subjects.userId(jwt));
    }
}
