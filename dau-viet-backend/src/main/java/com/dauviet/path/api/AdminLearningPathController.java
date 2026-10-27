package com.dauviet.path.api;

import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;
import com.dauviet.common.api.PageResponse;
import com.dauviet.path.api.dto.*;
import com.dauviet.path.application.*;
import com.dauviet.path.domain.LearningPathVersion;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.PositiveOrZero;
import org.springframework.validation.annotation.Validated;

/**
 * Controller quản trị lộ trình học tập chuẩn hóa (PATH-01).
 * Bảo vệ bởi SecurityConfig: chỉ CONTENT_ADMIN mới được truy cập /api/v1/admin/**.
 */
@RestController
@Validated
@RequestMapping("/api/v1/admin/learning-path")
public class AdminLearningPathController {

    private final LearningPathValidator validator;
    private final AdminPathReadService read;
    private final AdminPathVersionService versions;
    private final AdminPathChapterService chapters;
    private final AdminPathEventService events;
    private final AdminPathLessonService lessons;
    private final AdminPathOrderService order;

    public AdminLearningPathController(LearningPathValidator validator, AdminPathReadService read,
            AdminPathVersionService versions, AdminPathChapterService chapters, AdminPathEventService events,
            AdminPathLessonService lessons, AdminPathOrderService order) {
        this.validator = validator; this.read = read; this.versions = versions; this.chapters = chapters;
        this.events = events; this.lessons = lessons; this.order = order;
    }

    /**
     * Báo cáo kiểm toán chất lượng nội dung và tính nhất quán dữ liệu lộ trình.
     */
    @GetMapping("/audit")
    public PathAuditReport audit(
            @RequestParam(required = false, defaultValue = LearningPathService.DEFAULT_PATH_CODE) String code,
            @RequestParam(required = false) Integer version) {
        return validator.audit(code, version);
    }

    @GetMapping("/versions")
    public List<LearningPathVersion> list(
            @RequestParam(defaultValue = LearningPathService.DEFAULT_PATH_CODE) String code) {
        return read.list(code);
    }

    @GetMapping(value = "/versions", params = "page")
    public PageResponse<LearningPathVersion> listPaged(
            @RequestParam(defaultValue = LearningPathService.DEFAULT_PATH_CODE) String code,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        List<LearningPathVersion> all = read.list(code);
        if (status != null && !status.isBlank()) {
            String normalizedStatus = status.trim().toUpperCase();
            all = all.stream()
                    .filter(v -> v.getStatus() != null && v.getStatus().name().equalsIgnoreCase(normalizedStatus))
                    .toList();
        }
        long total = all.size();
        int totalPages = (int) Math.ceil((double) total / size);
        int fromIndex = Math.min(page * size, all.size());
        int toIndex = Math.min(fromIndex + size, all.size());
        return new PageResponse<>(all.subList(fromIndex, toIndex), page, size, total, totalPages);
    }

    @GetMapping("/versions/{versionId}")
    public AdminPathResponse detail(@PathVariable UUID versionId) { return read.detail(versionId); }

    @PostMapping("/versions")
    public AdminPathResponse create(@Valid @RequestBody AdminPathRequests.Draft request) {
        return versions.create(request);
    }

    @PostMapping("/versions/{versionId}/clone")
    public AdminPathResponse clonePublished(@PathVariable UUID versionId) { return versions.clonePublished(versionId); }

    @GetMapping("/versions/{versionId}/validation")
    public PathAuditReport validate(@PathVariable UUID versionId) { return read.validate(versionId); }

    @PostMapping("/versions/{versionId}/publish")
    public AdminPathResponse publish(@PathVariable UUID versionId,
            @Valid @RequestBody AdminPathRequests.Revision request) {
        return versions.publish(versionId, request.expectedRevision());
    }

    @PostMapping("/versions/{versionId}/chapters")
    public AdminPathResponse addChapter(@PathVariable UUID versionId,
            @Valid @RequestBody AdminPathRequests.Chapter request) { return chapters.add(versionId, request); }

    @PatchMapping("/versions/{versionId}/chapters/{chapterId}")
    public AdminPathResponse patchChapter(@PathVariable UUID versionId, @PathVariable UUID chapterId,
            @Valid @RequestBody AdminPathRequests.ChapterPatch request) { return chapters.patch(versionId, chapterId, request); }

    @DeleteMapping("/versions/{versionId}/chapters/{chapterId}")
    public AdminPathResponse deleteChapter(@PathVariable UUID versionId, @PathVariable UUID chapterId,
            @RequestParam @PositiveOrZero Long expectedRevision) { return chapters.delete(versionId, chapterId, expectedRevision); }

    @PostMapping("/versions/{versionId}/chapters/{chapterId}/events")
    public AdminPathResponse addEvent(@PathVariable UUID versionId, @PathVariable UUID chapterId,
            @Valid @RequestBody AdminPathRequests.Event request) { return events.add(versionId, chapterId, request); }

    @PatchMapping("/versions/{versionId}/events/{eventNodeId}")
    public AdminPathResponse patchEvent(@PathVariable UUID versionId, @PathVariable UUID eventNodeId,
            @Valid @RequestBody AdminPathRequests.EventPatch request) { return events.patch(versionId, eventNodeId, request); }

    @DeleteMapping("/versions/{versionId}/events/{eventNodeId}")
    public AdminPathResponse deleteEvent(@PathVariable UUID versionId, @PathVariable UUID eventNodeId,
            @RequestParam @PositiveOrZero Long expectedRevision) { return events.delete(versionId, eventNodeId, expectedRevision); }

    @PostMapping("/versions/{versionId}/events/{eventNodeId}/lessons")
    public AdminPathResponse addLesson(@PathVariable UUID versionId, @PathVariable UUID eventNodeId,
            @Valid @RequestBody AdminPathRequests.Lesson request) { return lessons.add(versionId, eventNodeId, request); }

    @DeleteMapping("/versions/{versionId}/events/{eventNodeId}/lessons/{lessonNodeId}")
    public AdminPathResponse deleteLesson(@PathVariable UUID versionId, @PathVariable UUID eventNodeId,
            @PathVariable UUID lessonNodeId, @RequestParam @PositiveOrZero Long expectedRevision) {
        return lessons.delete(versionId, eventNodeId, lessonNodeId, expectedRevision);
    }

    @PutMapping("/versions/{versionId}/chapters/reorder")
    public AdminPathResponse reorderChapters(@PathVariable UUID versionId,
            @Valid @RequestBody AdminPathRequests.ChaptersOrder request) { return order.chapters(versionId, request); }

    @PutMapping("/versions/{versionId}/chapters/{chapterId}/events/reorder")
    public AdminPathResponse reorderEvents(@PathVariable UUID versionId, @PathVariable UUID chapterId,
            @Valid @RequestBody AdminPathRequests.EventsOrder request) { return order.events(versionId, chapterId, request); }

    @PutMapping("/versions/{versionId}/events/{eventNodeId}/lessons/reorder")
    public AdminPathResponse reorderLessons(@PathVariable UUID versionId, @PathVariable UUID eventNodeId,
            @Valid @RequestBody AdminPathRequests.LessonsOrder request) { return order.lessons(versionId, eventNodeId, request); }
}
