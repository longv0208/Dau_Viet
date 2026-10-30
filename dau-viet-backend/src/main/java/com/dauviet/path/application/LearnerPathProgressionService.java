package com.dauviet.path.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.common.heritage.HeritageBackgroundConfigDto;
import com.dauviet.collection.domain.UserEventProgress;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.domain.DatePrecision;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.api.dto.LearnerLearningPathResponse;
import com.dauviet.path.domain.LearnerPathStatus;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathEventNode;
import com.dauviet.path.domain.LearningPathExceptions;
import com.dauviet.path.domain.LearningPathLessonNode;
import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.domain.LearningPathVersion;
import com.dauviet.path.domain.LessonLockedByPathException;
import com.dauviet.path.domain.ParticipationType;
import com.dauviet.path.domain.PathContentStatus;
import com.dauviet.path.domain.PathNodeType;
import com.dauviet.path.domain.UserLearningPathEnrollment;
import com.dauviet.path.domain.UserPathPeriodState;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathLessonNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathVersionRepository;
import com.dauviet.path.infrastructure.persistence.UserLearningPathEnrollmentRepository;
import com.dauviet.path.infrastructure.persistence.UserPathPeriodStateRepository;

import jakarta.persistence.EntityManager;

/**
 * Computes learner access from the active published path and existing completion ledgers.
 * Sequential locking is scoped per PERIOD chapter so learners can explore any historical
 * period in parallel while progressing sequentially within each period.
 */
@Service
@Transactional(readOnly = true)
public class LearnerPathProgressionService {

    private final LearningPathVersionRepository versions;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;
    private final LearningPathLessonNodeRepository lessonNodes;
    private final HistoricalEventRepository historicalEvents;
    private final LessonRepository lessons;
    private final EventCompletionPolicyRepository policies;
    private final UserEventProgressRepository progress;
    private final LearnerAttemptRepository attempts;
    private final UserLearningPathEnrollmentRepository enrollments;
    private final PathReadiness readiness;
    private final EntityManager entityManager;
    private UserPathPeriodStateRepository periodStates;

    public LearnerPathProgressionService(
            LearningPathVersionRepository versions,
            LearningPathChapterRepository chapters,
            LearningPathEventNodeRepository events,
            LearningPathLessonNodeRepository lessonNodes,
            HistoricalEventRepository historicalEvents,
            LessonRepository lessons,
            EventCompletionPolicyRepository policies,
            UserEventProgressRepository progress,
            LearnerAttemptRepository attempts,
            UserLearningPathEnrollmentRepository enrollments,
            PathReadiness readiness,
            EntityManager entityManager) {
        this.versions = versions;
        this.chapters = chapters;
        this.events = events;
        this.lessonNodes = lessonNodes;
        this.historicalEvents = historicalEvents;
        this.lessons = lessons;
        this.policies = policies;
        this.progress = progress;
        this.attempts = attempts;
        this.enrollments = enrollments;
        this.readiness = readiness;
        this.entityManager = entityManager;
    }

    @Autowired(required = false)
    public void setPeriodStates(UserPathPeriodStateRepository periodStates) {
        this.periodStates = periodStates;
    }

    @Transactional
    public LearningPathVersion enrolledVersion(UUID userId, String pathCode) {
        String code = pathCode == null || pathCode.isBlank()
                ? LearningPathService.DEFAULT_PATH_CODE
                : pathCode.trim();
        entityManager.createNativeQuery("select pg_advisory_xact_lock(hashtextextended(:k, 0::bigint))")
                .setParameter("k", userId + "|" + code).getSingleResult();

        Optional<LearningPathVersion> latestPublished =
                versions.findByPathCodeAndStatus(code, LearningPathStatus.PUBLISHED);
        Optional<UserLearningPathEnrollment> existing =
                enrollments.findByIdUserIdAndIdPathCode(userId, code);

        if (existing.isPresent()) {
            UserLearningPathEnrollment enrollment = existing.get();
            if (latestPublished.isPresent()
                    && !latestPublished.get().getId().equals(enrollment.getPathVersionId())) {
                enrollment.setPathVersionId(latestPublished.get().getId());
                enrollments.saveAndFlush(enrollment);
                return latestPublished.get();
            }
            if (latestPublished.isPresent()
                    && latestPublished.get().getId().equals(enrollment.getPathVersionId())) {
                return latestPublished.get();
            }
            Optional<LearningPathVersion> pinned = versions.findById(enrollment.getPathVersionId());
            if (pinned.isPresent()) {
                return pinned.get();
            }
        }

        LearningPathVersion published = latestPublished
                .orElseThrow(() -> new LearningPathExceptions.PathNotFoundException(code));
        enrollments.saveAndFlush(new UserLearningPathEnrollment(userId, code, published.getId()));
        return published;
    }

    @Transactional
    public LearnerLearningPathResponse pathFor(UUID userId) {
        return project(userId, enrolledVersion(userId, LearningPathService.DEFAULT_PATH_CODE));
    }

    @Transactional
    public LearnerLearningPathResponse.TouchPeriodResponse touchPeriod(UUID userId, String periodCode) {
        LearningPathVersion version = enrolledVersion(userId, LearningPathService.DEFAULT_PATH_CODE);
        LearningPathChapter chapter = chapters.findByPathVersionIdAndCode(version.getId(), periodCode)
                .orElseThrow(() -> new ResourceNotFoundException("Period chapter not found: " + periodCode));
        PathNodeType type = chapter.getNodeType() == null ? PathNodeType.PERIOD : chapter.getNodeType();
        if (type != PathNodeType.PERIOD) {
            throw new ResourceNotFoundException("Chapter is not a PERIOD: " + periodCode);
        }
        Instant now = Instant.now();
        if (periodStates != null) {
            UserPathPeriodState.Key key =
                    new UserPathPeriodState.Key(userId, version.getPathCode(), chapter.getId());
            UserPathPeriodState state = periodStates.findById(key)
                    .orElseGet(() -> new UserPathPeriodState(userId, version.getPathCode(), chapter.getId(), now));
            state.setLastTouchedAt(now);
            periodStates.saveAndFlush(state);
        }
        return new LearnerLearningPathResponse.TouchPeriodResponse(
                chapter.getCode(), chapter.getId(), now);
    }

    public void requireLessonAvailableForNewAttempt(UUID userId, UUID lessonId) {
        if (attempts.findInProgressByUserIdAndLessonId(userId, lessonId).isPresent()) return;
        final LearningPathVersion version;
        try {
            version = enrolledVersion(userId, LearningPathService.DEFAULT_PATH_CODE);
        } catch (LearningPathExceptions.PathNotFoundException ex) {
            return;
        }
        Projection projection = load(userId, version);
        LearnerPathStatus status = projection.lessonStatus.get(lessonId);
        if (status == null) return;
        if (status != LearnerPathStatus.AVAILABLE
                && status != LearnerPathStatus.IN_PROGRESS
                && status != LearnerPathStatus.COMPLETED
                && status != LearnerPathStatus.MASTERED) {
            throw new LessonLockedByPathException("Lesson is locked by the learner's learning path");
        }
    }

    private LearnerLearningPathResponse project(UUID userId, LearningPathVersion version) {
        Projection p = load(userId, version);
        List<LearnerLearningPathResponse.Chapter> out = new ArrayList<>();
        for (LearningPathChapter chapter : p.chapters) {
            List<LearnerLearningPathResponse.Event> eventOut = new ArrayList<>();
            for (LearningPathEventNode node : p.byChapter.getOrDefault(chapter.getId(), List.of())) {
                HistoricalEvent event = p.eventMap.get(node.getEventId());
                List<LearnerLearningPathResponse.Lesson> lessonOut = new ArrayList<>();
                for (LearningPathLessonNode ln : p.byNode.getOrDefault(node.getId(), List.of())) {
                    Lesson lesson = p.lessonMap.get(ln.getLessonId());
                    LearnerPathStatus lessonStatus = p.lessonStatus.getOrDefault(
                            ln.getLessonId(), LearnerPathStatus.NOT_READY);
                    lessonOut.add(new LearnerLearningPathResponse.Lesson(
                            ln.getLessonId(),
                            lesson == null ? null : lesson.getTitle(),
                            ln.getSortOrder(),
                            lessonStatus,
                            lesson == null ? null : lesson.getCoverAssetId(),
                            lesson == null || lesson.getCoverAssetId() == null
                                    ? null
                                    : "/api/v1/assets/" + lesson.getCoverAssetId() + "/content",
                            lesson == null
                                    ? HeritageBackgroundConfigDto.defaultConfig()
                                    : lesson.getBackgroundConfig()));
                }
                LearnerPathStatus eventStatus = p.eventStatus.get(node.getId());
                eventOut.add(new LearnerLearningPathResponse.Event(
                        node.getId(),
                        node.getEventId(),
                        event == null ? null : event.getSlug(),
                        event == null ? null : event.getTitle(),
                        event == null ? null : event.getStartYear(),
                        event == null ? null : YearLabelFormatter.formatYear(event.getStartYear(), event.getPeriod()),
                        event == null ? null : event.getEndYear(),
                        event == null || event.getDatePrecision() == null ? DatePrecision.EXACT : DatePrecision.valueOf(event.getDatePrecision()),
                        event == null ? null : event.getPeriod(),
                        event == null ? null : event.getCoverAssetKey(),
                        event == null
                                ? HeritageBackgroundConfigDto.defaultConfig()
                                : event.getBackgroundConfig(),
                        node.getSortOrder(),
                        node.getParticipationType(),
                        eventStatus,
                        p.contentStatus.get(node.getId()),
                        lessonOut));
            }
            out.add(new LearnerLearningPathResponse.Chapter(
                    chapter.getId(),
                    chapter.getParentId(),
                    chapter.getNodeType() == null ? PathNodeType.PERIOD : chapter.getNodeType(),
                    chapter.getCode(),
                    chapter.getTitle(),
                    chapter.getDescription(),
                    chapter.getStartYear(),
                    chapter.getEndYear(),
                    chapter.getPeriodLabel(),
                    chapter.getSortOrder(),
                    chapter.getThemeKey(),
                    chapter.getCoverImageKey(),
                    chapter.getBackgroundConfig(),
                    eventOut));
        }

        String lastPeriodCode = resolveLastPeriodCode(userId, version, p);
        LearnerLearningPathResponse.Current current = lastPeriodCode != null
                ? p.currentByPeriod.get(lastPeriodCode)
                : null;
        if (current == null) {
            current = p.currentByPeriod.values().stream()
                    .filter(Objects::nonNull)
                    .findFirst()
                    .orElse(null);
        }

        return new LearnerLearningPathResponse(
                version.getPathCode(),
                version.getVersionNo(),
                true,
                new LearnerLearningPathResponse.Summary(
                        p.completedEvents,
                        p.requiredNodes.size(),
                        p.completedRequiredLessons,
                        p.totalRequiredLessons),
                current,
                out,
                p.periodProgress,
                p.currentByPeriod,
                lastPeriodCode);
    }

    private String resolveLastPeriodCode(UUID userId, LearningPathVersion version, Projection p) {
        Map<UUID, LearningPathChapter> periodById = p.periodChapters.stream()
                .collect(Collectors.toMap(LearningPathChapter::getId, Function.identity()));
        if (periodStates != null) {
            List<UserPathPeriodState> states =
                    periodStates.findByIdUserIdAndIdPathCodeOrderByLastTouchedAtDesc(userId, version.getPathCode());
            for (UserPathPeriodState state : states) {
                LearningPathChapter ch = periodById.get(state.getId().getPeriodChapterId());
                if (ch != null) {
                    return ch.getCode();
                }
            }
        }
        for (LearningPathChapter ch : p.periodChapters) {
            if (p.currentByPeriod.get(ch.getCode()) != null) {
                return ch.getCode();
            }
        }
        return p.periodChapters.isEmpty() ? null : p.periodChapters.get(0).getCode();
    }

    private Projection load(UUID userId, LearningPathVersion version) {
        List<LearningPathChapter> rawChapters = chapters.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<LearningPathChapter> chapterList = orderChaptersTreeFirst(rawChapters);
        List<LearningPathEventNode> nodeList = events.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<UUID> nodeIds = nodeList.stream().map(LearningPathEventNode::getId).toList();
        List<LearningPathLessonNode> nodeLessons = nodeIds.isEmpty()
                ? List.of()
                : lessonNodes.findByEventNodeIdInOrderBySortOrderAsc(nodeIds);
        Map<UUID, HistoricalEvent> eventMap = historicalEvents.findAllById(
                nodeList.stream().map(LearningPathEventNode::getEventId).toList())
                .stream().collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));
        Map<UUID, Lesson> lessonMap = lessons.findAllById(
                nodeLessons.stream().map(LearningPathLessonNode::getLessonId).toList())
                .stream().collect(Collectors.toMap(Lesson::getId, Function.identity()));
        Map<UUID, EventCompletionPolicy> policyMap = nodeList.isEmpty()
                ? Map.of()
                : policies.findPublishedByEventIdIn(eventMap.keySet())
                        .stream().collect(Collectors.toMap(EventCompletionPolicy::getEventId, Function.identity()));
        readiness.includePolicyLessons(lessonMap, policyMap.values(), lessons);
        Map<UUID, LessonVersion> snapshots = readiness.snapshots(lessonMap.values());
        Map<UUID, List<LearningPathEventNode>> byChapter = nodeList.stream()
                .collect(Collectors.groupingBy(LearningPathEventNode::getChapterId));
        Map<UUID, List<LearningPathLessonNode>> byNode = nodeLessons.stream()
                .collect(Collectors.groupingBy(LearningPathLessonNode::getEventNodeId));
        Set<UUID> completed = attempts.findDistinctCompletedLessonIds(userId);
        Set<UUID> inProgressLessons = attempts.findDistinctInProgressLessonIds(userId);
        Set<UUID> pathEventIds = nodeList.stream()
                .map(LearningPathEventNode::getEventId)
                .collect(Collectors.toSet());
        Set<UUID> completedEvents = pathEventIds.isEmpty()
                ? Set.of()
                : progress.findEventIdsByUserAndMilestoneAndEventIdIn(
                        userId, UserEventProgress.Milestone.EVENT_COMPLETED.name(), pathEventIds);
        Set<UUID> masteredEvents = pathEventIds.isEmpty()
                ? Set.of()
                : progress.findEventIdsByUserAndMilestoneAndEventIdIn(
                        userId, UserEventProgress.Milestone.EVENT_MASTERED.name(), pathEventIds);

        Projection p = new Projection(chapterList, byChapter, byNode, eventMap, lessonMap);

        // Identify PERIOD chapters (and any child PHASE chapters belonging to each PERIOD)
        List<LearningPathChapter> periodChapters = chapterList.stream()
                .filter(c -> (c.getNodeType() == null ? PathNodeType.PERIOD : c.getNodeType()) == PathNodeType.PERIOD)
                .toList();
        p.periodChapters = periodChapters;

        Map<UUID, List<LearningPathChapter>> phasesByPeriod = chapterList.stream()
                .filter(c -> c.getNodeType() == PathNodeType.PHASE && c.getParentId() != null)
                .collect(Collectors.groupingBy(LearningPathChapter::getParentId));

        List<LearningPathEventNode> allRequiredNodes = new ArrayList<>();

        for (LearningPathChapter period : periodChapters) {
            List<LearningPathEventNode> periodNodes = new ArrayList<>(
                    byChapter.getOrDefault(period.getId(), List.of()));
            for (LearningPathChapter phase : phasesByPeriod.getOrDefault(period.getId(), List.of())) {
                periodNodes.addAll(byChapter.getOrDefault(phase.getId(), List.of()));
            }

            List<LearningPathEventNode> periodRequired = periodNodes.stream()
                    .filter(n -> n.getParticipationType() == ParticipationType.REQUIRED)
                    .toList();
            allRequiredNodes.addAll(periodRequired);

            int firstOpen = -1;
            for (int i = 0; i < periodRequired.size(); i++) {
                if (!completedEvents.contains(periodRequired.get(i).getEventId())) {
                    firstOpen = i;
                    break;
                }
            }

            long periodCompletedEvents = 0;
            long periodTotalReqLessons = 0;
            long periodCompletedReqLessons = 0;
            LearnerLearningPathResponse.Current periodCurrent = null;

            for (int i = 0; i < periodNodes.size(); i++) {
                LearningPathEventNode node = periodNodes.get(i);
                Set<UUID> attached = byNode.getOrDefault(node.getId(), List.of()).stream()
                        .map(LearningPathLessonNode::getLessonId)
                        .collect(Collectors.toSet());
                PathContentStatus content = readiness.status(
                        node.getEventId(), attached, policyMap.get(node.getEventId()), lessonMap, snapshots);
                p.contentStatus.put(node.getId(), content);

                boolean done = completedEvents.contains(node.getEventId());
                boolean mastered = masteredEvents.contains(node.getEventId());
                LearnerPathStatus es = mastered
                        ? LearnerPathStatus.MASTERED
                        : done
                                ? LearnerPathStatus.COMPLETED
                                : content != PathContentStatus.PLAYABLE
                                        ? LearnerPathStatus.NOT_READY
                                        : LearnerPathStatus.LOCKED;

                int requiredIndex = periodRequired.indexOf(node);
                if (!done && content == PathContentStatus.PLAYABLE
                        && ((requiredIndex >= 0 && requiredIndex == firstOpen)
                                || (node.getParticipationType() == ParticipationType.EXPLORATION_ONLY
                                        && (firstOpen < 0 || i <= periodNodes.indexOf(periodRequired.get(firstOpen)))))) {
                    es = LearnerPathStatus.AVAILABLE;
                }
                p.eventStatus.put(node.getId(), es);
                if (done && node.getParticipationType() == ParticipationType.REQUIRED) {
                    p.completedEvents++;
                    periodCompletedEvents++;
                }

                EventCompletionPolicy policy = policyMap.get(node.getEventId());
                Set<UUID> requiredLessonIds = policy == null
                        ? Set.of()
                        : new HashSet<>(readiness.policyIds(policy.getRequiredLessonIdsJson()));
                List<UUID> requiredLessons = byNode.getOrDefault(node.getId(), List.of()).stream()
                        .map(LearningPathLessonNode::getLessonId)
                        .filter(requiredLessonIds::contains)
                        .toList();
                int firstLesson = -1;
                for (int x = 0; x < requiredLessons.size(); x++) {
                    if (!completed.contains(requiredLessons.get(x))) {
                        firstLesson = x;
                        break;
                    }
                }
                p.totalRequiredLessons += requiredLessons.size();
                long nodeDoneLessons = requiredLessons.stream().filter(completed::contains).count();
                p.completedRequiredLessons += nodeDoneLessons;
                periodTotalReqLessons += requiredLessons.size();
                periodCompletedReqLessons += nodeDoneLessons;

                UUID openLessonForCurrent = null;
                for (LearningPathLessonNode ln : byNode.getOrDefault(node.getId(), List.of())) {
                    UUID id = ln.getLessonId();
                    LearnerPathStatus ls = completed.contains(id)
                            ? LearnerPathStatus.COMPLETED
                            : inProgressLessons.contains(id)
                                    ? LearnerPathStatus.IN_PROGRESS
                                    : LearnerPathStatus.LOCKED;
                    boolean eventUnlocked = es == LearnerPathStatus.AVAILABLE
                            || es == LearnerPathStatus.IN_PROGRESS
                            || es == LearnerPathStatus.COMPLETED
                            || es == LearnerPathStatus.MASTERED;
                    if (eventUnlocked
                            && (requiredLessons.contains(id)
                                    ? requiredLessons.indexOf(id) == firstLesson
                                    : firstLesson < 0)) {
                        ls = ls == LearnerPathStatus.LOCKED ? LearnerPathStatus.AVAILABLE : ls;
                    }
                    p.lessonStatus.put(id, ls);
                    if (openLessonForCurrent == null
                            && (ls == LearnerPathStatus.AVAILABLE || ls == LearnerPathStatus.IN_PROGRESS)) {
                        openLessonForCurrent = id;
                    }
                }

                if (periodCurrent == null && es == LearnerPathStatus.AVAILABLE) {
                    periodCurrent = new LearnerLearningPathResponse.Current(
                            period.getId(), node.getId(), openLessonForCurrent);
                }
            }

            int percent = periodRequired.isEmpty()
                    ? 0
                    : (int) Math.round((periodCompletedEvents * 100.0) / periodRequired.size());
            p.periodProgress.add(new LearnerLearningPathResponse.PeriodProgress(
                    period.getId(),
                    period.getCode(),
                    period.getTitle(),
                    periodCompletedEvents,
                    periodRequired.size(),
                    periodCompletedReqLessons,
                    periodTotalReqLessons,
                    percent));
            p.currentByPeriod.put(period.getCode(), periodCurrent);
        }

        p.requiredNodes = allRequiredNodes;
        p.allRequiredEventsCompleted = p.completedEvents >= allRequiredNodes.size() && !allRequiredNodes.isEmpty();
        return p;
    }

    private List<LearningPathChapter> orderChaptersTreeFirst(List<LearningPathChapter> all) {
        if (all.isEmpty()) return all;
        boolean hasParent = all.stream().anyMatch(c -> c.getParentId() != null);
        if (!hasParent) return all;

        Comparator<LearningPathChapter> bySort = Comparator
                .comparingInt(LearningPathChapter::getSortOrder)
                .thenComparing(LearningPathChapter::getCode);
        Map<UUID, List<LearningPathChapter>> childrenByParent = new HashMap<>();
        List<LearningPathChapter> roots = new ArrayList<>();
        for (LearningPathChapter c : all) {
            if (c.getParentId() == null) {
                roots.add(c);
            } else {
                childrenByParent.computeIfAbsent(c.getParentId(), k -> new ArrayList<>()).add(c);
            }
        }
        roots.sort(bySort);
        childrenByParent.values().forEach(list -> list.sort(bySort));

        List<LearningPathChapter> ordered = new ArrayList<>(all.size());
        for (LearningPathChapter root : roots) {
            appendSubtree(root, childrenByParent, ordered);
        }
        if (ordered.size() < all.size()) {
            Set<UUID> visited = ordered.stream().map(LearningPathChapter::getId).collect(Collectors.toSet());
            for (LearningPathChapter c : all) {
                if (!visited.contains(c.getId())) ordered.add(c);
            }
        }
        return ordered;
    }

    private void appendSubtree(
            LearningPathChapter current,
            Map<UUID, List<LearningPathChapter>> childrenByParent,
            List<LearningPathChapter> out) {
        out.add(current);
        for (LearningPathChapter child : childrenByParent.getOrDefault(current.getId(), List.of())) {
            appendSubtree(child, childrenByParent, out);
        }
    }

    private static final class Projection {
        final List<LearningPathChapter> chapters;
        final Map<UUID, List<LearningPathEventNode>> byChapter;
        final Map<UUID, List<LearningPathLessonNode>> byNode;
        final Map<UUID, HistoricalEvent> eventMap;
        final Map<UUID, Lesson> lessonMap;
        final Map<UUID, LearnerPathStatus> eventStatus = new HashMap<>();
        final Map<UUID, LearnerPathStatus> lessonStatus = new HashMap<>();
        final Map<UUID, PathContentStatus> contentStatus = new HashMap<>();
        final List<LearnerLearningPathResponse.PeriodProgress> periodProgress = new ArrayList<>();
        final Map<String, LearnerLearningPathResponse.Current> currentByPeriod = new LinkedHashMap<>();
        List<LearningPathChapter> periodChapters = List.of();
        List<LearningPathEventNode> requiredNodes = List.of();
        long completedEvents;
        long totalRequiredLessons;
        long completedRequiredLessons;
        boolean allRequiredEventsCompleted;

        Projection(
                List<LearningPathChapter> c,
                Map<UUID, List<LearningPathEventNode>> bc,
                Map<UUID, List<LearningPathLessonNode>> bn,
                Map<UUID, HistoricalEvent> em,
                Map<UUID, Lesson> lm) {
            chapters = c;
            byChapter = bc;
            byNode = bn;
            eventMap = em;
            lessonMap = lm;
        }
    }
}
