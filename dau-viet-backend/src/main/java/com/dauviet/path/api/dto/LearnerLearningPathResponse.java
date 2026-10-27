package com.dauviet.path.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import com.dauviet.historicalevent.domain.DatePrecision;
import com.dauviet.path.domain.LearnerPathStatus;
import com.dauviet.path.domain.ParticipationType;
import com.dauviet.path.domain.PathContentStatus;
import com.dauviet.path.domain.PathNodeType;

public record LearnerLearningPathResponse(
        String pathCode,
        int pathVersion,
        boolean enrolled,
        Summary summary,
        Current current,
        List<Chapter> chapters,
        List<PeriodProgress> periodProgress,
        Map<String, Current> currentByPeriod,
        String lastPeriodCode
) {
    public LearnerLearningPathResponse(
            String pathCode,
            int pathVersion,
            boolean enrolled,
            Summary summary,
            Current current,
            List<Chapter> chapters) {
        this(pathCode, pathVersion, enrolled, summary, current, chapters, List.of(), Map.of(), null);
    }

    public record Summary(
            long completedEvents,
            long totalRequiredEvents,
            long completedLessons,
            long totalRequiredLessons
    ) {}

    public record Current(
            UUID chapterId,
            UUID eventNodeId,
            UUID lessonId
    ) {}

    public record PeriodProgress(
            UUID chapterId,
            String code,
            String title,
            long completedEvents,
            long requiredEvents,
            long completedLessons,
            long requiredLessons,
            int percent
    ) {}

    public record Chapter(
            UUID chapterId,
            UUID parentId,
            PathNodeType nodeType,
            String code,
            String title,
            int sortOrder,
            List<Event> events
    ) {
        public Chapter(UUID chapterId, String code, String title, int sortOrder, List<Event> events) {
            this(chapterId, null, PathNodeType.PERIOD, code, title, sortOrder, events);
        }
    }

    public record Event(
            UUID eventNodeId,
            UUID eventId,
            String title,
            String yearLabel,
            Integer endYear,
            DatePrecision datePrecision,
            int sortOrder,
            ParticipationType participationType,
            LearnerPathStatus status,
            PathContentStatus contentStatus,
            List<Lesson> lessons
    ) {
        public Event(UUID eventNodeId, UUID eventId, String title, String yearLabel, int sortOrder,
                ParticipationType participationType, LearnerPathStatus status, PathContentStatus contentStatus,
                List<Lesson> lessons) {
            this(eventNodeId, eventId, title, yearLabel, null, DatePrecision.EXACT, sortOrder,
                    participationType, status, contentStatus, lessons);
        }
    }

    public record Lesson(
            UUID lessonId,
            String title,
            int sortOrder,
            LearnerPathStatus status
    ) {}

    public record TouchPeriodResponse(
            String periodCode,
            UUID chapterId,
            Instant touchedAt
    ) {}
}
