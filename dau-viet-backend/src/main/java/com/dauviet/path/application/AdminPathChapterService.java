package com.dauviet.path.application;

import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.*;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.PathNodeType;
import com.dauviet.path.infrastructure.persistence.*;

@Service
@Transactional
public class AdminPathChapterService {
    private final AdminPathAccess access;
    private final AdminPathReadService read;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;
    private final PathHierarchyValidator hierarchyValidator;

    public AdminPathChapterService(AdminPathAccess access, AdminPathReadService read,
            LearningPathChapterRepository chapters, LearningPathEventNodeRepository events,
            PathHierarchyValidator hierarchyValidator) {
        this.access = access;
        this.read = read;
        this.chapters = chapters;
        this.events = events;
        this.hierarchyValidator = hierarchyValidator;
    }

    public AdminPathResponse add(UUID versionId, AdminPathRequests.Chapter request) {
        access.draft(versionId, request.expectedRevision());
        validateFields(request.code(), request.title(), request.startYear(), request.endYear(),
                request.periodLabel(), request.themeKey());
        uniqueCode(versionId, null, request.code());
        PathNodeType nodeType = hierarchyValidator.parseNodeType(request.nodeType());
        hierarchyValidator.validateParentAssignment(versionId, null, request.parentId(), nodeType);
        int order = chapters.findByPathVersionIdOrderBySortOrderAsc(versionId).stream()
                .filter(c -> Objects.equals(c.getParentId(), request.parentId()))
                .mapToInt(LearningPathChapter::getSortOrder).max().orElse(0) + 1;
        chapters.saveAndFlush(new LearningPathChapter(null, versionId, request.parentId(), nodeType,
                request.code(), request.title(), request.description(), request.startYear(),
                request.endYear(), request.periodLabel(), order, request.themeKey(),
                request.coverImageKey()));
        return read.detail(versionId);
    }

    public AdminPathResponse patch(UUID versionId, UUID id, AdminPathRequests.ChapterPatch request) {
        access.draft(versionId, request.expectedRevision());
        var chapter = access.chapter(versionId, id);
        String code = value(request.code(), chapter.getCode());
        String title = value(request.title(), chapter.getTitle());
        int start = request.startYear() == null ? chapter.getStartYear() : request.startYear();
        int end = request.endYear() == null ? chapter.getEndYear() : request.endYear();
        String period = value(request.periodLabel(), chapter.getPeriodLabel());
        String theme = value(request.themeKey(), chapter.getThemeKey());
        validateFields(code, title, start, end, period, theme);
        uniqueCode(versionId, id, code);
        UUID parentId = Boolean.TRUE.equals(request.clearParent())
                ? null
                : (request.parentId() != null ? request.parentId() : chapter.getParentId());
        PathNodeType nodeType = request.nodeType() != null
                ? hierarchyValidator.parseNodeType(request.nodeType())
                : chapter.getNodeType();
        hierarchyValidator.validateParentAssignment(versionId, id, parentId, nodeType);
        boolean parentChanged = !Objects.equals(parentId, chapter.getParentId());
        if (parentChanged) {
            access.deferSortConstraints();
            int nextOrder = chapters.findByPathVersionIdOrderBySortOrderAsc(versionId).stream()
                    .filter(c -> !c.getId().equals(id) && Objects.equals(c.getParentId(), parentId))
                    .mapToInt(LearningPathChapter::getSortOrder).max().orElse(0) + 1;
            chapter.setSortOrder(nextOrder);
        }
        chapter.update(parentId, nodeType, code, title,
                value(request.description(), chapter.getDescription()), start, end, period, theme);
        if (request.coverImageKey() != null) {
            chapter.setCoverImageKey(request.coverImageKey());
        }
        chapters.flush();
        return read.detail(versionId);
    }

    public AdminPathResponse delete(UUID versionId, UUID id, Long revision) {
        access.draft(versionId, revision);
        var chapter = access.chapter(versionId, id);
        hierarchyValidator.validateCanDeleteChapter(versionId, id);
        AdminPathAccess.require(events.findByChapterIdOrderBySortOrderAsc(id).isEmpty(),
                "Move or remove all event nodes before deleting a chapter");
        UUID parentId = chapter.getParentId();
        chapters.delete(chapter);
        chapters.flush();
        access.deferSortConstraints();
        var remaining = chapters.findByPathVersionIdOrderBySortOrderAsc(versionId).stream()
                .filter(c -> Objects.equals(c.getParentId(), parentId))
                .toList();
        for (int i = 0; i < remaining.size(); i++) remaining.get(i).setSortOrder(i + 1);
        chapters.flush();
        return read.detail(versionId);
    }

    private void uniqueCode(UUID versionId, UUID id, String code) {
        chapters.findByPathVersionIdAndCode(versionId, code).ifPresent(existing ->
                AdminPathAccess.require(existing.getId().equals(id), "Chapter code already exists in this version"));
    }

    private static void validateFields(String code, String title, int start, int end, String period, String theme) {
        AdminPathAccess.require(!code.isBlank() && !title.isBlank() && !period.isBlank() && !theme.isBlank(),
                "Chapter code, title, periodLabel and themeKey must not be blank");
        AdminPathAccess.require(start <= end, "Chapter startYear must be less than or equal to endYear");
    }

    private static String value(String replacement, String current) { return replacement == null ? current : replacement; }
}
