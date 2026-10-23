package com.dauviet.animation.api;

import java.util.List;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.animation.api.dto.AnimationDtos.PublishRequest;
import com.dauviet.animation.api.dto.AnimationDtos.PublishResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneCreateRequest;
import com.dauviet.animation.api.dto.AnimationDtos.SceneResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneSummaryResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneUpdateRequest;
import com.dauviet.animation.api.dto.AnimationDtos.SceneValidationResponse;
import com.dauviet.animation.api.dto.AnimationDtos.SceneVersionDetail;
import com.dauviet.animation.api.dto.AnimationDtos.SceneVersionSummary;
import com.dauviet.animation.application.AnimationScenePublishService;
import com.dauviet.animation.application.AnimationSceneService;
import com.dauviet.animation.domain.AnimationSceneStatus;
import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.common.api.PageResponse;

/**
 * Admin animation scene CRUD + draft + validate/publish/archive + versions.
 * Requires ROLE_CONTENT_ADMIN. Manifests never leave this surface as draft —
 * learners only see published snapshots embedded in lesson_versions.
 */
@RestController
@RequestMapping("/api/v1/admin/animation-scenes")
@Validated
public class AdminAnimationSceneController {

    private static final Set<String> ALLOWED_SORT_FIELDS =
            Set.of("title", "createdAt", "updatedAt", "status");
    private static final Sort DEFAULT_SORT = Sort.by(Sort.Direction.DESC, "updatedAt");

    private final AnimationSceneService service;
    private final AnimationScenePublishService publishService;

    public AdminAnimationSceneController(AnimationSceneService service,
                                         AnimationScenePublishService publishService) {
        this.service = service;
        this.publishService = publishService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SceneResponse create(@Valid @RequestBody SceneCreateRequest req,
                                @AuthenticationPrincipal Jwt jwt) {
        return service.create(req, adminId(jwt));
    }

    @GetMapping
    public PageResponse<SceneSummaryResponse> list(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "updatedAt,desc") String sort,
            @RequestParam(required = false) UUID templateId,
            @RequestParam(required = false) UUID eventId,
            @RequestParam(required = false) AnimationSceneStatus status,
            @RequestParam(required = false) String q) {
        Pageable pageable = PageRequest.of(page, size, parseSort(sort));
        return PageResponse.from(service.list(templateId, eventId, status, q, pageable));
    }

    @GetMapping("/{id}")
    public SceneResponse get(@PathVariable UUID id) {
        return service.get(id);
    }

    @PatchMapping("/{id}")
    public SceneResponse update(@PathVariable UUID id,
                                @Valid @RequestBody SceneUpdateRequest req,
                                @AuthenticationPrincipal Jwt jwt) {
        return service.update(id, req, adminId(jwt));
    }

    @PostMapping("/{id}/duplicate")
    @ResponseStatus(HttpStatus.CREATED)
    public SceneResponse duplicate(@PathVariable UUID id,
                                   @AuthenticationPrincipal Jwt jwt) {
        return service.duplicate(id, adminId(jwt));
    }

    @PostMapping("/{id}/archive")
    public SceneResponse archive(@PathVariable UUID id,
                                 @AuthenticationPrincipal Jwt jwt) {
        return service.archive(id, adminId(jwt));
    }

    /** Read-only manifest validation probe — always 200 with structured errors. */
    @PostMapping("/{id}/validate")
    public SceneValidationResponse validate(@PathVariable UUID id) {
        return service.validate(id);
    }

    /** Transactional publish: validate → immutable version → rotate pointer. */
    @PostMapping("/{id}/publish")
    public PublishResponse publish(@PathVariable UUID id,
                                   @RequestBody(required = false) PublishRequest req,
                                   @AuthenticationPrincipal Jwt jwt) {
        Long expected = req == null ? null : req.expectedRowVersion();
        return publishService.publish(id, expected, adminId(jwt));
    }

    @GetMapping("/{id}/versions")
    public List<SceneVersionSummary> versions(@PathVariable UUID id) {
        return service.listVersions(id);
    }

    @GetMapping("/{id}/versions/{versionId}")
    public SceneVersionDetail version(@PathVariable UUID id,
                                      @PathVariable UUID versionId) {
        return service.getVersion(id, versionId);
    }

    private UUID adminId(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
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
