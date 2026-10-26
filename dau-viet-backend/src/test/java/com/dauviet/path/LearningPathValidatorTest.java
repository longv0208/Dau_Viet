package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.api.dto.PathAuditReport;
import com.dauviet.path.application.LearningPathValidator;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathExceptions.PathValidationException;
import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathLessonNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathVersionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

@DisplayName("PATH-01 — LearningPathValidator Unit Tests")
class LearningPathValidatorTest {

    private LearningPathVersionRepository versionRepo;
    private LearningPathChapterRepository chapterRepo;
    private LearningPathEventNodeRepository eventNodeRepo;
    private LearningPathLessonNodeRepository lessonNodeRepo;
    private HistoricalEventRepository historicalEventRepo;
    private LessonRepository lessonRepo;
    private EventCompletionPolicyRepository policyRepo;
    private ObjectMapper mapper;
    private LearningPathValidator validator;

    @BeforeEach
    void setUp() {
        versionRepo = mock(LearningPathVersionRepository.class);
        chapterRepo = mock(LearningPathChapterRepository.class);
        eventNodeRepo = mock(LearningPathEventNodeRepository.class);
        lessonNodeRepo = mock(LearningPathLessonNodeRepository.class);
        historicalEventRepo = mock(HistoricalEventRepository.class);
        lessonRepo = mock(LessonRepository.class);
        policyRepo = mock(EventCompletionPolicyRepository.class);
        mapper = new ObjectMapper();

        validator = new LearningPathValidator(
                versionRepo, chapterRepo, eventNodeRepo, lessonNodeRepo,
                historicalEventRepo, lessonRepo, policyRepo, mapper);
    }

    @Test
    @DisplayName("Phát hiện lỗi khi chapter có startYear > endYear")
    void detectInvalidChapterYears() {
        UUID vId = UUID.randomUUID();
        LearningPathVersion version = new LearningPathVersion(
                vId, "HISTORY_MAIN", 1, "Test Path", null, LearningPathStatus.DRAFT, null);
        when(versionRepo.findByPathCodeAndVersionNo("HISTORY_MAIN", 1)).thenReturn(Optional.of(version));

        LearningPathChapter badChapter = new LearningPathChapter(
                UUID.randomUUID(), vId, "BAD_CH", "Bad Chapter", null,
                1000, 500, "1000 - 500", 1, "THEME");
        when(chapterRepo.findByPathVersionIdOrderBySortOrderAsc(vId)).thenReturn(List.of(badChapter));
        when(eventNodeRepo.findByPathVersionIdOrderBySortOrderAsc(vId)).thenReturn(Collections.emptyList());

        PathAuditReport report = validator.audit("HISTORY_MAIN", 1);
        assertThat(report.issues()).anyMatch(i -> "INVALID_CHAPTER_YEARS".equals(i.code()));

        assertThatThrownBy(() -> validator.validateForPublish("HISTORY_MAIN", 1))
                .isInstanceOf(PathValidationException.class)
                .hasMessageContaining("startYear 1000 > endYear 500");
    }

    @Test
    @DisplayName("Cảnh báo khi chapter có 0 sự kiện")
    void warningOnEmptyChapter() {
        UUID vId = UUID.randomUUID();
        LearningPathVersion version = new LearningPathVersion(
                vId, "HISTORY_MAIN", 1, "Test Path", null, LearningPathStatus.DRAFT, null);
        when(versionRepo.findByPathCodeAndVersionNo("HISTORY_MAIN", 1)).thenReturn(Optional.of(version));

        LearningPathChapter emptyChapter = new LearningPathChapter(
                UUID.randomUUID(), vId, "EMPTY_CH", "Chương Trống", null,
                100, 200, "100 - 200", 1, "THEME");
        when(chapterRepo.findByPathVersionIdOrderBySortOrderAsc(vId)).thenReturn(List.of(emptyChapter));
        when(eventNodeRepo.findByPathVersionIdOrderBySortOrderAsc(vId)).thenReturn(Collections.emptyList());

        PathAuditReport report = validator.audit("HISTORY_MAIN", 1);
        assertThat(report.emptyChapters()).contains("EMPTY_CH");
        assertThat(report.issues()).anyMatch(i -> "EMPTY_CHAPTER".equals(i.code()) && "WARNING".equals(i.level()));
    }
}
