package com.dauviet.map.admin;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.map.admin.dto.AdminMapLocationRequest;
import com.dauviet.map.admin.dto.AdminMapLocationResponse;
import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationStatus;
import com.dauviet.map.infrastructure.persistence.MapLocationRepository;

/**
 * Admin CRUD + publish/archive for map locations nested under one event.
 * Same-event rule for unlockLesson is enforced in service (400, friendly
 * message) AND at DB level (composite FK) — a cross-event lessonId can never
 * be persisted even if the service check is bypassed.
 */
@Service
public class AdminMapLocationService {

    private final MapLocationRepository locations;
    private final HistoricalEventRepository events;
    private final LessonRepository lessons;

    public AdminMapLocationService(MapLocationRepository locations,
                                   HistoricalEventRepository events,
                                   LessonRepository lessons) {
        this.locations = locations;
        this.events = events;
        this.lessons = lessons;
    }

    @Transactional(readOnly = true)
    public List<AdminMapLocationResponse> list(UUID eventId) {
        requireEvent(eventId);
        List<MapLocation> rows = locations.findByEventIdOrderByDisplayOrderAscTitleAsc(eventId);
        Map<UUID, Lesson> byId = lessonTitles(rows);
        return rows.stream().map(l -> toResponse(l, byId)).toList();
    }

    @Transactional
    public AdminMapLocationResponse create(UUID eventId, AdminMapLocationRequest req) {
        requireEvent(eventId);
        validateLessonLink(eventId, req.unlockLessonId());
        MapLocation l = new MapLocation();
        l.setId(UUID.randomUUID());
        l.setEventId(eventId);
        apply(l, req);
        l.setStatus(MapLocationStatus.DRAFT);
        return toResponse(locations.save(l), Map.of());
    }

    @Transactional
    public AdminMapLocationResponse update(UUID eventId, UUID locationId,
                                           AdminMapLocationRequest req,
                                           Long expectedRowVersion) {
        MapLocation l = load(eventId, locationId);
        checkVersion(l, expectedRowVersion);
        validateLessonLink(eventId, req.unlockLessonId());
        if (l.getStatus() == MapLocationStatus.PUBLISHED) {
            // Publication invariant: PUBLISHED location không được đổi
            // unlockLessonId (đổi → archive về DRAFT, sửa, publish lại).
            // Metadata (title/desc/tọa độ/displayOrder) vẫn sửa tự do.
            if (!java.util.Objects.equals(req.unlockLessonId(),
                                          l.getUnlockLessonId())) {
                throw new IllegalArgumentException(
                        "Địa điểm đã xuất bản không thể đổi bài học mở khoá — "
                        + "chuyển về bản nháp trước khi đổi liên kết");
            }
            // Defence-in-depth: nếu DB đã lưu link không accessible (dữ liệu
            // cũ trước publish gate), mọi update vẫn bị chặn đến khi sửa link.
            validatePublishable(l.getUnlockLessonId());
        }
        apply(l, req);
        return toResponse(locations.save(l), Map.of());
    }

    @Transactional
    public AdminMapLocationResponse setStatus(UUID eventId, UUID locationId,
                                              MapLocationStatus status,
                                              Long expectedRowVersion) {
        MapLocation l = load(eventId, locationId);
        checkVersion(l, expectedRowVersion);
        if (status == MapLocationStatus.PUBLISHED) {
            validatePublishable(l.getUnlockLessonId());
        }
        l.setStatus(status);
        return toResponse(locations.save(l), Map.of());
    }

    /* ---------- internals ---------- */

    private void requireEvent(UUID eventId) {
        if (!events.existsById(eventId)) {
            throw new ResourceNotFoundException("Event not found: " + eventId);
        }
    }

    private MapLocation load(UUID eventId, UUID locationId) {
        return locations.findByIdAndEventId(locationId, eventId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Map location not found: " + locationId));
    }

    private void checkVersion(MapLocation l, Long expected) {
        if (expected == null) {
            throw new IllegalArgumentException(
                    "Thiếu expectedRowVersion — tải lại địa điểm trước khi sửa");
        }
        if (!expected.equals(l.getRowVersion())) {
            throw new org.springframework.orm.ObjectOptimisticLockingFailureException(
                    MapLocation.class, l.getId());
        }
    }

    /** Cross-event lesson link → 400; also protected by composite FK. */
    private void validateLessonLink(UUID eventId, UUID lessonId) {
        if (lessonId == null) return;
        Lesson lesson = lessons.findById(lessonId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Bài học mở khoá không tồn tại: " + lessonId));
        if (!eventId.equals(lesson.getEventId())) {
            throw new IllegalArgumentException(
                    "Bài học mở khoá phải thuộc cùng sự kiện với địa điểm");
        }
    }

    /**
     * Publish gate (FR-36): địa điểm PUBLISHED không được trỏ tới bài học mà
     * learner không mở được — draft (chưa publish) hoặc archived (không còn
     * bản published nào). Bài học đã publish rồi archive vẫn giữ
     * currentVersionId nên learner cũ vẫn mở được; draft/archived-lesson
     * không có version nào thì bị chặn.
     */
    private void validatePublishable(UUID lessonId) {
        if (lessonId == null) return;
        Lesson lesson = lessons.findById(lessonId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Bài học mở khoá không tồn tại: " + lessonId));
        boolean learnerAccessible = lesson.getStatus() == LessonStatus.PUBLISHED
                && lesson.getCurrentVersionId() != null;
        if (!learnerAccessible) {
            throw new IllegalArgumentException(
                    "Bài học mở khoá phải được xuất bản trước khi địa điểm "
                            + "được xuất bản cho học viên");
        }
    }

    private void apply(MapLocation l, AdminMapLocationRequest req) {
        l.setTitle(req.title());
        l.setDescription(req.description());
        l.setLatitude(req.latitude());
        l.setLongitude(req.longitude());
        l.setUnlockLessonId(req.unlockLessonId());
        l.setDisplayOrder(req.displayOrder() == null ? 0 : req.displayOrder());
    }

    private Map<UUID, Lesson> lessonTitles(List<MapLocation> rows) {
        Set<UUID> ids = rows.stream()
                .map(MapLocation::getUnlockLessonId)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());
        return ids.isEmpty() ? Map.of()
                : lessons.findAllById(ids).stream()
                        .collect(Collectors.toMap(Lesson::getId, Function.identity()));
    }

    private AdminMapLocationResponse toResponse(MapLocation l, Map<UUID, Lesson> byId) {
        UUID lessonId = l.getUnlockLessonId();
        Lesson linked = lessonId == null ? null : byId.get(lessonId);
        return new AdminMapLocationResponse(
                l.getId(), l.getEventId(), l.getTitle(), l.getDescription(),
                l.getLatitude(), l.getLongitude(), lessonId,
                linked == null ? null : linked.getTitle(),
                l.getDisplayOrder(), l.getStatus().name(), l.getRowVersion(),
                l.getCreatedAt(), l.getUpdatedAt());
    }
}
