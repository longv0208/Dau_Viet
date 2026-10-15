package com.dauviet.lesson.application;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Corrupt published snapshot_json must surface as SnapshotCorruptException
 * (500 SNAPSHOT_CORRUPT) — never silent empty learner content.
 */
class LearnerLessonServiceTest {

    @Test
    void getContent_corruptSnapshot_throwsSnapshotCorrupt() {
        LessonRepository lessons = mock(LessonRepository.class);
        LessonVersionRepository versions = mock(LessonVersionRepository.class);
        HistoricalEventRepository events = mock(HistoricalEventRepository.class);
        LearnerProjectionService projection = new LearnerProjectionService();
        LearnerLessonService svc = new LearnerLessonService(
                lessons, versions, events, projection, new ObjectMapper());

        UUID lessonId = UUID.randomUUID();
        UUID versionId = UUID.randomUUID();
        Lesson lesson = new Lesson();
        lesson.setId(lessonId);
        lesson.setStatus(LessonStatus.PUBLISHED);
        lesson.setCurrentVersionId(versionId);
        LessonVersion v = new LessonVersion();
        v.setId(versionId);
        v.setLessonId(lessonId);
        v.setVersionNo(1);
        v.setSnapshotJson("{not-valid-json"); // jsonb normally prevents this
        when(lessons.findById(lessonId)).thenReturn(Optional.of(lesson));
        when(versions.findById(versionId)).thenReturn(Optional.of(v));

        assertThatThrownBy(() -> svc.getContent(lessonId))
                .isInstanceOf(SnapshotCorruptException.class);
    }
}
