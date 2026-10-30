package com.dauviet.map.admin;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.map.admin.dto.AdminMapLocationRequest;
import com.dauviet.map.admin.dto.AdminMapLocationResponse;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.EventLinkInput;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.EventLinkView;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.MediaInput;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.MediaView;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.ReplaceUnlockLessonsRequest;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.ReplaceEventsRequest;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.StandaloneLocationRequest;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.StandaloneLocationResponse;
import com.dauviet.map.admin.dto.AdminStandaloneMapLocationDtos.UnlockLessonView;
import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationEvent;
import com.dauviet.map.domain.MapLocationMedia;
import com.dauviet.map.domain.MapLocationStatus;
import com.dauviet.map.domain.MapLocationUnlockLesson;
import com.dauviet.map.infrastructure.persistence.MapLocationEventRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationMediaRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationUnlockLessonRepository;

/**
 * Admin CRUD + publish/archive for map locations (both event-nested v1 and standalone v2).
 */
@Service
public class AdminMapLocationService {

    private static final Set<String> VALID_KINDS = Set.of(
            "HERITAGE_SITE", "BATTLEFIELD", "ANCIENT_CAPITAL",
            "ARCHAEOLOGICAL_SITE", "MEMORIAL", "SCHEMATIC_REGION");
    private static final Set<String> VALID_PRECISIONS = Set.of(
            "EXACT", "APPROXIMATE", "SCHEMATIC_ONLY");
    private static final Set<String> VALID_VISIBILITIES = Set.of(
            "ALWAYS_VISIBLE", "HIDDEN_UNTIL_UNLOCKED");
    private static final Set<String> VALID_UNLOCK_MODES = Set.of(
            "NONE", "ANY", "ALL");
    private static final Set<String> VALID_EVENT_ROLES = Set.of(
            "PRIMARY", "RELATED");
    private static final Set<String> VALID_MEDIA_TYPES = Set.of(
            "IMAGE_2D", "PANORAMA_360", "AUDIO_GUIDE", "DOCUMENTARY_CLIP");
    private static final Set<String> VALID_MEDIA_VISIBILITIES = Set.of(
            "PUBLIC_PREVIEW", "UNLOCKED_ONLY");

    private final MapLocationRepository locations;
    private final HistoricalEventRepository events;
    private final LessonRepository lessons;
    private final MapLocationEventRepository locationEvents;
    private final MapLocationUnlockLessonRepository unlockLessons;
    private final MapLocationMediaRepository locationMedia;
    private final AssetRepository assets;

    public AdminMapLocationService(MapLocationRepository locations,
                                   HistoricalEventRepository events,
                                   LessonRepository lessons) {
        this(locations, events, lessons, null, null, null, null);
    }

    @Autowired
    public AdminMapLocationService(MapLocationRepository locations,
                                   HistoricalEventRepository events,
                                   LessonRepository lessons,
                                   MapLocationEventRepository locationEvents,
                                   MapLocationUnlockLessonRepository unlockLessons,
                                   MapLocationMediaRepository locationMedia,
                                   AssetRepository assets) {
        this.locations = locations;
        this.events = events;
        this.lessons = lessons;
        this.locationEvents = locationEvents;
        this.unlockLessons = unlockLessons;
        this.locationMedia = locationMedia;
        this.assets = assets;
    }

    /* ==================== Legacy Event-Nested Endpoints ==================== */

    @Transactional(readOnly = true)
    public List<AdminMapLocationResponse> list(UUID eventId) {
        requireEvent(eventId);
        Map<UUID, MapLocation> byLocId = new java.util.LinkedHashMap<>();
        List<MapLocation> direct = locations.findByEventIdOrderByDisplayOrderAscTitleAsc(eventId);
        if (direct != null) {
            for (MapLocation l : direct) {
                if (l != null && l.getId() != null) {
                    byLocId.put(l.getId(), l);
                }
            }
        }
        List<MapLocation> linkedQuery = locations.findAllByEventIdIncludingLinks(eventId);
        if (linkedQuery != null) {
            for (MapLocation l : linkedQuery) {
                if (l != null && l.getId() != null) {
                    byLocId.putIfAbsent(l.getId(), l);
                }
            }
        }
        if (locationEvents != null) {
            List<MapLocationEvent> links = locationEvents.findByIdEventId(eventId);
            if (links != null && !links.isEmpty()) {
                Set<UUID> missingIds = new java.util.LinkedHashSet<>();
                for (MapLocationEvent link : links) {
                    UUID locId = link != null ? link.getLocationId() : null;
                    if (locId != null && !byLocId.containsKey(locId)) {
                        missingIds.add(locId);
                    }
                }
                if (!missingIds.isEmpty()) {
                    List<MapLocation> fetched = locations.findAllById(missingIds);
                    if (fetched != null) {
                        for (MapLocation l : fetched) {
                            if (l != null && l.getId() != null) {
                                byLocId.putIfAbsent(l.getId(), l);
                            }
                        }
                    }
                }
            }
        }
        List<MapLocation> rows = byLocId.values().stream()
                .sorted(java.util.Comparator
                        .comparingInt(MapLocation::getDisplayOrder)
                        .thenComparing(l -> l.getTitle() == null ? "" : l.getTitle()))
                .toList();
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
        l.setUnlockRuleMode(req.unlockLessonId() != null ? "ANY" : "NONE");
        l.setStatus(MapLocationStatus.DRAFT);
        MapLocation saved = locations.saveAndFlush(l);
        syncLegacyJoinTables(saved);
        return toResponse(saved, Map.of());
    }

    @Transactional
    public AdminMapLocationResponse update(UUID eventId, UUID locationId,
                                           AdminMapLocationRequest req,
                                           Long expectedRowVersion) {
        MapLocation l = load(eventId, locationId);
        checkVersion(l, expectedRowVersion);
        validateLessonLink(eventId, req.unlockLessonId());
        if (l.getPublishedAt() != null
                && !Objects.equals(req.unlockLessonId(), l.getUnlockLessonId())) {
            throw new IllegalArgumentException(
                    "Địa điểm đã từng xuất bản không thể đổi bài học mở khoá");
        }
        apply(l, req);
        l.setUnlockRuleMode(req.unlockLessonId() != null ? "ANY" : "NONE");
        MapLocation saved = locations.saveAndFlush(l);
        syncLegacyJoinTables(saved);
        return toResponse(saved, Map.of());
    }

    @Transactional
    public AdminMapLocationResponse setStatus(UUID eventId, UUID locationId,
                                              MapLocationStatus status,
                                              Long expectedRowVersion) {
        MapLocation l = load(eventId, locationId);
        checkVersion(l, expectedRowVersion);
        if (status == MapLocationStatus.PUBLISHED) {
            validatePublishable(l.getUnlockLessonId());
            if (l.getPublishedAt() == null) {
                l.setPublishedAt(Instant.now());
            }
        }
        l.setStatus(status);
        return toResponse(locations.save(l), Map.of());
    }

    /* ==================== Standalone Heritage Location V2 Endpoints ==================== */

    @Transactional(readOnly = true)
    public List<StandaloneLocationResponse> listStandalone(
            String q, String kind, MapLocationStatus status, UUID eventId) {
        List<MapLocation> all = locations.findAllOrderedForAdmin();
        Set<UUID> eventFilteredLocationIds = null;
        if (eventId != null) {
            eventFilteredLocationIds = new HashSet<>();
            for (MapLocation loc : all) {
                if (eventId.equals(loc.getEventId())) {
                    eventFilteredLocationIds.add(loc.getId());
                }
            }
            if (locationEvents != null) {
                for (MapLocationEvent link : locationEvents.findByIdEventId(eventId)) {
                    eventFilteredLocationIds.add(link.getId().getLocationId());
                }
            }
        }

        String normalizedQ = (q == null || q.isBlank()) ? null : q.trim().toLowerCase(Locale.ROOT);
        String normalizedKind = (kind == null || kind.isBlank()) ? null : kind.trim().toUpperCase(Locale.ROOT);
        final Set<UUID> allowedByEvent = eventFilteredLocationIds;

        List<MapLocation> filtered = all.stream()
                .filter(l -> status == null || l.getStatus() == status)
                .filter(l -> normalizedKind == null || normalizedKind.equalsIgnoreCase(l.getKind()))
                .filter(l -> allowedByEvent == null || allowedByEvent.contains(l.getId()))
                .filter(l -> {
                    if (normalizedQ == null) return true;
                    String title = l.getTitle() == null ? "" : l.getTitle().toLowerCase(Locale.ROOT);
                    String slug = l.getSlug() == null ? "" : l.getSlug().toLowerCase(Locale.ROOT);
                    return title.contains(normalizedQ) || slug.contains(normalizedQ);
                })
                .toList();

        return filtered.stream().map(this::toStandaloneResponse).toList();
    }

    @Transactional(readOnly = true)
    public com.dauviet.common.api.PageResponse<StandaloneLocationResponse> listStandalonePage(
            String q, String kind, MapLocationStatus status, UUID eventId, int page, int size) {
        List<StandaloneLocationResponse> all = listStandalone(q, kind, status, eventId);
        int safeSize = Math.max(1, Math.min(size, 100));
        int safePage = Math.max(0, page);
        long total = all.size();
        int totalPages = (int) Math.ceil((double) total / safeSize);
        int fromIndex = Math.min(safePage * safeSize, all.size());
        int toIndex = Math.min(fromIndex + safeSize, all.size());
        List<StandaloneLocationResponse> slice = all.subList(fromIndex, toIndex);
        return new com.dauviet.common.api.PageResponse<>(slice, safePage, safeSize, total, totalPages);
    }

    @Transactional(readOnly = true)
    public StandaloneLocationResponse getStandalone(UUID locationId) {
        MapLocation l = loadStandalone(locationId);
        return toStandaloneResponse(l);
    }

    @Transactional
    public StandaloneLocationResponse createStandalone(StandaloneLocationRequest req) {
        validateStandaloneEnums(req);
        validateAssetIfPresent(req.coverAssetId());
        validateAssetIfPresent(req.mapAssetId());
        validateSlugUniqueness(req.slug(), null);

        MapLocation l = new MapLocation();
        l.setId(UUID.randomUUID());
        applyStandalone(l, req);
        l.setStatus(MapLocationStatus.DRAFT);
        MapLocation saved = locations.saveAndFlush(l);
        return toStandaloneResponse(saved);
    }

    @Transactional
    public StandaloneLocationResponse updateStandalone(
            UUID locationId, StandaloneLocationRequest req, Long expectedRowVersion) {
        MapLocation l = loadStandalone(locationId);
        checkVersion(l, expectedRowVersion);
        validateStandaloneEnums(req);
        validateAssetIfPresent(req.coverAssetId());
        validateAssetIfPresent(req.mapAssetId());
        validateSlugUniqueness(req.slug(), locationId);

        applyStandalone(l, req);
        MapLocation saved = locations.saveAndFlush(l);
        return toStandaloneResponse(saved);
    }

    @Transactional
    public StandaloneLocationResponse setStandaloneStatus(
            UUID locationId, MapLocationStatus status, Long expectedRowVersion) {
        MapLocation l = loadStandalone(locationId);
        checkVersion(l, expectedRowVersion);
        if (status == MapLocationStatus.PUBLISHED) {
            validatePublishable(l.getUnlockLessonId());
            if (unlockLessons != null) {
                List<MapLocationUnlockLesson> rules =
                        unlockLessons.findByIdLocationId(locationId);
                for (MapLocationUnlockLesson rule : rules) {
                    validatePublishable(rule.getId().getLessonId());
                }
            }
            if (l.getPublishedAt() == null) {
                l.setPublishedAt(Instant.now());
            }
        }
        l.setStatus(status);
        MapLocation saved = locations.saveAndFlush(l);
        return toStandaloneResponse(saved);
    }

    @Transactional
    public StandaloneLocationResponse replaceEvents(UUID locationId, ReplaceEventsRequest req) {
        return replaceEvents(locationId, req == null ? List.of() : req.events());
    }

    @Transactional
    public StandaloneLocationResponse replaceEvents(UUID locationId, List<EventLinkInput> inputs) {
        MapLocation l = loadStandalone(locationId);
        List<EventLinkInput> safeInputs = inputs == null ? List.of() : inputs;
        Set<UUID> seen = new HashSet<>();
        for (EventLinkInput in : safeInputs) {
            if (in.eventId() == null) {
                throw new IllegalArgumentException("eventId không được để trống");
            }
            if (!seen.add(in.eventId())) {
                throw new IllegalArgumentException("Duplicate eventId: " + in.eventId());
            }
            requireEvent(in.eventId());
            String role = in.role() == null ? "RELATED" : in.role().trim().toUpperCase(Locale.ROOT);
            if (!VALID_EVENT_ROLES.contains(role)) {
                throw new IllegalArgumentException("Invalid event role: " + in.role());
            }
        }

        UUID primaryEventId = null;
        if (!safeInputs.isEmpty()) {
            for (EventLinkInput in : safeInputs) {
                String role = in.role() == null ? "RELATED" : in.role().trim().toUpperCase(Locale.ROOT);
                if ("PRIMARY".equals(role)) {
                    primaryEventId = in.eventId();
                    break;
                }
            }
            if (primaryEventId == null) {
                primaryEventId = safeInputs.get(0).eventId();
            }
        }
        l.setEventId(primaryEventId);
        locations.saveAndFlush(l);

        if (locationEvents != null) {
            locationEvents.deleteByLocationId(locationId);
            locationEvents.flush();
            int idx = 0;
            for (EventLinkInput in : safeInputs) {
                String role = in.role() == null ? "RELATED" : in.role().trim().toUpperCase(Locale.ROOT);
                int sort = in.sortOrder() != null ? in.sortOrder() : idx;
                locationEvents.save(new MapLocationEvent(locationId, in.eventId(), role, sort));
                idx++;
            }
            locationEvents.flush();
        }
        return toStandaloneResponse(l);
    }

    @Transactional
    public StandaloneLocationResponse replaceUnlockLessons(
            UUID locationId, ReplaceUnlockLessonsRequest req) {
        MapLocation l = loadStandalone(locationId);
        String mode = req.unlockRuleMode() == null
                ? "NONE"
                : req.unlockRuleMode().trim().toUpperCase(Locale.ROOT);
        if (!VALID_UNLOCK_MODES.contains(mode)) {
            throw new IllegalArgumentException("Invalid unlockRuleMode: " + req.unlockRuleMode());
        }
        List<UUID> lessonIds = req.lessonIds() == null ? List.of() : req.lessonIds();
        if (!"NONE".equals(mode) && lessonIds.isEmpty()) {
            throw new IllegalArgumentException(
                    "Cần ít nhất 1 bài học mở khoá khi unlockRuleMode là " + mode);
        }

        Set<UUID> seen = new HashSet<>();
        for (UUID lid : lessonIds) {
            if (!seen.add(lid)) {
                throw new IllegalArgumentException("Duplicate lessonId: " + lid);
            }
            Lesson lesson = lessons.findById(lid)
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Bài học mở khoá không tồn tại: " + lid));
            if (l.getStatus() == MapLocationStatus.PUBLISHED) {
                boolean accessible = lesson.getStatus() == LessonStatus.PUBLISHED
                        && lesson.getCurrentVersionId() != null;
                if (!accessible) {
                    throw new IllegalArgumentException(
                            "Địa điểm đang PUBLISHED chỉ được gắn bài học đã PUBLISHED: " + lid);
                }
            }
        }

        l.setUnlockRuleMode(mode);
        if ( "NONE".equals(mode) || lessonIds.isEmpty()) {
            l.setUnlockLessonId(null);
        } else if (l.getEventId() != null) {
            // Only set legacy unlock_lesson_id if lesson belongs to same event (composite FK constraint)
            UUID firstLessonId = lessonIds.get(0);
            Lesson first = lessons.findById(firstLessonId).orElse(null);
            if (first != null && l.getEventId().equals(first.getEventId())) {
                l.setUnlockLessonId(firstLessonId);
            } else {
                l.setUnlockLessonId(null);
            }
        }
        locations.saveAndFlush(l);

        if (unlockLessons != null) {
            unlockLessons.deleteByLocationId(locationId);
            unlockLessons.flush();
            if (!"NONE".equals(mode)) {
                for (int i = 0; i < lessonIds.size(); i++) {
                    unlockLessons.save(new MapLocationUnlockLesson(locationId, lessonIds.get(i)));
                }
                unlockLessons.flush();
            }
        }
        return toStandaloneResponse(l);
    }

    @Transactional
    public StandaloneLocationResponse replaceMedia(UUID locationId, List<MediaInput> inputs) {
        MapLocation l = loadStandalone(locationId);
        List<MediaInput> safeInputs = inputs == null ? List.of() : inputs;
        for (MediaInput in : safeInputs) {
            String mediaType = in.mediaType() == null
                    ? ""
                    : in.mediaType().trim().toUpperCase(Locale.ROOT);
            if (!VALID_MEDIA_TYPES.contains(mediaType)) {
                throw new IllegalArgumentException("Invalid mediaType: " + in.mediaType());
            }
            String vis = in.visibility() == null
                    ? "PUBLIC_PREVIEW"
                    : in.visibility().trim().toUpperCase(Locale.ROOT);
            if (!VALID_MEDIA_VISIBILITIES.contains(vis)) {
                throw new IllegalArgumentException("Invalid media visibility: " + in.visibility());
            }
            if (in.assetId() == null && (in.externalUrl() == null || in.externalUrl().isBlank())) {
                throw new IllegalArgumentException(
                        "Media phải có assetId hoặc externalUrl");
            }
            validateAssetIfPresent(in.assetId());
        }

        if (locationMedia != null) {
            locationMedia.deleteByLocationId(locationId);
            locationMedia.flush();
            int idx = 0;
            for (MediaInput in : safeInputs) {
                MapLocationMedia m = new MapLocationMedia(
                        UUID.randomUUID(),
                        locationId,
                        in.mediaType().trim().toUpperCase(Locale.ROOT),
                        in.title() == null ? "" : in.title(),
                        in.caption(),
                        in.assetId(),
                        in.externalUrl(),
                        in.visibility() == null ? "PUBLIC_PREVIEW" : in.visibility().trim().toUpperCase(Locale.ROOT),
                        in.sortOrder() != null ? in.sortOrder() : idx);
                locationMedia.save(m);
                idx++;
            }
            locationMedia.flush();
        }
        return toStandaloneResponse(l);
    }

    /* ---------- internals ---------- */

    private void syncLegacyJoinTables(MapLocation l) {
        if (locationEvents != null && l.getEventId() != null) {
            List<MapLocationEvent> existing = locationEvents.findByIdLocationIdOrderBySortOrderAsc(l.getId());
            boolean hasEvent = existing.stream()
                    .anyMatch(e -> l.getEventId().equals(e.getId().getEventId()));
            if (!hasEvent) {
                locationEvents.save(new MapLocationEvent(l.getId(), l.getEventId(), "PRIMARY", 0));
            }
        }
        if (unlockLessons != null) {
            unlockLessons.deleteByLocationId(l.getId());
            unlockLessons.flush();
            if (l.getUnlockLessonId() != null) {
                unlockLessons.save(new MapLocationUnlockLesson(l.getId(), l.getUnlockLessonId()));
                unlockLessons.flush();
            }
        }
    }

    private void validateStandaloneEnums(StandaloneLocationRequest req) {
        if (req.kind() != null && !VALID_KINDS.contains(req.kind().trim().toUpperCase(Locale.ROOT))) {
            throw new IllegalArgumentException("Invalid location kind: " + req.kind());
        }
        if (req.coordinatePrecision() != null
                && !VALID_PRECISIONS.contains(req.coordinatePrecision().trim().toUpperCase(Locale.ROOT))) {
            throw new IllegalArgumentException(
                    "Invalid coordinatePrecision: " + req.coordinatePrecision());
        }
        if (req.visibility() != null
                && !VALID_VISIBILITIES.contains(req.visibility().trim().toUpperCase(Locale.ROOT))) {
            throw new IllegalArgumentException("Invalid visibility: " + req.visibility());
        }
        if (req.unlockRuleMode() != null
                && !VALID_UNLOCK_MODES.contains(req.unlockRuleMode().trim().toUpperCase(Locale.ROOT))) {
            throw new IllegalArgumentException("Invalid unlockRuleMode: " + req.unlockRuleMode());
        }
    }

    private void validateAssetIfPresent(UUID assetId) {
        if (assetId == null || assets == null) return;
        if (!assets.existsById(assetId)) {
            throw new IllegalArgumentException("Asset không tồn tại: " + assetId);
        }
    }

    private void validateSlugUniqueness(String slug, UUID excludeId) {
        if (slug == null || slug.isBlank()) return;
        String clean = slug.trim();
        locations.findBySlug(clean).ifPresent(existing -> {
            if (excludeId == null || !existing.getId().equals(excludeId)) {
                throw new IllegalArgumentException("Slug địa điểm đã tồn tại: " + clean);
            }
        });
    }

    private void applyStandalone(MapLocation l, StandaloneLocationRequest req) {
        if (req.slug() != null && !req.slug().isBlank()) {
            l.setSlug(req.slug().trim());
        }
        l.setTitle(req.title().trim());
        l.setShortSummary(req.shortSummary());
        l.setDescription(req.description());
        l.setKind(req.kind() == null || req.kind().isBlank()
                ? "HERITAGE_SITE"
                : req.kind().trim().toUpperCase(Locale.ROOT));
        l.setLatitude(req.latitude());
        l.setLongitude(req.longitude());
        l.setCoordinatePrecision(req.coordinatePrecision() == null || req.coordinatePrecision().isBlank()
                ? "EXACT"
                : req.coordinatePrecision().trim().toUpperCase(Locale.ROOT));
        l.setVisibility(req.visibility() == null || req.visibility().isBlank()
                ? "ALWAYS_VISIBLE"
                : req.visibility().trim().toUpperCase(Locale.ROOT));
        if (req.unlockRuleMode() != null && !req.unlockRuleMode().isBlank()) {
            l.setUnlockRuleMode(req.unlockRuleMode().trim().toUpperCase(Locale.ROOT));
        }
        l.setCoverAssetId(req.coverAssetId());
        l.setMapAssetId(req.mapAssetId());
        l.setDisplayOrder(req.displayOrder() == null ? 0 : req.displayOrder());
    }

    private StandaloneLocationResponse toStandaloneResponse(MapLocation l) {
        List<EventLinkView> eventViews = new ArrayList<>();
        if (locationEvents != null) {
            List<MapLocationEvent> links = locationEvents.findByIdLocationIdOrderBySortOrderAsc(l.getId());
            Set<UUID> eIds = links.stream().map(e -> e.getId().getEventId()).collect(Collectors.toSet());
            Map<UUID, HistoricalEvent> eventById = eIds.isEmpty()
                    ? Map.of()
                    : events.findAllById(eIds).stream()
                            .collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));
            for (MapLocationEvent link : links) {
                HistoricalEvent ev = eventById.get(link.getId().getEventId());
                eventViews.add(new EventLinkView(
                        link.getId().getEventId(),
                        ev != null ? ev.getTitle() : null,
                        ev != null ? ev.getPeriod() : null,
                        link.getRole(),
                        link.getSortOrder()));
            }
        }

        List<UnlockLessonView> lessonViews = new ArrayList<>();
        if (unlockLessons != null) {
            List<MapLocationUnlockLesson> rules = unlockLessons.findByIdLocationId(l.getId());
            Set<UUID> lIds = rules.stream().map(r -> r.getId().getLessonId()).collect(Collectors.toSet());
            Map<UUID, Lesson> lessonById = lIds.isEmpty()
                    ? Map.of()
                    : lessons.findAllById(lIds).stream()
                            .collect(Collectors.toMap(Lesson::getId, Function.identity()));
            int ruleIdx = 0;
            for (MapLocationUnlockLesson rule : rules) {
                Lesson les = lessonById.get(rule.getId().getLessonId());
                lessonViews.add(new UnlockLessonView(
                        rule.getId().getLessonId(),
                        les != null ? les.getTitle() : null,
                        les != null && les.getStatus() != null ? les.getStatus().name() : null,
                        ruleIdx++));
            }
        }

        List<MediaView> mediaViews = new ArrayList<>();
        if (locationMedia != null) {
            List<MapLocationMedia> mediaRows = locationMedia.findByLocationIdOrderBySortOrderAsc(l.getId());
            for (MapLocationMedia m : mediaRows) {
                String assetUrl = m.getAssetId() != null
                        ? "/api/v1/assets/" + m.getAssetId() + "/content"
                        : null;
                mediaViews.add(new MediaView(
                        m.getId(),
                        m.getMediaType(),
                        m.getTitle(),
                        m.getCaption(),
                        m.getAssetId(),
                        assetUrl,
                        m.getExternalUrl(),
                        m.getVisibility(),
                        m.getSortOrder()));
            }
        }

        return new StandaloneLocationResponse(
                l.getId(),
                l.getSlug(),
                l.getEventId(),
                l.getTitle(),
                l.getShortSummary(),
                l.getDescription(),
                l.getKind(),
                l.getLatitude(),
                l.getLongitude(),
                l.getCoordinatePrecision(),
                l.getVisibility(),
                l.getUnlockRuleMode(),
                l.getCoverAssetId(),
                l.getMapAssetId(),
                l.getDisplayOrder(),
                l.getStatus().name(),
                l.getPublishedAt() != null,
                l.getRowVersion(),
                l.getCreatedAt(),
                l.getUpdatedAt(),
                eventViews,
                lessonViews,
                mediaViews);
    }

    private void requireEvent(UUID eventId) {
        if (!events.existsById(eventId)) {
            throw new ResourceNotFoundException("Event not found: " + eventId);
        }
    }

    private MapLocation load(UUID eventId, UUID locationId) {
        return locations.findByIdAndEventId(locationId, eventId)
                .or(() -> {
                    if (locationEvents != null) {
                        List<MapLocationEvent> links = locationEvents.findByIdEventId(eventId);
                        boolean linked = links != null && links.stream()
                                .anyMatch(e -> e != null && locationId.equals(e.getLocationId()));
                        if (linked) {
                            return locations.findById(locationId);
                        }
                    }
                    return java.util.Optional.empty();
                })
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Map location not found: " + locationId));
    }

    private MapLocation loadStandalone(UUID locationId) {
        return locations.findById(locationId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Map location not found: " + locationId));
    }

    private void checkVersion(MapLocation l, Long expected) {
        if (expected == null) {
            throw new IllegalArgumentException(
                    "Thiếu expectedRowVersion — tải lại địa điểm trước khi sửa");
        }
        if (!expected.equals(l.getRowVersion())) {
            throw new ObjectOptimisticLockingFailureException(
                    MapLocation.class, l.getId());
        }
    }

    /** Cross-event lesson link -> 400; also protected by composite FK. */
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
                .filter(Objects::nonNull)
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
                l.getDisplayOrder(), l.getStatus().name(),
                l.getPublishedAt() != null,
                l.getRowVersion(), l.getCreatedAt(), l.getUpdatedAt());
    }
}
