package com.dauviet.lesson.api;

import java.util.List;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.lesson.api.dto.LearnerLessonContent;
import com.dauviet.lesson.api.dto.LearnerLessonListItem;
import com.dauviet.lesson.api.dto.LearnerLessonMetadata;
import com.dauviet.lesson.application.LearnerLessonService;

/**
 * Public learner lesson surface: published lessons of a published event,
 * lesson metadata, and the learner-safe current-version content.
 * Presentation data only — answer keys and validation internals are stripped
 * by LearnerProjectionService before anything reaches here.
 */
@RestController
@RequestMapping("/api/v1")
public class LearnerLessonController {

    private final LearnerLessonService lessons;

    public LearnerLessonController(LearnerLessonService lessons) {
        this.lessons = lessons;
    }

    /** Published lessons belonging to a published event. */
    @GetMapping("/events/{eventId}/lessons")
    public List<LearnerLessonListItem> listForEvent(@PathVariable UUID eventId) {
        return lessons.listForEvent(eventId);
    }

    /** Published lesson metadata; unpublished reads as not found. */
    @GetMapping("/lessons/{lessonId}")
    public LearnerLessonMetadata getMetadata(@PathVariable UUID lessonId) {
        return lessons.getMetadata(lessonId);
    }

    /** Learner-safe content of the current published version. */
    @GetMapping("/lessons/{lessonId}/content")
    public LearnerLessonContent getContent(@PathVariable UUID lessonId) {
        return lessons.getContent(lessonId);
    }
}
