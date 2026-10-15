package com.dauviet.lesson.api.mapper;

import org.springframework.stereotype.Component;

import com.dauviet.lesson.api.dto.AdminLessonResponse;
import com.dauviet.lesson.api.dto.AdminLessonSummaryResponse;
import com.dauviet.lesson.domain.Lesson;

/** Entity → admin DTO mapping for lessons. */
@Component
public class AdminLessonMapper {

    public AdminLessonResponse toResponse(Lesson l) {
        return new AdminLessonResponse(
                l.getId(), l.getEventId(), l.getTemplateId(), l.getTitle(),
                l.getCentralQuestion(), l.getObjectivesJson(), l.getDraftJson(),
                l.getStatus().name(), l.getCurrentVersionId(), l.getRowVersion(),
                l.getCreatedBy(), l.getUpdatedBy(), l.getCreatedAt(), l.getUpdatedAt());
    }

    public AdminLessonSummaryResponse toSummary(Lesson l) {
        return new AdminLessonSummaryResponse(
                l.getId(), l.getEventId(), l.getTitle(), l.getStatus().name(),
                l.getCurrentVersionId(), l.getRowVersion());
    }
}
