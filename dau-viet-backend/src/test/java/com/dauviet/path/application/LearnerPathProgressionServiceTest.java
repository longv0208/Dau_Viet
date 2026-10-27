package com.dauviet.path.application;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.learning.domain.LearnerAttempt;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathEventNode;
import com.dauviet.path.domain.LearningPathLessonNode;
import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;
import com.dauviet.path.domain.LessonLockedByPathException;
import com.dauviet.path.domain.ParticipationType;
import com.dauviet.path.domain.PathContentStatus;
import com.dauviet.path.domain.UserLearningPathEnrollment;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathLessonNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathVersionRepository;
import com.dauviet.path.infrastructure.persistence.UserLearningPathEnrollmentRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;

class LearnerPathProgressionServiceTest {

    private LearningPathVersionRepository versions;
    private LearningPathChapterRepository chapters;
    private LearningPathEventNodeRepository events;
    private LearningPathLessonNodeRepository lessonNodes;
    private HistoricalEventRepository historicalEvents;
    private LessonRepository lessons;
    private EventCompletionPolicyRepository policies;
    private UserEventProgressRepository progress;
    private LearnerAttemptRepository attempts;
    private UserLearningPathEnrollmentRepository enrollments;
    private PathReadiness readiness;
    private EntityManager entityManager;
    private LearnerPathProgressionService service;

    private final UUID userId = UUID.randomUUID();
    private final UUID versionId = UUID.randomUUID();
    private final UUID chapterId = UUID.randomUUID();
    private final UUID eventNode1Id = UUID.randomUUID();
    private final UUID event1Id = UUID.randomUUID();
    private final UUID lesson1Id = UUID.randomUUID();
    private final UUID lesson2Id = UUID.randomUUID();
    private final UUID outOfPathLessonId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        versions = mock(LearningPathVersionRepository.class);
        chapters = mock(LearningPathChapterRepository.class);
        events = mock(LearningPathEventNodeRepository.class);
        lessonNodes = mock(LearningPathLessonNodeRepository.class);
        historicalEvents = mock(HistoricalEventRepository.class);
        lessons = mock(LessonRepository.class);
        policies = mock(EventCompletionPolicyRepository.class);
        progress = mock(UserEventProgressRepository.class);
        attempts = mock(LearnerAttemptRepository.class);
        enrollments = mock(UserLearningPathEnrollmentRepository.class);
        readiness = mock(PathReadiness.class);
        entityManager = mock(EntityManager.class);

        Query lockQuery = mock(Query.class);
        when(entityManager.createNativeQuery(anyString())).thenReturn(lockQuery);
        when(lockQuery.setParameter(anyString(), any())).thenReturn(lockQuery);
        when(lockQuery.getSingleResult()).thenReturn(null);

        LearningPathVersion version = new LearningPathVersion(
                versionId, "HISTORY_MAIN", 1, "Hành trình", "Desc", LearningPathStatus.PUBLISHED, Instant.now());
        when(enrollments.findByIdUserIdAndIdPathCode(userId, "HISTORY_MAIN"))
                .thenReturn(Optional.of(new UserLearningPathEnrollment(userId, "HISTORY_MAIN", versionId)));
        when(versions.findById(versionId)).thenReturn(Optional.of(version));

        LearningPathChapter ch = new LearningPathChapter(
                chapterId, versionId, "CH1", "Chapter 1", "Desc", 900, 1000, "900-1000", 1, "THEME");
        when(chapters.findByPathVersionIdOrderBySortOrderAsc(versionId)).thenReturn(List.of(ch));

        LearningPathEventNode evNode1 = new LearningPathEventNode(eventNode1Id, chapterId, versionId, event1Id, 1);
        evNode1.setParticipationType(ParticipationType.REQUIRED);
        when(events.findByPathVersionIdOrderBySortOrderAsc(versionId)).thenReturn(List.of(evNode1));

        LearningPathLessonNode ln1 = new LearningPathLessonNode(UUID.randomUUID(), eventNode1Id, event1Id, lesson1Id, 1);
        LearningPathLessonNode ln2 = new LearningPathLessonNode(UUID.randomUUID(), eventNode1Id, event1Id, lesson2Id, 2);
        when(lessonNodes.findByEventNodeIdInOrderBySortOrderAsc(List.of(eventNode1Id))).thenReturn(List.of(ln1, ln2));

        HistoricalEvent ev1 = new HistoricalEvent();
        ev1.setId(event1Id);
        ev1.setTitle("Bạch Đằng 938");
        when(historicalEvents.findAllById(any())).thenReturn(List.of(ev1));

        Lesson l1 = new Lesson();
        l1.setId(lesson1Id);
        l1.setEventId(event1Id);
        Lesson l2 = new Lesson();
        l2.setId(lesson2Id);
        l2.setEventId(event1Id);
        when(lessons.findAllById(any())).thenReturn(List.of(l1, l2));

        EventCompletionPolicy policy = mock(EventCompletionPolicy.class);
        when(policy.getEventId()).thenReturn(event1Id);
        when(policy.getRequiredLessonIdsJson()).thenReturn("[\"" + lesson1Id + "\",\"" + lesson2Id + "\"]");
        when(policies.findPublishedByEventIdIn(any())).thenReturn(List.of(policy));

        when(readiness.snapshots(any())).thenReturn(Map.of());
        when(readiness.status(any(), any(), any(), any(), any())).thenReturn(PathContentStatus.PLAYABLE);
        when(readiness.policyIds(policy.getRequiredLessonIdsJson())).thenReturn(List.of(lesson1Id, lesson2Id));

        when(attempts.findDistinctCompletedLessonIds(userId)).thenReturn(Set.of());
        when(attempts.findDistinctInProgressLessonIds(userId)).thenReturn(Set.of());
        when(progress.findEventIdsByUserAndMilestoneAndEventIdIn(any(), anyString(), any())).thenReturn(Set.of());

        service = new LearnerPathProgressionService(
                versions, chapters, events, lessonNodes, historicalEvents, lessons,
                policies, progress, attempts, enrollments, readiness, entityManager);
    }

    @Test
    @DisplayName("Bài học PUBLISHED nằm ngoài lộ trình (status == null) được phép học tự do")
    void allowsPublishedLessonOutsideLearningPath() {
        when(attempts.findInProgressByUserIdAndLessonId(userId, outOfPathLessonId)).thenReturn(Optional.empty());

        assertThatCode(() -> service.requireLessonAvailableForNewAttempt(userId, outOfPathLessonId))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Bài học bắt buộc đầu tiên trong sự kiện AVAILABLE được phép bắt đầu")
    void allowsFirstAvailableLessonInPath() {
        when(attempts.findInProgressByUserIdAndLessonId(userId, lesson1Id)).thenReturn(Optional.empty());

        assertThatCode(() -> service.requireLessonAvailableForNewAttempt(userId, lesson1Id))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("Bài học bắt buộc thứ hai trong sự kiện khi chưa hoàn thành bài đầu tiên bị chặn với LessonLockedByPathException")
    void blocksLockedLessonInPath() {
        when(attempts.findInProgressByUserIdAndLessonId(userId, lesson2Id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.requireLessonAvailableForNewAttempt(userId, lesson2Id))
                .isInstanceOf(LessonLockedByPathException.class)
                .hasMessageContaining("locked by the learner's learning path");
    }

    @Test
    @DisplayName("Bài học đang có attempt IN_PROGRESS luôn được phép tiếp tục bất kể trạng thái khóa")
    void allowsResumingInProgressAttemptEvenIfLocked() {
        when(attempts.findInProgressByUserIdAndLessonId(userId, lesson2Id))
                .thenReturn(Optional.of(new LearnerAttempt()));

        assertThatCode(() -> service.requireLessonAvailableForNewAttempt(userId, lesson2Id))
                .doesNotThrowAnyException();
    }
}
