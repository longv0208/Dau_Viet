package com.dauviet.lesson.api;

import java.util.UUID;

import org.springframework.data.domain.PageRequest;
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
@RequestMapping("/api/v1/admin/lessons/{lessonId}/versions")
public class AdminLessonVersionController {

    private final LessonVersionQueryService versions;

    public AdminLessonVersionController(LessonVersionQueryService versions) {
        this.versions = versions;
    }

    /** List versions newest-first. */
    @GetMapping
    public PageResponse<LessonVersionSummary> list(
            @PathVariable UUID lessonId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return versions.list(lessonId, PageRequest.of(page, size));
    }

    /** Full snapshot of one version (admin sees server-only keys). */
    @GetMapping("/{versionId}")
    public LessonVersionDetail get(@PathVariable UUID lessonId,
                                   @PathVariable UUID versionId) {
        return versions.get(lessonId, versionId);
    }

    /** The version lessons.current_version_id currently points at. */
    @GetMapping("/current")
    public LessonVersionDetail getCurrent(@PathVariable UUID lessonId) {
        return versions.getCurrent(lessonId);
    }
}
