package com.dauviet.learning.api;

import java.util.UUID;

import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.learning.api.dto.AttemptProgressResponse;
import com.dauviet.learning.api.dto.AttemptStartResponse;
import com.dauviet.learning.api.dto.CurrentActivityResponse;
import com.dauviet.learning.api.dto.SubmitActivityRequest;
import com.dauviet.learning.api.dto.SubmitActivityResponse;
import com.dauviet.learning.application.LearnerAttemptService;
import com.dauviet.learning.contract.LessonCompletion;

import jakarta.validation.Valid;

/**
 * Learner attempt runtime surface. All endpoints are authenticated
 * (anyRequest().authenticated() in SecurityConfig); ownership is enforced
 * server-side in the service. The submit endpoint accepts an optional
 * Idempotency-Key header — logged, not yet persisted (TASK-0012).
 */
@RestController
@RequestMapping("/api/v1")
public class LearnerAttemptController {

    private final LearnerAttemptService service;

    public LearnerAttemptController(LearnerAttemptService service) {
        this.service = service;
    }

    /** Start a new attempt or resume the IN_PROGRESS one for this user. */
    @PostMapping("/lessons/{lessonId}/attempts")
    public AttemptStartResponse start(@PathVariable UUID lessonId,
                                      @AuthenticationPrincipal Jwt jwt) {
        return service.startOrResume(userId(jwt), lessonId);
    }

    /** Attempt cursor + progress + completion verdict. */
    @GetMapping("/attempts/{attemptId}")
    public AttemptProgressResponse get(@PathVariable UUID attemptId,
                                       @AuthenticationPrincipal Jwt jwt) {
        return service.getAttempt(userId(jwt), attemptId);
    }

    /** Learner-safe view of the current activity. */
    @GetMapping("/attempts/{attemptId}/current")
    public CurrentActivityResponse current(@PathVariable UUID attemptId,
                                           @AuthenticationPrincipal Jwt jwt) {
        return service.getCurrent(userId(jwt), attemptId);
    }

    /** Evaluate one submission against the pinned snapshot. */
    @PostMapping("/attempts/{attemptId}/activities/{activityId}/submissions")
    public SubmitActivityResponse submit(@PathVariable UUID attemptId,
                                         @PathVariable String activityId,
                                         @Valid @RequestBody SubmitActivityRequest body,
                                         @RequestHeader(name = "Idempotency-Key", required = false)
                                         String idempotencyKey,
                                         @AuthenticationPrincipal Jwt jwt) {
        return service.submit(userId(jwt), attemptId, activityId,
                body.answer(), idempotencyKey);
    }

    /** Completion verdict only; does not flip status (TASK-0012). */
    @PostMapping("/attempts/{attemptId}/complete")
    public LessonCompletion complete(@PathVariable UUID attemptId,
                                     @AuthenticationPrincipal Jwt jwt) {
        return service.complete(userId(jwt), attemptId);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
