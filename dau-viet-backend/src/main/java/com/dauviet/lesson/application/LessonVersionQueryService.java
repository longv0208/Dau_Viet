package com.dauviet.lesson.application;

import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.api.PageResponse;
import com.dauviet.lesson.api.dto.LessonVersionDetail;
import com.dauviet.lesson.api.dto.LessonVersionSummary;
import com.dauviet.lesson.domain.LessonNotFoundException;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.domain.VersionNotFoundException;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Read-side queries over the immutable lesson_versions table. Admin-facing:
 * returns full snapshots (server-only keys included). Learner reads go
 * through LearnerLessonService which applies the projection.
 */
@Service
public class LessonVersionQueryService {

    private final LessonRepository lessons;
    private final LessonVersionRepository versions;
    private final ObjectMapper objectMapper;

    public LessonVersionQueryService(LessonRepository lessons,
                                     LessonVersionRepository versions,
                                     ObjectMapper objectMapper) {
        this.lessons = lessons;
        this.versions = versions;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public PageResponse<LessonVersionSummary> list(UUID lessonId, Pageable pageable) {
        requireLesson(lessonId);
        List<LessonVersionSummary> items =
                versions.findByLessonIdOrderByVersionNoDesc(lessonId, pageable)
                        .stream().map(this::toSummary).toList();
        long total = versions.countByLessonId(lessonId);
        int totalPages = pageable.getPageSize() == 0 ? 0
                : (int) Math.ceil((double) total / pageable.getPageSize());
        return new PageResponse<>(items, pageable.getPageNumber(),
                pageable.getPageSize(), total, totalPages);
    }

    @Transactional(readOnly = true)
    public LessonVersionDetail get(UUID lessonId, UUID versionId) {
        LessonVersion v = versions.findByLessonIdAndId(lessonId, versionId)
                .orElseThrow(() -> new VersionNotFoundException(
                        "version " + versionId + " not found for lesson " + lessonId));
        return toDetail(v);
    }

    @Transactional(readOnly = true)
    public LessonVersionDetail getCurrent(UUID lessonId) {
        var lesson = lessons.findById(lessonId)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + lessonId));
        if (lesson.getCurrentVersionId() == null) {
            throw new VersionNotFoundException("lesson has no published version: " + lessonId);
        }
        return get(lessonId, lesson.getCurrentVersionId());
    }

    private void requireLesson(UUID lessonId) {
        if (!lessons.existsById(lessonId)) {
            throw new LessonNotFoundException("Lesson not found: " + lessonId);
        }
    }

    private LessonVersionSummary toSummary(LessonVersion v) {
        return new LessonVersionSummary(v.getId(), v.getVersionNo(),
                v.getSchemaVersion(), v.getPublishedAt(), v.getPublishedBy());
    }

    private LessonVersionDetail toDetail(LessonVersion v) {
        return new LessonVersionDetail(v.getId(), v.getLessonId(), v.getVersionNo(),
                v.getSchemaVersion(), v.getPublishedAt(), v.getPublishedBy(),
                parse(v.getSnapshotJson()));
    }

    private JsonNode parse(String json) {
        try {
            return objectMapper.readTree(json);
        } catch (Exception e) {
            return objectMapper.createObjectNode();
        }
    }
}
