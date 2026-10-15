package com.dauviet.lesson.application;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.lesson.api.dto.PublishResponse;
import com.dauviet.lesson.api.dto.PublishReadinessResponse;
import com.dauviet.lesson.domain.InvalidStatusTransitionException;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonNotFoundException;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonTemplate;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.domain.TemplateNotFoundException;
import com.dauviet.lesson.draft.DraftValidationException;
import com.dauviet.lesson.draft.FieldError;
import com.dauviet.lesson.draft.SnapshotBuilder;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonTemplateRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Transactional publish: PUBLISH-validate the draft, insert an immutable
 * lesson_versions snapshot, and rotate lessons.current_version_id in one
 * transaction. A pessimistic lock on the lesson row serializes concurrent
 * publishes so version_no allocation cannot race; the unique
 * (lesson_id, version_no) constraint remains the backstop.
 */
@Service
public class LessonPublishService {

    private final LessonRepository lessons;
    private final LessonTemplateRepository templates;
    private final LessonVersionRepository versions;
    private final PublishReadinessEvaluator readiness;
    private final SnapshotBuilder snapshots;
    private final ObjectMapper objectMapper;

    public LessonPublishService(LessonRepository lessons,
                                LessonTemplateRepository templates,
                                LessonVersionRepository versions,
                                PublishReadinessEvaluator readiness,
                                SnapshotBuilder snapshots,
                                ObjectMapper objectMapper) {
        this.lessons = lessons;
        this.templates = templates;
        this.versions = versions;
        this.readiness = readiness;
        this.snapshots = snapshots;
        this.objectMapper = objectMapper;
    }

    /**
     * Publish the current draft as a new immutable version.
     * DRAFT and PUBLISHED lessons may (re)publish; ARCHIVED may not.
     */
    @Transactional
    public PublishResponse publish(UUID lessonId, Long expectedRowVersion, UUID adminId) {
        Lesson lesson = lessons.findForUpdate(lessonId)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + lessonId));
        if (lesson.getStatus() == LessonStatus.ARCHIVED) {
            throw new InvalidStatusTransitionException("archived lesson cannot be published");
        }
        checkVersion(lesson, expectedRowVersion);

        PublishReadinessResponse check = readiness.evaluate(lesson);
        if (!check.errors().isEmpty()) {
            throw new DraftValidationException(check.errors().stream()
                    .map(e -> new FieldError(e.get("path"), e.get("code"), e.get("message")))
                    .toList());
        }

        LessonTemplate template = templates.findById(lesson.getTemplateId())
                .orElseThrow(() -> new TemplateNotFoundException(
                        "Template not found: " + lesson.getTemplateId()));
        JsonNode draft = parse(lesson.getDraftJson());

        int versionNo = versions.findTopByLessonIdOrderByVersionNoDesc(lessonId)
                .map(v -> v.getVersionNo() + 1).orElse(1);
        LessonVersion version = new LessonVersion();
        version.setId(UUID.randomUUID());
        version.setLessonId(lessonId);
        version.setVersionNo(versionNo);
        version.setSchemaVersion(com.dauviet.lesson.draft.DraftSchema.CURRENT_VERSION);
        version.setSnapshotJson(write(snapshots.build(lesson, draft, template)));
        version.setPublishedAt(java.time.Instant.now());
        version.setPublishedBy(adminId);
        LessonVersion saved = versions.saveAndFlush(version);

        lesson.setStatus(LessonStatus.PUBLISHED);
        lesson.setCurrentVersionId(saved.getId());
        lesson.setUpdatedBy(adminId);
        lessons.saveAndFlush(lesson);

        return new PublishResponse(lessonId, saved.getId(), versionNo,
                lesson.getStatus().name(), saved.getPublishedAt());
    }

    private void checkVersion(Lesson l, Long expected) {
        if (expected != null && !expected.equals(l.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    Lesson.class, l.getId());
        }
    }

    private JsonNode parse(String json) {
        try {
            return objectMapper.readTree(json == null ? "{}" : json);
        } catch (Exception e) {
            // Unreachable: readiness already parsed the same draft.
            throw new DraftValidationException(java.util.List.of(
                    new FieldError("draftJson", "INVALID_DRAFT", "draft_json is not parseable")));
        }
    }

    private String write(JsonNode node) {
        try {
            return objectMapper.writeValueAsString(node);
        } catch (Exception e) {
            throw new IllegalStateException("snapshot serialization failed", e);
        }
    }
}
