package com.dauviet.lesson.api;

import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.lesson.api.dto.ActivityDto;
import com.dauviet.lesson.api.dto.ActivityPatchRequest;
import com.dauviet.lesson.api.dto.ActivityUpsertRequest;
import com.dauviet.lesson.api.dto.DraftActivitiesResponse;
import com.dauviet.lesson.api.dto.DraftStagesResponse;
import com.dauviet.lesson.api.dto.OrderRequest;
import com.dauviet.lesson.api.dto.StageDto;
import com.dauviet.lesson.api.dto.StagePatchRequest;
import com.dauviet.lesson.api.dto.StageUpsertRequest;
import com.dauviet.lesson.application.LessonDraftService;

/**
 * Admin sub-resource API for the structured draft_json document.
 * All mutations are SAVE-level validated before persist; ordering is
 * array-position based via PUT .../order with the full orderedIds list.
 */
@RestController
@RequestMapping("/api/v1/admin/lessons/{lessonId}/draft")
public class AdminLessonDraftController {

    private final LessonDraftService service;

    public AdminLessonDraftController(LessonDraftService service) {
        this.service = service;
    }

    /* -------- stages -------- */

    @GetMapping("/stages")
    public DraftStagesResponse listStages(@PathVariable UUID lessonId) {
        return service.listStages(lessonId);
    }

    @GetMapping("/stages/{stageId}")
    public StageDto getStage(@PathVariable UUID lessonId,
                             @PathVariable String stageId) {
        return service.getStage(lessonId, stageId);
    }

    @PostMapping("/stages")
    @ResponseStatus(HttpStatus.CREATED)
    public StageDto addStage(@PathVariable UUID lessonId,
                             @Valid @RequestBody StageUpsertRequest req,
                             @AuthenticationPrincipal Jwt jwt) {
        return service.addStage(lessonId, req, adminId(jwt));
    }

    @PatchMapping("/stages/{stageId}")
    public StageDto updateStage(@PathVariable UUID lessonId,
                                @PathVariable String stageId,
                                @Valid @RequestBody StagePatchRequest req,
                                @AuthenticationPrincipal Jwt jwt) {
        return service.updateStage(lessonId, stageId, req, adminId(jwt));
    }

    @PutMapping("/stages/order")
    public DraftStagesResponse reorderStages(@PathVariable UUID lessonId,
                                             @Valid @RequestBody OrderRequest req,
                                             @AuthenticationPrincipal Jwt jwt) {
        return service.reorderStages(
                lessonId, req.orderedIds(), req.expectedRowVersion(), adminId(jwt));
    }

    @DeleteMapping("/stages/{stageId}")
    public DraftStagesResponse removeStage(@PathVariable UUID lessonId,
                                           @PathVariable String stageId,
                                           @RequestParam(required = false) Long expectedRowVersion,
                                           @AuthenticationPrincipal Jwt jwt) {
        return service.removeStage(lessonId, stageId, expectedRowVersion, adminId(jwt));
    }

    /* -------- activities -------- */

    @GetMapping("/stages/{stageId}/activities")
    public DraftActivitiesResponse listActivities(@PathVariable UUID lessonId,
                                                  @PathVariable String stageId) {
        return service.listActivities(lessonId, stageId);
    }

    @GetMapping("/stages/{stageId}/activities/{activityId}")
    public ActivityDto getActivity(@PathVariable UUID lessonId,
                                   @PathVariable String stageId,
                                   @PathVariable String activityId) {
        return service.getActivity(lessonId, stageId, activityId);
    }

    @PostMapping("/stages/{stageId}/activities")
    @ResponseStatus(HttpStatus.CREATED)
    public ActivityDto addActivity(@PathVariable UUID lessonId,
                                   @PathVariable String stageId,
                                   @Valid @RequestBody ActivityUpsertRequest req,
                                   @AuthenticationPrincipal Jwt jwt) {
        return service.addActivity(lessonId, stageId, req, adminId(jwt));
    }

    @PatchMapping("/stages/{stageId}/activities/{activityId}")
    public ActivityDto updateActivity(@PathVariable UUID lessonId,
                                      @PathVariable String stageId,
                                      @PathVariable String activityId,
                                      @Valid @RequestBody ActivityPatchRequest req,
                                      @AuthenticationPrincipal Jwt jwt) {
        return service.updateActivity(lessonId, stageId, activityId, req, adminId(jwt));
    }

    @PutMapping("/stages/{stageId}/activities/order")
    public DraftActivitiesResponse reorderActivities(@PathVariable UUID lessonId,
                                                     @PathVariable String stageId,
                                                     @Valid @RequestBody OrderRequest req,
                                                     @AuthenticationPrincipal Jwt jwt) {
        return service.reorderActivities(
                lessonId, stageId, req.orderedIds(), req.expectedRowVersion(), adminId(jwt));
    }

    @DeleteMapping("/stages/{stageId}/activities/{activityId}")
    public DraftActivitiesResponse removeActivity(@PathVariable UUID lessonId,
                                                  @PathVariable String stageId,
                                                  @PathVariable String activityId,
                                                  @RequestParam(required = false) Long expectedRowVersion,
                                                  @AuthenticationPrincipal Jwt jwt) {
        return service.removeActivity(
                lessonId, stageId, activityId, expectedRowVersion, adminId(jwt));
    }

    private UUID adminId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            throw new AuthenticationFailedException();
        }
    }
}
