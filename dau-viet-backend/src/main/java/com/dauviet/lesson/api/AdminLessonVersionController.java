package com.dauviet.lesson.api;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.api.PageResponse;
import com.dauviet.lesson.api.dto.LessonVersionDetail;
import com.dauviet.lesson.api.dto.LessonVersionSummary;
import com.dauviet.lesson.application.LessonVersionQueryService;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * Read-only admin access to the immutable lesson_versions history.
 * Published snapshots can never be edited — republish creates a new row.
 */
@RestController
@RequestMapping("/api/v1/admin")
@Validated
public class AdminLessonVersionController {

    private final LessonVersionQueryService versions;

    public AdminLessonVersionController(LessonVersionQueryService versions) {
        this.versions = versions;
    }

    /** Global paginated list of published lesson versions (with optional lessonId & search q). */
    @GetMapping("/lesson-versions")
    public PageResponse<LessonVersionSummary> listGlobal(
            @RequestParam(required = false) UUID lessonId,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return versions.listGlobal(lessonId, q, PageRequest.of(page, size));
    }

    /** List versions newest-first for a specific lesson. */
    @GetMapping("/lessons/{lessonId}/versions")
    public PageResponse<LessonVersionSummary> list(
            @PathVariable UUID lessonId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return versions.list(lessonId, PageRequest.of(page, size));
    }

    /** Full snapshot of one version (admin sees server-only keys). */
    @GetMapping("/lessons/{lessonId}/versions/{versionId}")
    public LessonVersionDetail get(@PathVariable UUID lessonId,
                                   @PathVariable UUID versionId) {
        return versions.get(lessonId, versionId);
    }

    /** The version lessons.current_version_id currently points at. */
    @GetMapping("/lessons/{lessonId}/versions/current")
    public LessonVersionDetail getCurrent(@PathVariable UUID lessonId) {
        return versions.getCurrent(lessonId);
    }
}
