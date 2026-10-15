package com.dauviet.lesson.application;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.lesson.api.dto.LearnerLessonContent;
import com.dauviet.lesson.api.dto.LearnerLessonListItem;
import com.dauviet.lesson.api.dto.LearnerLessonMetadata;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonNotFoundException;
import com.dauviet.lesson.domain.LessonNotPublishedException;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.domain.VersionNotFoundException;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Public learner read surface: published lessons of a published event,
 * lesson metadata, and the learner-safe projection of the current
 * published version. Never exposes draft or server-only data.
 */
@Service
public class LearnerLessonService {

    private final LessonRepository lessons;
    private final LessonVersionRepository versions;
    private final HistoricalEventRepository events;
    private final LearnerProjectionService projection;
    private final ObjectMapper objectMapper;

    public LearnerLessonService(LessonRepository lessons,
                                LessonVersionRepository versions,
                                HistoricalEventRepository events,
                                LearnerProjectionService projection,
                                ObjectMapper objectMapper) {
        this.lessons = lessons;
        this.versions = versions;
        this.events = events;
        this.projection = projection;
        this.objectMapper = objectMapper;
    }

    /** Published lessons of a PUBLISHED event; 404 otherwise. */
    @Transactional(readOnly = true)
    public List<LearnerLessonListItem> listForEvent(UUID eventId) {
        var event = events.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Event not found: " + eventId));
        if (event.getStatus() != EventStatus.PUBLISHED) {
            throw new ResourceNotFoundException("Event not found: " + eventId);
        }
        return lessons.findByEventIdAndStatusOrderByTitle(eventId, LessonStatus.PUBLISHED).stream()
                .map(l -> new LearnerLessonListItem(l.getId(), l.getTitle(),
                        l.getCentralQuestion()))
                .toList();
    }

    /** Published lesson metadata; unpublished lessons read as not found. */
    @Transactional(readOnly = true)
    public LearnerLessonMetadata getMetadata(UUID lessonId) {
        Lesson l = loadPublished(lessonId);
        LessonVersion current = versions.findById(l.getCurrentVersionId())
                .orElseThrow(() -> new VersionNotFoundException(
                        "current version row missing for lesson " + lessonId));
        return new LearnerLessonMetadata(l.getId(), l.getTitle(), l.getCentralQuestion(),
                l.getEventId(), l.getCurrentVersionId(),
                current.getVersionNo(), current.getPublishedAt());
    }

    /** Learner-safe projection of the current published snapshot. */
    @Transactional(readOnly = true)
    public LearnerLessonContent getContent(UUID lessonId) {
        Lesson l = loadPublished(lessonId);
        LessonVersion v = versions.findById(l.getCurrentVersionId())
                .orElseThrow(() -> new VersionNotFoundException(
                        "current version row missing for lesson " + lessonId));
        return new LearnerLessonContent(lessonId, v.getId(), v.getVersionNo(),
                projection.project(parse(v.getSnapshotJson())));
    }

    private Lesson loadPublished(UUID lessonId) {
        Lesson l = lessons.findById(lessonId)
                .orElseThrow(() -> new LessonNotFoundException("Lesson not found: " + lessonId));
        if (l.getStatus() != LessonStatus.PUBLISHED || l.getCurrentVersionId() == null) {
            throw new LessonNotPublishedException("lesson is not published: " + lessonId);
        }
        return l;
    }

    private com.fasterxml.jackson.databind.JsonNode parse(String json) {
        try {
            return objectMapper.readTree(json);
        } catch (Exception e) {
            // A corrupt published snapshot is a data-integrity defect — log the
            // fact and surface an empty document rather than leaking internals.
            org.slf4j.LoggerFactory.getLogger(LearnerLessonService.class)
                    .error("unparseable snapshot_json: {}", e.getMessage());
            return objectMapper.createObjectNode();
        }
    }
}
