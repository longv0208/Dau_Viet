package com.dauviet.path.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.AdminPathRequests;
import com.dauviet.path.api.dto.AdminPathResponse;
import com.dauviet.path.domain.*;
import com.dauviet.path.infrastructure.persistence.*;

@Service
@Transactional
public class AdminPathVersionService {
    private final AdminPathAccess access;
    private final AdminPathReadService read;
    private final LearningPathVersionRepository versions;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;
    private final LearningPathLessonNodeRepository lessons;
    private final LearningPathValidator validator;

    public AdminPathVersionService(AdminPathAccess access, AdminPathReadService read,
            LearningPathVersionRepository versions, LearningPathChapterRepository chapters,
            LearningPathEventNodeRepository events, LearningPathLessonNodeRepository lessons,
            LearningPathValidator validator) {
        this.access = access; this.read = read; this.versions = versions; this.chapters = chapters;
        this.events = events; this.lessons = lessons; this.validator = validator;
    }

    public AdminPathResponse create(AdminPathRequests.Draft request) {
        String code = request.pathCode().trim();
        access.lockPath(code);
        var version = newDraft(code, request.title(), request.description());
        return read.detail(version.getId());
    }

    public AdminPathResponse clonePublished(UUID sourceId) {
        var source = access.version(sourceId);
        access.lockPath(source.getPathCode());
        // Refresh status after obtaining the path lock: another publisher may have archived it.
        source = versions.findLockedById(sourceId).orElseThrow();
        access.refresh(source);
        AdminPathAccess.require(source.getStatus() == LearningPathStatus.PUBLISHED,
                "Clone source must be the current PUBLISHED version");
        var target = newDraft(source.getPathCode(), source.getTitle(), source.getDescription());
        access.deferSortConstraints();
        var chapterIds = new HashMap<UUID, UUID>();
        var sourceChapters = chapters.findByPathVersionIdOrderBySortOrderAsc(sourceId);
        for (var chapter : sourceChapters) {
            chapterIds.put(chapter.getId(), UUID.randomUUID());
        }
        var remaining = new ArrayList<>(sourceChapters);
        var insertedSourceIds = new HashSet<UUID>();
        while (!remaining.isEmpty()) {
            boolean progressed = false;
            var iterator = remaining.iterator();
            while (iterator.hasNext()) {
                var chapter = iterator.next();
                UUID srcParentId = chapter.getParentId();
                if (srcParentId == null || insertedSourceIds.contains(srcParentId) || !chapterIds.containsKey(srcParentId)) {
                    UUID newId = chapterIds.get(chapter.getId());
                    UUID newParentId = srcParentId == null ? null : chapterIds.get(srcParentId);
                    var copy = new LearningPathChapter(newId, target.getId(), newParentId, chapter.getNodeType(),
                            chapter.getCode(), chapter.getTitle(), chapter.getDescription(),
                            chapter.getStartYear(), chapter.getEndYear(), chapter.getPeriodLabel(),
                            chapter.getSortOrder(), chapter.getThemeKey(),
                            chapter.getCoverImageKey(), chapter.getBackgroundConfigJson());
                    chapters.save(copy);
                    insertedSourceIds.add(chapter.getId());
                    iterator.remove();
                    progressed = true;
                }
            }
            if (!progressed) {
                for (var chapter : remaining) {
                    UUID newId = chapterIds.get(chapter.getId());
                    UUID newParentId = chapter.getParentId() == null ? null : chapterIds.get(chapter.getParentId());
                    var copy = new LearningPathChapter(newId, target.getId(), newParentId, chapter.getNodeType(),
                            chapter.getCode(), chapter.getTitle(), chapter.getDescription(),
                            chapter.getStartYear(), chapter.getEndYear(), chapter.getPeriodLabel(),
                            chapter.getSortOrder(), chapter.getThemeKey(),
                            chapter.getCoverImageKey(), chapter.getBackgroundConfigJson());
                    chapters.save(copy);
                }
                break;
            }
        }
        chapters.flush();
        for (var event : events.findByPathVersionIdOrderBySortOrderAsc(sourceId)) {
            var copy = new LearningPathEventNode(null, chapterIds.get(event.getChapterId()), target.getId(),
                    event.getEventId(), event.getSortOrder());
            copy.setParticipationType(event.getParticipationType());
            events.save(copy);
            for (var lesson : lessons.findByEventNodeIdOrderBySortOrderAsc(event.getId())) {
                lessons.save(new LearningPathLessonNode(null, copy.getId(), lesson.getEventId(),
                        lesson.getLessonId(), lesson.getSortOrder()));
            }
        }
        versions.flush();
        return read.detail(target.getId());
    }

    public AdminPathResponse publish(UUID id, Long revision) {
        String code = access.version(id).getPathCode();
        access.lockPath(code);
        var target = access.draft(id, revision);
        versions.flush();
        validator.validateForPublish(code, target.getVersionNo());
        Instant now = Instant.now();
        versions.findByPathCodeAndStatus(code, LearningPathStatus.PUBLISHED).ifPresent(old -> {
            old.archive(now);
            versions.flush();
        });
        target.publish(now);
        versions.flush();
        return read.detail(id);
    }

    private LearningPathVersion newDraft(String code, String title, String description) {
        int next = versions.findByPathCodeOrderByVersionNoDesc(code).stream()
                .mapToInt(LearningPathVersion::getVersionNo).max().orElse(0) + 1;
        return versions.saveAndFlush(new LearningPathVersion(null, code, next, title, description,
                LearningPathStatus.DRAFT, null));
    }
}
