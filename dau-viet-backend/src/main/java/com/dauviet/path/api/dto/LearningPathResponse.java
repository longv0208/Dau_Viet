package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;

import com.dauviet.path.domain.PathContentStatus;
import com.dauviet.path.domain.PathNodeType;
import com.dauviet.path.domain.ParticipationType;

public record LearningPathResponse(
        String pathCode,
        int pathVersion,
        String title,
        String description,
        List<ChapterResponse> chapters
) {
    public record ChapterResponse(
            UUID chapterId,
            UUID parentId,
            PathNodeType nodeType,
            String code,
            String title,
            String description,
            Integer startYear,
            Integer endYear,
            String periodLabel,
            int sortOrder,
            String themeKey,
            List<EventNodeResponse> events
    ) {
        public ChapterResponse(
                UUID chapterId,
                String code,
                String title,
                String description,
                Integer startYear,
                Integer endYear,
                String periodLabel,
                int sortOrder,
                String themeKey,
                List<EventNodeResponse> events) {
            this(chapterId, null, PathNodeType.PERIOD, code, title, description,
                    startYear, endYear, periodLabel, sortOrder, themeKey, events);
        }
    }

    public record EventNodeResponse(
            UUID nodeId,
            UUID eventId,
            String slug,
            String title,
            Integer startYear,
            Integer endYear,
            String datePrecision,
            String yearLabel,
            String period,
            String coverAssetKey,
            int sortOrder,
            PathContentStatus contentStatus,
            List<LessonNodeResponse> lessons,
            ParticipationType participationType
    ) {
        public EventNodeResponse(
                UUID nodeId,
                UUID eventId,
                String slug,
                String title,
                Integer startYear,
                String yearLabel,
                String period,
                String coverAssetKey,
                int sortOrder,
                PathContentStatus contentStatus,
                List<LessonNodeResponse> lessons,
                ParticipationType participationType) {
            this(nodeId, eventId, slug, title, startYear, null, "EXACT",
                    yearLabel, period, coverAssetKey, sortOrder, contentStatus,
                    lessons, participationType);
        }
    }

    public record LessonNodeResponse(
            UUID lessonNodeId,
            UUID lessonId,
            String title,
            int sortOrder,
            String status
    ) {}
}
