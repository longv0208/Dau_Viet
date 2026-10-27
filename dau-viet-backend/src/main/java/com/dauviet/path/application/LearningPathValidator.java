package com.dauviet.path.application;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.api.dto.PathAuditReport;
import com.dauviet.path.api.dto.PathAuditReport.AuditIssue;
import com.dauviet.path.api.dto.PathAuditReport.DuplicateAliasReport;
import com.dauviet.path.domain.*;
import com.dauviet.path.domain.LearningPathExceptions.PathNotFoundException;
import com.dauviet.path.domain.LearningPathExceptions.PathValidationException;
import com.dauviet.path.infrastructure.persistence.*;

@Component
@Transactional(readOnly = true)
public class LearningPathValidator {
    private final LearningPathVersionRepository versions;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository nodes;
    private final LearningPathLessonNodeRepository lessonNodes;
    private final HistoricalEventRepository events;
    private final LessonRepository lessons;
    private final EventCompletionPolicyRepository policies;
    private final PathEventIdentity identities;
    private final PathReadiness readiness;

    public LearningPathValidator(LearningPathVersionRepository versions, LearningPathChapterRepository chapters,
            LearningPathEventNodeRepository nodes, LearningPathLessonNodeRepository lessonNodes,
            HistoricalEventRepository events, LessonRepository lessons,
            EventCompletionPolicyRepository policies, PathEventIdentity identities, PathReadiness readiness) {
        this.versions = versions; this.chapters = chapters; this.nodes = nodes; this.lessonNodes = lessonNodes;
        this.events = events; this.lessons = lessons; this.policies = policies;
        this.identities = identities; this.readiness = readiness;
    }

    public PathAuditReport audit(String pathCode, Integer versionNo) {
        pathCode = pathCode == null || pathCode.isBlank() ? LearningPathService.DEFAULT_PATH_CODE : pathCode.trim();
        String code = pathCode;
        LearningPathVersion version = (versionNo == null
                ? versions.findByPathCodeAndStatus(pathCode, LearningPathStatus.PUBLISHED)
                : versions.findByPathCodeAndVersionNo(pathCode, versionNo))
                .orElseThrow(() -> new PathNotFoundException(code));
        return audit(version);
    }

    public PathAuditReport audit(UUID versionId) {
        return audit(versions.findById(versionId).orElseThrow(() -> new PathNotFoundException(versionId.toString())));
    }

    private PathAuditReport audit(LearningPathVersion version) {
        List<LearningPathChapter> chapterList = chapters.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<LearningPathEventNode> nodeList = nodes.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<UUID> nodeIds = nodeList.stream().map(LearningPathEventNode::getId).toList();
        List<LearningPathLessonNode> lessonList = nodeIds.isEmpty() ? List.of() : lessonNodes.findByEventNodeIdInOrderBySortOrderAsc(nodeIds);
        Map<UUID, HistoricalEvent> eventMap = events.findAllById(nodeList.stream().map(LearningPathEventNode::getEventId).toList())
                .stream().collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));
        Map<UUID, Lesson> lessonMap = lessons.findAllById(lessonList.stream().map(LearningPathLessonNode::getLessonId).toList())
                .stream().collect(Collectors.toMap(Lesson::getId, Function.identity()));
        Map<UUID, EventCompletionPolicy> policyMap = eventMap.isEmpty() ? Map.of() : policies.findPublishedByEventIdIn(eventMap.keySet())
                .stream().collect(Collectors.toMap(EventCompletionPolicy::getEventId, Function.identity()));
        readiness.includePolicyLessons(lessonMap, policyMap.values(), lessons);
        Map<UUID, LessonVersion> snapshots = readiness.snapshots(lessonMap.values());
        Map<UUID, UUID> aliases = identities.aliases();
        List<AuditIssue> issues = new ArrayList<>();
        List<DuplicateAliasReport> duplicates = new ArrayList<>();
        List<String> empty = new ArrayList<>();
        Map<String, Long> counts = new HashMap<>();
        Set<Integer> chapterSorts = new HashSet<>();
        Set<String> chapterCodes = new HashSet<>();
        Set<UUID> seenCanonical = new HashSet<>();
        Set<UUID> seenEvents = new HashSet<>();
        Set<UUID> seenLessons = new HashSet<>();
        Integer previousChapterYear = null;
        Integer previousEventYear = null;
        if (chapterList.isEmpty()) issue(issues, "ERROR", "EMPTY_PATH", "Path must contain at least one chapter", version.getId());
        if (version.getStatus() == LearningPathStatus.DRAFT && LearningPathService.DEFAULT_PATH_CODE.equals(version.getPathCode())
                && nodeList.stream().noneMatch(node -> node.getParticipationType() == ParticipationType.REQUIRED)) {
            issue(issues, "ERROR", "NO_REQUIRED_EVENT", "A new main learning path must contain at least one REQUIRED event", version.getId());
        }
        for (LearningPathChapter chapter : chapterList) {
            checkSort(issues, chapterSorts, chapter.getSortOrder(), chapter.getId(), "CHAPTER");
            if (!chapterCodes.add(chapter.getCode())) issue(issues, "ERROR", "DUPLICATE_CHAPTER_CODE", "Chapter code is repeated", chapter.getId());
            if (chapter.getStartYear() > chapter.getEndYear()) issue(issues, "ERROR", "INVALID_CHAPTER_YEARS", "startYear " + chapter.getStartYear() + " > endYear " + chapter.getEndYear(), chapter.getId());
            if (previousChapterYear != null && chapter.getStartYear() < previousChapterYear) issue(issues, "WARNING", "CHAPTER_CHRONOLOGY", "Chapter dates go backwards in admin order", chapter.getId());
            previousChapterYear = chapter.getStartYear();
            List<LearningPathEventNode> inChapter = nodeList.stream().filter(n -> chapter.getId().equals(n.getChapterId())).toList();
            if (inChapter.isEmpty()) { empty.add(chapter.getCode()); issue(issues, "WARNING", "EMPTY_CHAPTER", "Chapter has no events", chapter.getId()); }
            Set<Integer> eventSorts = new HashSet<>();
            for (LearningPathEventNode node : inChapter) {
                checkSort(issues, eventSorts, node.getSortOrder(), node.getId(), "EVENT");
                if (!seenEvents.add(node.getEventId())) issue(issues, "ERROR", "DUPLICATE_EVENT_IN_PATH", "Event is repeated", node.getId());
                UUID canonical = identities.canonical(node.getEventId(), aliases);
                if (!canonical.equals(node.getEventId())) issue(issues, "WARNING", "CANONICAL_ALIAS", "Selected event is an alias of historical event " + canonical, node.getId());
                if (!seenCanonical.add(canonical)) {
                    issue(issues, "ERROR", "DUPLICATE_HISTORICAL_ALIAS", "Canonical event occurs more than once", node.getId());
                    duplicates.add(new DuplicateAliasReport(null, canonical, null, node.getEventId(), "Duplicate canonical historical identity"));
                }
                HistoricalEvent event = eventMap.get(node.getEventId());
                if (event == null || event.getStatus() != EventStatus.PUBLISHED) issue(issues, "ERROR", "UNPUBLISHED_EVENT_IN_PATH", "Event is missing, archived or unpublished", node.getId());
                if (event != null && event.getStartYear() != null) {
                    if (event.getStartYear() == 0 || event.getStartYear() == Integer.MIN_VALUE) issue(issues, "ERROR", "INVALID_EVENT_YEAR", "Event year cannot be rendered as a historical year", node.getId());
                    if (previousEventYear != null && event.getStartYear() < previousEventYear) issue(issues, "WARNING", "EVENT_CHRONOLOGY", "Event dates go backwards in admin order", node.getId());
                    previousEventYear = event.getStartYear();
                    if (event.getStartYear() < chapter.getStartYear() || event.getStartYear() > chapter.getEndYear()) issue(issues, "WARNING", "EVENT_OUTSIDE_CHAPTER", "Event year is outside chapter dates", node.getId());
                }
                Set<Integer> lessonSorts = new HashSet<>();
                Set<UUID> attached = new HashSet<>();
                for (LearningPathLessonNode child : lessonList.stream().filter(l -> node.getId().equals(l.getEventNodeId())).toList()) {
                    checkSort(issues, lessonSorts, child.getSortOrder(), child.getId(), "LESSON");
                    if (!attached.add(child.getLessonId()) || !seenLessons.add(child.getLessonId())) issue(issues, "ERROR", "DUPLICATE_LESSON_IN_PATH", "Lesson is repeated", child.getId());
                    Lesson lesson = lessonMap.get(child.getLessonId());
                    if (lesson == null || !node.getEventId().equals(lesson.getEventId()) || !node.getEventId().equals(child.getEventId())) issue(issues, "ERROR", "LESSON_EVENT_MISMATCH", "Lesson must belong to its event", child.getId());
                    else if (!readiness.published(lesson, snapshots)) issue(issues, "WARNING", "UNPUBLISHED_OR_UNPINNED_LESSON", "Attached lesson has no published version", child.getId());
                }
                PathContentStatus status = readiness.status(node.getEventId(), attached, policyMap.get(node.getEventId()), lessonMap, snapshots);
                counts.merge(status.name(), 1L, Long::sum);
                if (status != PathContentStatus.PLAYABLE) issue(issues, node.getParticipationType() == ParticipationType.REQUIRED ? "ERROR" : "WARNING",
                        status.name(), "Event is not ready for required participation: " + status, node.getId());
            }
        }
        if (seenEvents.size() != nodeList.size()) issue(issues, "ERROR", "INVALID_EVENT_SCOPE", "Event nodes are duplicated or outside the version's chapters", version.getId());
        return new PathAuditReport(version.getPathCode(), version.getVersionNo(), version.getStatus().name(), chapterList.size(), nodeList.size(), lessonList.size(), counts, issues, duplicates, empty);
    }

    public PathContentStatus contentStatus(UUID nodeId) {
        LearningPathEventNode node = nodes.findById(nodeId).orElseThrow(() -> new PathNotFoundException(nodeId.toString()));
        HistoricalEvent event = events.findById(node.getEventId()).orElse(null);
        if (event == null || event.getStatus() != EventStatus.PUBLISHED) return PathContentStatus.CONTENT_REVIEW_REQUIRED;
        Set<UUID> attached = lessonNodes.findByEventNodeIdOrderBySortOrderAsc(nodeId).stream().map(LearningPathLessonNode::getLessonId).collect(Collectors.toSet());
        Map<UUID, Lesson> map = lessons.findAllById(attached).stream().collect(Collectors.toMap(Lesson::getId, Function.identity()));
        EventCompletionPolicy policy = policies.findPublishedByEventIdIn(List.of(node.getEventId())).stream().findFirst().orElse(null);
        readiness.includePolicyLessons(map, policy == null ? List.of() : List.of(policy), lessons);
        return readiness.status(node.getEventId(), attached, policy, map, readiness.snapshots(map.values()));
    }

    public void assertRequiredReady(UUID nodeId) {
        PathContentStatus status = contentStatus(nodeId);
        if (status != PathContentStatus.PLAYABLE) throw new PathValidationException(List.of("Required event is not ready: " + status));
    }

    public void assertCanonicalUnique(UUID versionId, UUID eventId) {
        Map<UUID, UUID> aliases = identities.aliases();
        UUID canonical = identities.canonical(eventId, aliases);
        if (nodes.findByPathVersionIdOrderBySortOrderAsc(versionId).stream().anyMatch(n -> canonical.equals(identities.canonical(n.getEventId(), aliases)))) {
            throw new PathValidationException(List.of("Canonical historical event already appears in this version"));
        }
    }

    public void validateForPublish(String code, int versionNo) {
        List<String> errors = audit(code, versionNo).issues().stream().filter(i -> "ERROR".equals(i.level())).map(AuditIssue::message).toList();
        if (!errors.isEmpty()) throw new PathValidationException(errors);
    }

    private void checkSort(List<AuditIssue> issues, Set<Integer> seen, int sort, UUID id, String kind) {
        if (sort < 1 || !seen.add(sort)) issue(issues, "ERROR", "INVALID_" + kind + "_SORT", "Sort order must be positive and unique in its scope", id);
    }

    private void issue(List<AuditIssue> issues, String level, String code, String message, UUID id) {
        issues.add(new AuditIssue(level, code, message, id));
    }
}
