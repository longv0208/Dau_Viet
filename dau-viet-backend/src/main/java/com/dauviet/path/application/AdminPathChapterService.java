package com.dauviet.path.application;

import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.dauviet.path.api.dto.*;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.infrastructure.persistence.*;

@Service
@Transactional
public class AdminPathChapterService {
    private final AdminPathAccess access;
    private final AdminPathReadService read;
    private final LearningPathChapterRepository chapters;
    private final LearningPathEventNodeRepository events;

    public AdminPathChapterService(AdminPathAccess access, AdminPathReadService read,
            LearningPathChapterRepository chapters, LearningPathEventNodeRepository events) {
        this.access = access; this.read = read; this.chapters = chapters; this.events = events;
    }

    public AdminPathResponse add(UUID versionId, AdminPathRequests.Chapter request) {
        access.draft(versionId, request.expectedRevision());
        validateFields(request.code(), request.title(), request.startYear(), request.endYear(),
                request.periodLabel(), request.themeKey());
        uniqueCode(versionId, null, request.code());
        int order = chapters.findByPathVersionIdOrderBySortOrderAsc(versionId).stream()
                .mapToInt(LearningPathChapter::getSortOrder).max().orElse(0) + 1;
        chapters.saveAndFlush(new LearningPathChapter(null, versionId, request.code(), request.title(),
                request.description(), request.startYear(), request.endYear(), request.periodLabel(), order, request.themeKey()));
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
        chapter.update(code, title, value(request.description(), chapter.getDescription()), start, end, period, theme);
        chapters.flush();
        return read.detail(versionId);
    }

    public AdminPathResponse delete(UUID versionId, UUID id, Long revision) {
        access.draft(versionId, revision);
        var chapter = access.chapter(versionId, id);
        AdminPathAccess.require(events.findByChapterIdOrderBySortOrderAsc(id).isEmpty(),
                "Move or remove all event nodes before deleting a chapter");
        chapters.delete(chapter);
        chapters.flush();
        access.deferSortConstraints();
        var remaining = chapters.findByPathVersionIdOrderBySortOrderAsc(versionId);
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
