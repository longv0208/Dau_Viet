package com.dauviet.path.api.dto;

import java.util.List;
import java.util.UUID;

import com.dauviet.path.domain.PathContentStatus;
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
            String code,
            String title,
            String description,
            Integer startYear,
            Integer endYear,
            String periodLabel,
            int sortOrder,
            String themeKey,
            List<EventNodeResponse> events
    ) {}

    public record EventNodeResponse(
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
            ParticipationType participationType
    ) {}

    public record LessonNodeResponse(
            UUID lessonNodeId,
            UUID lessonId,
            String title,
            int sortOrder,
            String status
    ) {}
}
