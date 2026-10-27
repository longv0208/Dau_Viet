package com.dauviet.path.application;

import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.*;
import com.dauviet.path.domain.*;
import com.dauviet.path.infrastructure.persistence.LearningPathLessonNodeRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;

@Service
@Transactional
public class AdminPathLessonService {
    private final AdminPathAccess access;
    private final AdminPathReadService read;
    private final LearningPathLessonNodeRepository lessons;
    private final LessonRepository lessonRepository;

    public AdminPathLessonService(AdminPathAccess access, AdminPathReadService read,
            LearningPathLessonNodeRepository lessons, LessonRepository lessonRepository) {
        this.access = access; this.read = read; this.lessons = lessons;
        this.lessonRepository = lessonRepository;
    }

    public AdminPathResponse add(UUID versionId, UUID eventNodeId, AdminPathRequests.Lesson request) {
        access.draft(versionId, request.expectedRevision());
        var event = access.event(versionId, eventNodeId);
        var lesson = lessonRepository.findById(request.lessonId()).orElseThrow(() ->
                new LearningPathExceptions.PathNotFoundException("lesson " + request.lessonId()));
        AdminPathAccess.require(lesson.getEventId().equals(event.getEventId()), "Lesson belongs to a different event");
        AdminPathAccess.require(lessons.findByEventNodeIdAndLessonId(eventNodeId, request.lessonId()).isEmpty(),
                "Lesson is already attached to this event node");
        int order = lessons.findByEventNodeIdOrderBySortOrderAsc(eventNodeId).stream()
                .mapToInt(LearningPathLessonNode::getSortOrder).max().orElse(0) + 1;
        lessons.saveAndFlush(new LearningPathLessonNode(null, eventNodeId, event.getEventId(), request.lessonId(), order));
        return read.detail(versionId);
    }

    public AdminPathResponse delete(UUID versionId, UUID eventNodeId, UUID id, Long revision) {
        access.draft(versionId, revision);
        access.event(versionId, eventNodeId);
        var node = lessons.findById(id).orElseThrow(() ->
                new LearningPathExceptions.PathNotFoundException("lesson node " + id));
        AdminPathAccess.require(eventNodeId.equals(node.getEventNodeId()), "Lesson node belongs to another event node");
        lessons.delete(node);
        lessons.flush();
        access.deferSortConstraints();
        var remaining = lessons.findByEventNodeIdOrderBySortOrderAsc(eventNodeId);
        for (int i = 0; i < remaining.size(); i++) remaining.get(i).setSortOrder(i + 1);
        lessons.flush();
        return read.detail(versionId);
    }
}
