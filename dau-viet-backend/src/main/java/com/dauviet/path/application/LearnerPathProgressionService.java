package com.dauviet.path.application;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;
import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.domain.UserEventProgress;
import com.dauviet.collection.infrastructure.persistence.EventCompletionPolicyRepository;
import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.path.api.dto.LearnerLearningPathResponse;
import com.dauviet.path.domain.*;
import com.dauviet.path.infrastructure.persistence.*;

/** Computes learner access from the pinned path and existing completion ledgers. */
@Service
@Transactional(readOnly = true)
public class LearnerPathProgressionService {
    private final LearningPathVersionRepository versions; private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events; private final LearningPathLessonNodeRepository lessonNodes;
    private final HistoricalEventRepository historicalEvents; private final LessonRepository lessons;
    private final EventCompletionPolicyRepository policies; private final UserEventProgressRepository progress;
    private final LearnerAttemptRepository attempts; private final UserLearningPathEnrollmentRepository enrollments;
    private final PathReadiness readiness; private final EntityManager entityManager;
    public LearnerPathProgressionService(LearningPathVersionRepository versions, LearningPathChapterRepository chapters,
            LearningPathEventNodeRepository events, LearningPathLessonNodeRepository lessonNodes,
            HistoricalEventRepository historicalEvents, LessonRepository lessons, EventCompletionPolicyRepository policies,
            UserEventProgressRepository progress, LearnerAttemptRepository attempts,
            UserLearningPathEnrollmentRepository enrollments, PathReadiness readiness, EntityManager entityManager) {
        this.versions=versions; this.chapters=chapters; this.events=events; this.lessonNodes=lessonNodes;
        this.historicalEvents=historicalEvents; this.lessons=lessons; this.policies=policies; this.progress=progress;
        this.attempts=attempts; this.enrollments=enrollments; this.readiness=readiness; this.entityManager=entityManager;
    }
    @Transactional
    public LearningPathVersion enrolledVersion(UUID userId, String pathCode) {
        String code = pathCode == null || pathCode.isBlank() ? LearningPathService.DEFAULT_PATH_CODE : pathCode.trim();
        entityManager.createNativeQuery("select pg_advisory_xact_lock(hashtextextended(:k, 0::bigint))")
                .setParameter("k", userId + "|" + code).getSingleResult();
        return enrollments.findByIdUserIdAndIdPathCode(userId, code)
                .flatMap(e -> versions.findById(e.getPathVersionId()))
                .orElseGet(() -> {
                    LearningPathVersion published = versions.findByPathCodeAndStatus(code, LearningPathStatus.PUBLISHED)
                            .orElseThrow(() -> new LearningPathExceptions.PathNotFoundException(code));
                    enrollments.saveAndFlush(new UserLearningPathEnrollment(userId, code, published.getId()));
                    return published;
                });
    }
    public LearnerLearningPathResponse pathFor(UUID userId) { return project(userId, enrolledVersion(userId, LearningPathService.DEFAULT_PATH_CODE)); }
    public void requireLessonAvailableForNewAttempt(UUID userId, UUID lessonId) {
        if (attempts.findInProgressByUserIdAndLessonId(userId, lessonId).isPresent()) return;
        Projection projection = load(userId, enrolledVersion(userId, LearningPathService.DEFAULT_PATH_CODE));
        LearnerPathStatus status = projection.lessonStatus.get(lessonId);
        if (status != LearnerPathStatus.AVAILABLE && status != LearnerPathStatus.COMPLETED && status != LearnerPathStatus.MASTERED) {
            throw new LessonLockedByPathException("Lesson is locked by the learner's learning path");
        }
    }
    private LearnerLearningPathResponse project(UUID userId, LearningPathVersion version) {
        Projection p = load(userId, version);
        List<LearnerLearningPathResponse.Chapter> out = new ArrayList<>();
        LearnerLearningPathResponse.Current current = null;
        for (LearningPathChapter chapter : p.chapters) {
            List<LearnerLearningPathResponse.Event> eventOut = new ArrayList<>();
            for (LearningPathEventNode node : p.byChapter.getOrDefault(chapter.getId(), List.of())) {
                HistoricalEvent event = p.eventMap.get(node.getEventId());
                List<LearnerLearningPathResponse.Lesson> lessonOut = new ArrayList<>();
                for (LearningPathLessonNode ln : p.byNode.getOrDefault(node.getId(), List.of())) {
                    Lesson lesson = p.lessonMap.get(ln.getLessonId());
                    LearnerPathStatus lessonStatus = p.lessonStatus.getOrDefault(ln.getLessonId(), LearnerPathStatus.NOT_READY);
                    lessonOut.add(new LearnerLearningPathResponse.Lesson(ln.getLessonId(), lesson == null ? null : lesson.getTitle(), ln.getSortOrder(), lessonStatus));
                }
                LearnerPathStatus eventStatus = p.eventStatus.get(node.getId());
                if (!p.allRequiredEventsCompleted && current == null && eventStatus == LearnerPathStatus.AVAILABLE) {
                    UUID lessonId = lessonOut.stream().filter(l -> l.status() == LearnerPathStatus.AVAILABLE).map(LearnerLearningPathResponse.Lesson::lessonId).findFirst().orElse(null);
                    current = new LearnerLearningPathResponse.Current(chapter.getId(), node.getId(), lessonId);
                }
                eventOut.add(new LearnerLearningPathResponse.Event(node.getId(), node.getEventId(), event == null ? null : event.getTitle(),
                        event == null ? null : YearLabelFormatter.formatYear(event.getStartYear(), event.getPeriod()), node.getSortOrder(), node.getParticipationType(),
                        eventStatus, p.contentStatus.get(node.getId()), lessonOut));
            }
            out.add(new LearnerLearningPathResponse.Chapter(chapter.getId(), chapter.getCode(), chapter.getTitle(), chapter.getSortOrder(), eventOut));
        }
        return new LearnerLearningPathResponse(version.getPathCode(), version.getVersionNo(), true,
                new LearnerLearningPathResponse.Summary(p.completedEvents, p.requiredNodes.size(), p.completedRequiredLessons, p.totalRequiredLessons), current, out);
    }
    private Projection load(UUID userId, LearningPathVersion version) {
        List<LearningPathChapter> chapterList = chapters.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<LearningPathEventNode> nodeList = events.findByPathVersionIdOrderBySortOrderAsc(version.getId());
        List<UUID> nodeIds = nodeList.stream().map(LearningPathEventNode::getId).toList();
        List<LearningPathLessonNode> nodeLessons = nodeIds.isEmpty()?List.of():lessonNodes.findByEventNodeIdInOrderBySortOrderAsc(nodeIds);
        Map<UUID, HistoricalEvent> eventMap = historicalEvents.findAllById(nodeList.stream().map(LearningPathEventNode::getEventId).toList()).stream().collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));
        Map<UUID, Lesson> lessonMap = lessons.findAllById(nodeLessons.stream().map(LearningPathLessonNode::getLessonId).toList()).stream().collect(Collectors.toMap(Lesson::getId, Function.identity()));
        Map<UUID, EventCompletionPolicy> policyMap = nodeList.isEmpty()?Map.of():policies.findPublishedByEventIdIn(eventMap.keySet()).stream().collect(Collectors.toMap(EventCompletionPolicy::getEventId, Function.identity()));
        readiness.includePolicyLessons(lessonMap, policyMap.values(), lessons);
        Map<UUID, LessonVersion> snapshots = readiness.snapshots(lessonMap.values());
        Map<UUID,List<LearningPathEventNode>> byChapter=nodeList.stream().collect(Collectors.groupingBy(LearningPathEventNode::getChapterId));
        Map<UUID,List<LearningPathLessonNode>> byNode=nodeLessons.stream().collect(Collectors.groupingBy(LearningPathLessonNode::getEventNodeId));
        Set<UUID> completed = attempts.findDistinctCompletedLessonIds(userId);
        Set<UUID> inProgressLessons = attempts.findDistinctInProgressLessonIds(userId);
        Set<UUID> pathEventIds = nodeList.stream().map(LearningPathEventNode::getEventId).collect(Collectors.toSet());
        Set<UUID> completedEvents = pathEventIds.isEmpty() ? Set.of()
                : progress.findEventIdsByUserAndMilestoneAndEventIdIn(userId, UserEventProgress.Milestone.EVENT_COMPLETED.name(), pathEventIds);
        Set<UUID> masteredEvents = pathEventIds.isEmpty() ? Set.of()
                : progress.findEventIdsByUserAndMilestoneAndEventIdIn(userId, UserEventProgress.Milestone.EVENT_MASTERED.name(), pathEventIds);
        Projection p=new Projection(chapterList,byChapter,byNode,eventMap,lessonMap);
        List<LearningPathEventNode> orderedNodes = chapterList.stream()
                .flatMap(chapter -> byChapter.getOrDefault(chapter.getId(), List.of()).stream()).toList();
        List<LearningPathEventNode> required = orderedNodes.stream().filter(n->n.getParticipationType()==ParticipationType.REQUIRED).toList(); p.requiredNodes=required;
        int firstOpen=-1;
        for(int i=0;i<required.size();i++) if(!completedEvents.contains(required.get(i).getEventId())) { firstOpen=i; break; }
        p.allRequiredEventsCompleted = firstOpen < 0;
        for(int i=0;i<orderedNodes.size();i++) { LearningPathEventNode node=orderedNodes.get(i); Set<UUID> attached=byNode.getOrDefault(node.getId(),List.of()).stream().map(LearningPathLessonNode::getLessonId).collect(Collectors.toSet());
            PathContentStatus content=readiness.status(node.getEventId(),attached,policyMap.get(node.getEventId()),lessonMap,snapshots); p.contentStatus.put(node.getId(),content);
            boolean done=completedEvents.contains(node.getEventId());
            boolean mastered=masteredEvents.contains(node.getEventId());
            LearnerPathStatus es= mastered?LearnerPathStatus.MASTERED : done?LearnerPathStatus.COMPLETED : content!=PathContentStatus.PLAYABLE?LearnerPathStatus.NOT_READY:LearnerPathStatus.LOCKED;
            int requiredIndex=required.indexOf(node);
            if(!done && content==PathContentStatus.PLAYABLE && ((requiredIndex>=0 && requiredIndex==firstOpen) || (node.getParticipationType()==ParticipationType.EXPLORATION_ONLY && (firstOpen<0 || i<=orderedNodes.indexOf(required.get(firstOpen)))))) es=LearnerPathStatus.AVAILABLE;
            p.eventStatus.put(node.getId(),es); if(done && node.getParticipationType()==ParticipationType.REQUIRED)p.completedEvents++;
            EventCompletionPolicy policy=policyMap.get(node.getEventId()); Set<UUID> requiredLessonIds=policy==null?Set.of():new HashSet<>(readiness.policyIds(policy.getRequiredLessonIdsJson()));
            List<UUID> requiredLessons=byNode.getOrDefault(node.getId(),List.of()).stream().map(LearningPathLessonNode::getLessonId).filter(requiredLessonIds::contains).toList();
            int firstLesson=-1; for(int x=0;x<requiredLessons.size();x++) if(!completed.contains(requiredLessons.get(x))){firstLesson=x;break;}
            p.totalRequiredLessons+=requiredLessons.size(); p.completedRequiredLessons+=requiredLessons.stream().filter(completed::contains).count();
            for(LearningPathLessonNode ln:byNode.getOrDefault(node.getId(),List.of())) { UUID id=ln.getLessonId(); LearnerPathStatus ls=completed.contains(id)?LearnerPathStatus.COMPLETED:inProgressLessons.contains(id)?LearnerPathStatus.IN_PROGRESS:LearnerPathStatus.LOCKED;
                if(es==LearnerPathStatus.AVAILABLE && (requiredLessons.contains(id)?requiredLessons.indexOf(id)==firstLesson:true)) ls= ls==LearnerPathStatus.LOCKED?LearnerPathStatus.AVAILABLE:ls;
                p.lessonStatus.put(id,ls); }
        }
        return p;
    }
    private static final class Projection { final List<LearningPathChapter> chapters; final Map<UUID,List<LearningPathEventNode>> byChapter; final Map<UUID,List<LearningPathLessonNode>> byNode; final Map<UUID,HistoricalEvent> eventMap; final Map<UUID,Lesson> lessonMap; final Map<UUID,LearnerPathStatus> eventStatus=new HashMap<>(),lessonStatus=new HashMap<>(); final Map<UUID,PathContentStatus> contentStatus=new HashMap<>(); List<LearningPathEventNode> requiredNodes=List.of(); long completedEvents,totalRequiredLessons,completedRequiredLessons; boolean allRequiredEventsCompleted; Projection(List<LearningPathChapter> c,Map<UUID,List<LearningPathEventNode>> bc,Map<UUID,List<LearningPathLessonNode>> bn,Map<UUID,HistoricalEvent> em,Map<UUID,Lesson> lm){chapters=c;byChapter=bc;byNode=bn;eventMap=em;lessonMap=lm;} }
}
