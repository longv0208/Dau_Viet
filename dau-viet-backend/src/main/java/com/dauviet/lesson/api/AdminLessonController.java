package com.dauviet.lesson.api;

import java.util.Set;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
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
import com.dauviet.common.api.PageResponse;
import com.dauviet.lesson.api.dto.AdminLessonCreateRequest;
import com.dauviet.lesson.api.dto.AdminLessonDraftRequest;
import com.dauviet.lesson.api.dto.AdminLessonResponse;
import com.dauviet.lesson.api.dto.AdminLessonSummaryResponse;
import com.dauviet.lesson.api.dto.AdminLessonUpdateRequest;
import com.dauviet.lesson.api.dto.LearnerLessonContent;
import com.dauviet.lesson.api.dto.PublishReadinessResponse;
import com.dauviet.lesson.api.dto.PublishRequest;
import com.dauviet.lesson.api.dto.PublishResponse;
import com.dauviet.lesson.application.LessonPublishService;
import com.dauviet.lesson.application.LessonService;
import com.dauviet.lesson.domain.LessonStatus;

/**
 * Admin lesson CRUD + draft editing. Requires ROLE_CONTENT_ADMIN.
 * `PUT /{id}/draft` replaces the JSONB draft while preserving the published
 * snapshot in lesson_versions.
 */
@RestController
@RequestMapping("/api/v1/admin/lessons")
@Validated
public class AdminLessonController {

    private static final Set<String> ALLOWED_SORT_FIELDS =
            Set.of("title", "createdAt", "updatedAt", "status");
    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.DESC, "updatedAt");

    private final LessonService service;
    private final LessonPublishService publishService;

    public AdminLessonController(LessonService service,
                                 LessonPublishService publishService) {
        this.service = service;
        this.publishService = publishService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminLessonResponse create(@Valid @RequestBody AdminLessonCreateRequest req,
                                      @AuthenticationPrincipal Jwt jwt) {
        return service.create(req, adminId(jwt));
    }

    @GetMapping
    public PageResponse<AdminLessonSummaryResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "updatedAt,desc") String sort,
            @RequestParam(required = false) UUID eventId,
            @RequestParam(required = false) LessonStatus status,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        return PageResponse.from(service.list(eventId, status, q, pageable));
    }

    @GetMapping("/{id}")
    public AdminLessonResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PatchMapping("/{id}")
    public AdminLessonResponse update(@PathVariable UUID id,
                                      @Valid @RequestBody AdminLessonUpdateRequest req,
                                      @AuthenticationPrincipal Jwt jwt) {
        return service.update(id, req, adminId(jwt));
    }

    @PutMapping("/{id}/draft")
    public AdminLessonResponse updateDraft(@PathVariable UUID id,
                                           @Valid @RequestBody AdminLessonDraftRequest req,
                                           @AuthenticationPrincipal Jwt jwt) {
        return service.updateDraft(id, req, adminId(jwt));
    }

    @PostMapping("/{id}/archive")
    public AdminLessonResponse archive(@PathVariable UUID id,
                                       @AuthenticationPrincipal Jwt jwt) {
        return service.archive(id, adminId(jwt));
    }

    /**
     * PUBLISH-level readiness probe — read-only, always 200 with
     * {ready, errors, warnings, summary}. Does NOT create lesson_versions
     * (that is TASK-0010's publish flow).
     */
    @PostMapping("/{id}/validate")
    public PublishReadinessResponse validate(@PathVariable UUID id) {
        return service.checkPublishReadiness(id);
    }

    /**
     * Transactional publish: validates the draft at PUBLISH level, writes an
     * immutable lesson_versions snapshot, and rotates current_version_id.
     */
    @PostMapping("/{id}/publish")
    public PublishResponse publish(@PathVariable UUID id,
                                   @RequestBody(required = false) PublishRequest req,
                                   @AuthenticationPrincipal Jwt jwt) {
        Long expected = req == null ? null : req.expectedRowVersion();
        return publishService.publish(id, expected, adminId(jwt));
    }

    /**
     * Learner-safe projection of the current draft — what a learner would see
     * if it were published now. Read-only; never writes lesson_versions.
     */
    @PostMapping("/{id}/preview")
    public LearnerLessonContent preview(@PathVariable UUID id) {
        return service.preview(id);
    }

    private UUID adminId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            // Malformed subject on a signed token is an authentication failure,
            // consistent with UserController.subjectToUuid.
            throw new AuthenticationFailedException();
        }
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) return DEFAULT_SORT;
        String[] parts = sort.split(",");
        if (parts.length > 2) {
            throw new IllegalArgumentException("Malformed sort parameter: " + sort);
        }
        String field = parts[0].trim();
        if (!ALLOWED_SORT_FIELDS.contains(field)) {
            throw new IllegalArgumentException("Unsupported sort field: " + field);
        }
        if (parts.length == 1) return Sort.by(Sort.Direction.ASC, field);
        String dir = parts[1].trim().toLowerCase();
        if (!dir.equals("asc") && !dir.equals("desc")) {
            throw new IllegalArgumentException("Unsupported sort direction: " + parts[1].trim());
        }
        return Sort.by(Sort.Direction.fromString(dir), field);
    }
}
