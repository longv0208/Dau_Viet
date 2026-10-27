package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;
import com.dauviet.path.domain.LearnerPathStatus;
import com.dauviet.path.domain.ParticipationType;
import com.dauviet.path.domain.PathContentStatus;

public record LearnerLearningPathResponse(String pathCode, int pathVersion, boolean enrolled,
        Summary summary, Current current, List<Chapter> chapters) {
    public record Summary(long completedEvents, long totalRequiredEvents, long completedLessons, long totalRequiredLessons) {}
    public record Current(UUID chapterId, UUID eventNodeId, UUID lessonId) {}
    public record Chapter(UUID chapterId, String code, String title, int sortOrder, List<Event> events) {}
    public record Event(UUID eventNodeId, UUID eventId, String title, String yearLabel, int sortOrder,
            ParticipationType participationType, LearnerPathStatus status, PathContentStatus contentStatus,
            List<Lesson> lessons) {}
    public record Lesson(UUID lessonId, String title, int sortOrder, LearnerPathStatus status) {}
}
