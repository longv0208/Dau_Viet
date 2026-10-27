package com.dauviet.path.application;

import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.*;
import com.dauviet.path.domain.*;
import com.dauviet.path.infrastructure.persistence.*;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;

@Service
@Transactional
public class AdminPathEventService {
    private final AdminPathAccess access;
    private final AdminPathReadService read;
    private final LearningPathEventNodeRepository events;
    private final LearningPathLessonNodeRepository lessons;
    private final HistoricalEventRepository historicalEvents;
    private final LearningPathValidator validator;
    private final PathHierarchyValidator hierarchyValidator;

    public AdminPathEventService(AdminPathAccess access, AdminPathReadService read,
            LearningPathEventNodeRepository events, LearningPathLessonNodeRepository lessons,
            HistoricalEventRepository historicalEvents, LearningPathValidator validator,
            PathHierarchyValidator hierarchyValidator) {
        this.access = access;
        this.read = read;
        this.events = events;
        this.lessons = lessons;
        this.historicalEvents = historicalEvents;
        this.validator = validator;
        this.hierarchyValidator = hierarchyValidator;
    }

    public AdminPathResponse add(UUID versionId, UUID chapterId, AdminPathRequests.Event request) {
        access.draft(versionId, request.expectedRevision());
        var chapter = access.chapter(versionId, chapterId);
        hierarchyValidator.validateEventAttachmentChapter(chapter);
        var event = historicalEvents.findById(request.eventId()).orElseThrow(() ->
                new LearningPathExceptions.PathNotFoundException("event " + request.eventId()));
        AdminPathAccess.require(event.getStatus() != EventStatus.ARCHIVED, "Archived events cannot be added to a path");
        validator.assertCanonicalUnique(versionId, request.eventId());
        int order = events.findByChapterIdOrderBySortOrderAsc(chapterId).stream()
                .mapToInt(LearningPathEventNode::getSortOrder).max().orElse(0) + 1;
        var node = new LearningPathEventNode(null, chapterId, versionId, request.eventId(), order);
        node.setParticipationType(request.participationType());
        events.saveAndFlush(node);
        return read.detail(versionId);
    }

    public AdminPathResponse patch(UUID versionId, UUID id, AdminPathRequests.EventPatch request) {
        access.draft(versionId, request.expectedRevision());
        var node = access.event(versionId, id);
        if (request.chapterId() != null && !request.chapterId().equals(node.getChapterId())) {
            var targetChapter = access.chapter(versionId, request.chapterId());
            hierarchyValidator.validateEventAttachmentChapter(targetChapter);
            UUID oldChapter = node.getChapterId();
            int order = events.findByChapterIdOrderBySortOrderAsc(request.chapterId()).stream()
                    .mapToInt(LearningPathEventNode::getSortOrder).max().orElse(0) + 1;
            access.deferSortConstraints();
            node.moveToChapter(request.chapterId());
            node.setSortOrder(order);
            events.flush();
            normalize(oldChapter);
        }
        if (request.participationType() != null) node.setParticipationType(request.participationType());
        events.flush();
        return read.detail(versionId);
    }

    public AdminPathResponse delete(UUID versionId, UUID id, Long revision) {
        access.draft(versionId, revision);
        var node = access.event(versionId, id);
        lessons.deleteAll(lessons.findByEventNodeIdOrderBySortOrderAsc(id));
        lessons.flush();
        events.delete(node);
        events.flush();
        access.deferSortConstraints();
        normalize(node.getChapterId());
        return read.detail(versionId);
    }

    private void normalize(UUID chapterId) {
        var remaining = events.findByChapterIdOrderBySortOrderAsc(chapterId);
        for (int i = 0; i < remaining.size(); i++) remaining.get(i).setSortOrder(i + 1);
        events.flush();
    }
}
