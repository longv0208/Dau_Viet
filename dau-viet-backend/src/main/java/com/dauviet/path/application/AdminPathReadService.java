package com.dauviet.path.application;

import java.util.List;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.AdminPathResponse;
import com.dauviet.path.domain.*;
import com.dauviet.path.infrastructure.persistence.*;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.lesson.domain.SnapshotCorruptException;

@Service
@Transactional(readOnly = true)
public class AdminPathReadService {
    private final AdminPathAccess access;
    private final LearningPathVersionRepository versions;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;
    private final LearningPathLessonNodeRepository lessons;
    private final HistoricalEventRepository historicalEvents;
    private final LessonRepository lessonRepository;
    private final LearningPathValidator validator;
    private final EventCompletionPolicyRepository policies;
    private final PathReadiness readiness;
    private final PathEventIdentity identities;

    public AdminPathReadService(AdminPathAccess access, LearningPathVersionRepository versions,
            LearningPathChapterRepository chapters, LearningPathEventNodeRepository events,
            LearningPathLessonNodeRepository lessons, HistoricalEventRepository historicalEvents,
            LessonRepository lessonRepository, LearningPathValidator validator,
            EventCompletionPolicyRepository policies, PathReadiness readiness, PathEventIdentity identities) {
        this.access = access; this.versions = versions; this.chapters = chapters; this.events = events;
        this.lessons = lessons; this.historicalEvents = historicalEvents;
        this.lessonRepository = lessonRepository; this.validator = validator;
        this.policies = policies; this.readiness = readiness;
        this.identities = identities;
    }

    public List<LearningPathVersion> list(String code) {
        String effectiveCode = code == null || code.isBlank() ? LearningPathService.DEFAULT_PATH_CODE : code.trim();
        return versions.findByPathCodeOrderByVersionNoDesc(effectiveCode);
    }

    public AdminPathResponse detail(UUID id) {
        LearningPathVersion version = access.version(id);
        var chapterList = chapters.findByPathVersionIdOrderBySortOrderAsc(id);
        var eventList = events.findByPathVersionIdOrderBySortOrderAsc(id);
        var lessonList = eventList.isEmpty() ? List.<LearningPathLessonNode>of()
                : lessons.findByEventNodeIdInOrderBySortOrderAsc(eventList.stream().map(LearningPathEventNode::getId).toList());
        var eventData = historicalEvents.findAllById(eventList.stream().map(LearningPathEventNode::getEventId).toList())
                .stream().collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));
        var lessonData = lessonRepository.findAllById(lessonList.stream().map(LearningPathLessonNode::getLessonId).toList())
                .stream().collect(Collectors.toMap(Lesson::getId, Function.identity()));
        var byChapter = eventList.stream().collect(Collectors.groupingBy(LearningPathEventNode::getChapterId));
        var byEvent = lessonList.stream().collect(Collectors.groupingBy(LearningPathLessonNode::getEventNodeId));
        var publishedPolicies = eventList.isEmpty() ? java.util.Map.<UUID, EventCompletionPolicy>of()
                : policies.findPublishedByEventIdIn(eventData.keySet()).stream()
                    .collect(Collectors.toMap(EventCompletionPolicy::getEventId, Function.identity()));
        readiness.includePolicyLessons(lessonData, publishedPolicies.values(), lessonRepository);
        var snapshots = readiness.snapshots(lessonData.values());
        var aliases = identities.aliases();
        return new AdminPathResponse(version, chapterList.stream().map(c -> new AdminPathResponse.Chapter(c,
                byChapter.getOrDefault(c.getId(), List.of()).stream().map(e -> {
                    HistoricalEvent data = eventData.get(e.getEventId());
                    var policy = publishedPolicies.get(e.getEventId());
                    var attached = byEvent.getOrDefault(e.getId(), List.of()).stream()
                            .map(LearningPathLessonNode::getLessonId).collect(Collectors.toSet());
                    PathContentStatus status = data == null || data.getStatus() != EventStatus.PUBLISHED
                            ? PathContentStatus.CONTENT_REVIEW_REQUIRED
                            : readiness.status(e.getEventId(), attached, policy, lessonData, snapshots);
                    return new AdminPathResponse.Event(e, data == null ? null : data.getTitle(),
                            data == null ? null : data.getStartYear(), status,
                            policy == null ? null : policy.getId(), policy == null ? null : policy.getPolicyVersion(),
                            policyLessons(policy, true), policyLessons(policy, false),
                            byEvent.getOrDefault(e.getId(), List.of()).stream().map(l -> {
                                Lesson lesson = lessonData.get(l.getLessonId());
                                return new AdminPathResponse.Lesson(l, lesson == null ? null : lesson.getTitle(),
                                        lesson == null ? "MISSING" : lesson.getStatus().name());
                            }).toList(), data == null ? "MISSING" : data.getStatus().name(),
                            identities.canonical(e.getEventId(), aliases), aliases.containsKey(e.getEventId()));
                }).toList())).toList());
    }

    public com.dauviet.path.api.dto.PathAuditReport validate(UUID id) {
        var version = access.version(id);
        return validator.audit(version.getPathCode(), version.getVersionNo());
    }

    private List<UUID> policyLessons(EventCompletionPolicy policy, boolean required) {
        if (policy == null) return null;
        try {
            return readiness.policyIds(required ? policy.getRequiredLessonIdsJson() : policy.getOptionalLessonIdsJson());
        } catch (SnapshotCorruptException ex) {
            // Null signals an unreadable policy; contentStatus explicitly reports its readiness failure.
            return null;
        }
    }
}
