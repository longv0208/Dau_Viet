package com.dauviet.path.application;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Function;
import java.util.function.ObjIntConsumer;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.*;
import com.dauviet.path.domain.*;
import com.dauviet.path.infrastructure.persistence.*;

@Service
@Transactional
public class AdminPathOrderService {
    private final AdminPathAccess access;
    private final AdminPathReadService read;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;
    private final LearningPathLessonNodeRepository lessons;

    public AdminPathOrderService(AdminPathAccess access, AdminPathReadService read,
            LearningPathChapterRepository chapters, LearningPathEventNodeRepository events,
            LearningPathLessonNodeRepository lessons) {
        this.access = access; this.read = read; this.chapters = chapters; this.events = events; this.lessons = lessons;
    }

    public AdminPathResponse chapters(UUID versionId, AdminPathRequests.ChaptersOrder request) {
        access.draft(versionId, request.expectedRevision());
        access.deferSortConstraints();
        List<LearningPathChapter> allInVersion = chapters.findByPathVersionIdOrderBySortOrderAsc(versionId);
        List<LearningPathChapter> scope = allInVersion;
        if (request.parentId() != null) {
            scope = allInVersion.stream().filter(c -> Objects.equals(c.getParentId(), request.parentId())).toList();
        } else if (request.chapterIds() != null && request.chapterIds().size() < allInVersion.size() && !request.chapterIds().isEmpty()) {
            UUID firstId = request.chapterIds().get(0);
            LearningPathChapter first = allInVersion.stream().filter(c -> c.getId().equals(firstId)).findFirst().orElse(null);
            if (first != null) {
                UUID inferredParent = first.getParentId();
                scope = allInVersion.stream().filter(c -> Objects.equals(c.getParentId(), inferredParent)).toList();
            }
        }
        reorder(request.chapterIds(), scope, LearningPathChapter::getId, LearningPathChapter::setSortOrder);
        chapters.flush();
        return read.detail(versionId);
    }

    public AdminPathResponse events(UUID versionId, UUID chapterId, AdminPathRequests.EventsOrder request) {
        access.draft(versionId, request.expectedRevision());
        access.chapter(versionId, chapterId);
        access.deferSortConstraints();
        reorder(request.eventNodeIds(), events.findByChapterIdOrderBySortOrderAsc(chapterId),
                LearningPathEventNode::getId, LearningPathEventNode::setSortOrder);
        events.flush();
        return read.detail(versionId);
    }

    public AdminPathResponse lessons(UUID versionId, UUID eventNodeId, AdminPathRequests.LessonsOrder request) {
        access.draft(versionId, request.expectedRevision());
        access.event(versionId, eventNodeId);
        access.deferSortConstraints();
        reorder(request.lessonNodeIds(), lessons.findByEventNodeIdOrderBySortOrderAsc(eventNodeId),
                LearningPathLessonNode::getId, LearningPathLessonNode::setSortOrder);
        lessons.flush();
        return read.detail(versionId);
    }

    private static <T> void reorder(List<UUID> ids, List<T> current, Function<T, UUID> identity,
                                    ObjIntConsumer<T> setOrder) {
        Map<UUID, T> nodes = current.stream().collect(Collectors.toMap(identity, Function.identity()));
        AdminPathAccess.require(ids != null && !ids.contains(null) && ids.size() == nodes.size()
                        && new HashSet<>(ids).size() == ids.size() && nodes.keySet().equals(new HashSet<>(ids)),
                "Reorder must contain every node in this scope exactly once");
        for (int i = 0; i < ids.size(); i++) setOrder.accept(nodes.get(ids.get(i)), i + 1);
    }
}
