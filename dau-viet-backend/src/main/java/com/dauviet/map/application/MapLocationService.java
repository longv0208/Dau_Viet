package com.dauviet.map.application;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonStatus;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.map.api.dto.MapLocationDto;
import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationEvent;
import com.dauviet.map.domain.MapLocationMedia;
import com.dauviet.map.domain.MapLocationStatus;
import com.dauviet.map.domain.UserLocationUnlock;
import com.dauviet.map.infrastructure.persistence.MapLocationEventRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationMediaRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationRepository;
import com.dauviet.map.infrastructure.persistence.UserLocationUnlockRepository;
import com.dauviet.path.application.YearLabelFormatter;
import com.dauviet.path.domain.LearningPathChapter;
import com.dauviet.path.domain.LearningPathEventNode;
import com.dauviet.path.domain.LearningPathStatus;
import com.dauviet.path.infrastructure.persistence.LearningPathChapterRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathEventNodeRepository;
import com.dauviet.path.infrastructure.persistence.LearningPathVersionRepository;

@Service
public class MapLocationService {

    private final MapLocationRepository locations;
    private final MapLocationEventRepository locationEvents;
    private final MapLocationMediaRepository locationMedia;
    private final UserLocationUnlockRepository userUnlocks;
    private final LocationUnlockEvaluator unlockEvaluator;
    private final LessonRepository lessons;
    private final HistoricalEventRepository events;
    private final MapLocationUnlockQuery unlockQuery;
    private final LearningPathVersionRepository pathVersions;
    private final LearningPathChapterRepository pathChapters;
    private final LearningPathEventNodeRepository pathEventNodes;

    public MapLocationService(MapLocationRepository locations,
                              MapLocationEventRepository locationEvents,
                              MapLocationMediaRepository locationMedia,
                              UserLocationUnlockRepository userUnlocks,
                              LocationUnlockEvaluator unlockEvaluator,
                              LessonRepository lessons,
                              HistoricalEventRepository events,
                              MapLocationUnlockQuery unlockQuery,
                              LearningPathVersionRepository pathVersions,
                              LearningPathChapterRepository pathChapters,
                              LearningPathEventNodeRepository pathEventNodes) {
        this.locations = locations;
        this.locationEvents = locationEvents;
        this.locationMedia = locationMedia;
        this.userUnlocks = userUnlocks;
        this.unlockEvaluator = unlockEvaluator;
        this.lessons = lessons;
        this.events = events;
        this.unlockQuery = unlockQuery;
        this.pathVersions = pathVersions;
        this.pathChapters = pathChapters;
        this.pathEventNodes = pathEventNodes;
    }

    @Transactional(readOnly = true)
    public List<MapLocationDto> listForLearner(UUID userId) {
        return listForLearner(userId, null, null, null, null);
    }

    @Transactional(readOnly = true)
    public List<MapLocationDto> listForLearner(UUID userId, String periodCode,
                                               UUID eventId, String kind,
                                               Boolean unlockedFilter) {
        List<MapLocation> rows = locations.findVisibleForLearner(MapLocationStatus.PUBLISHED);
        List<MapLocationDto> dtos = toDtos(userId, rows, false);

        Set<UUID> periodEventIds = resolveEventIdsForPeriodCode(periodCode);
        return dtos.stream()
                .filter(dto -> !"HIDDEN_UNTIL_UNLOCKED".equalsIgnoreCase(dto.visibility()) || dto.unlocked())
                .filter(dto -> kind == null || kind.isBlank() || kind.trim().equalsIgnoreCase(dto.kind()))
                .filter(dto -> unlockedFilter == null || unlockedFilter.booleanValue() == dto.unlocked())
                .filter(dto -> eventId == null || dto.eventIds().contains(eventId) || eventId.equals(dto.eventId()))
                .filter(dto -> periodEventIds == null || dto.eventIds().stream().anyMatch(periodEventIds::contains))
                .toList();
    }

    @Transactional(readOnly = true)
    public MapLocationDto getForLearner(UUID userId, UUID locationId) {
        MapLocation loc = locations
                .findVisibleForLearnerById(locationId, MapLocationStatus.PUBLISHED)
                .orElseThrow(() -> new ResourceNotFoundException("Map location not found"));
        return toDtos(userId, List.of(loc), true).get(0);
    }

    private List<MapLocationDto> toDtos(UUID userId, List<MapLocation> rows, boolean includeMedia) {
        if (rows.isEmpty()) {
            return List.of();
        }
        List<UUID> locIds = rows.stream().map(MapLocation::getId).toList();
        Map<UUID, Set<UUID>> rulesByLocation = unlockEvaluator.loadEffectiveUnlockLessons(rows);

        Set<UUID> allLinkedLessonIds = new HashSet<>();
        rulesByLocation.values().forEach(allLinkedLessonIds::addAll);
        Set<UUID> completedLessons = unlockQuery.completedLessonIds(userId, allLinkedLessonIds);

        Map<UUID, Lesson> lessonById = allLinkedLessonIds.isEmpty()
                ? Map.of()
                : lessons.findAllById(allLinkedLessonIds).stream()
                        .collect(Collectors.toMap(Lesson::getId, Function.identity()));

        Set<UUID> persistedUnlocks = userUnlocks.findByIdUserIdAndIdLocationIdIn(userId, locIds)
                .stream().map(UserLocationUnlock::getLocationId).collect(Collectors.toSet());

        Map<UUID, List<MapLocationEvent>> eventsByLocation = locationEvents
                .findByIdLocationIdInOrderBySortOrderAsc(locIds).stream()
                .collect(Collectors.groupingBy(MapLocationEvent::getLocationId));

        Set<UUID> allEventIds = new HashSet<>();
        for (MapLocation r : rows) {
            if (r.getEventId() != null) allEventIds.add(r.getEventId());
        }
        eventsByLocation.values().forEach(list -> list.forEach(e -> allEventIds.add(e.getEventId())));
        Map<UUID, HistoricalEvent> eventsById = allEventIds.isEmpty()
                ? Map.of()
                : events.findAllById(allEventIds).stream()
                        .collect(Collectors.toMap(HistoricalEvent::getId, Function.identity()));

        Map<UUID, List<MapLocationMedia>> mediaByLocation = includeMedia
                ? locationMedia.findByLocationIdInOrderBySortOrderAsc(locIds).stream()
                        .collect(Collectors.groupingBy(MapLocationMedia::getLocationId))
                : Map.of();

        return rows.stream().map(loc -> {
            Set<UUID> ruleLessons = rulesByLocation.getOrDefault(loc.getId(), Set.of());
            String unlockMode = ruleLessons.isEmpty() ? "NONE"
                    : ("ALL".equalsIgnoreCase(loc.getUnlockRuleMode()) ? "ALL" : "ANY");

            String state;
            boolean isUnlocked;
            MapLocationDto.RequiredLessonRef required = null;
            List<MapLocationDto.UnlockLessonProgressDto> unlockLessonDtos = new ArrayList<>();

            for (UUID lid : ruleLessons) {
                Lesson l = lessonById.get(lid);
                boolean accessible = l != null
                        && l.getStatus() == LessonStatus.PUBLISHED
                        && l.getCurrentVersionId() != null;
                boolean done = completedLessons.contains(lid);
                unlockLessonDtos.add(new MapLocationDto.UnlockLessonProgressDto(
                        lid, l == null ? null : l.getTitle(), done, accessible));
                if (required == null) {
                    required = new MapLocationDto.RequiredLessonRef(
                            lid, l == null ? null : l.getTitle(), accessible);
                }
            }

            if (ruleLessons.isEmpty()) {
                state = "AVAILABLE";
                isUnlocked = true;
            } else {
                boolean satisfied = persistedUnlocks.contains(loc.getId())
                        || unlockEvaluator.isRuleSatisfied(unlockMode, ruleLessons, completedLessons);
                state = satisfied ? "UNLOCKED" : "LOCKED";
                isUnlocked = satisfied;
            }

            List<MapLocationEvent> locEventLinks = eventsByLocation.getOrDefault(loc.getId(), List.of());
            Set<UUID> eventIdsSet = new LinkedHashSet<>();
            if (loc.getEventId() != null) {
                eventIdsSet.add(loc.getEventId());
            }
            List<MapLocationDto.LinkedEventDto> linkedEventDtos = new ArrayList<>();
            for (MapLocationEvent link : locEventLinks) {
                eventIdsSet.add(link.getEventId());
                HistoricalEvent he = eventsById.get(link.getEventId());
                if (he != null) {
                    String yearLabel = he.getStartYear() == null ? he.getPeriod()
                            : YearLabelFormatter.formatYear(he.getStartYear(), he.getPeriod());
                    linkedEventDtos.add(new MapLocationDto.LinkedEventDto(
                            he.getId(), he.getTitle(), yearLabel, link.getRole(), link.getSortOrder()));
                }
            }
            UUID primaryEventId = loc.getEventId() != null ? loc.getEventId()
                    : (eventIdsSet.isEmpty() ? null : eventIdsSet.iterator().next());
            HistoricalEvent primaryEvent = primaryEventId == null ? null : eventsById.get(primaryEventId);
            String primaryEventTitle = primaryEvent == null ? null : primaryEvent.getTitle();

            List<MapLocationDto.LocationMediaDto> mediaDtos = List.of();
            if (includeMedia) {
                List<MapLocationMedia> rawMedia = mediaByLocation.getOrDefault(loc.getId(), List.of());
                mediaDtos = rawMedia.stream()
                        .filter(m -> isUnlocked || "PUBLIC_PREVIEW".equalsIgnoreCase(m.getVisibility()))
                        .map(m -> new MapLocationDto.LocationMediaDto(
                                m.getId(),
                                m.getMediaType(),
                                m.getTitle(),
                                m.getCaption(),
                                m.getAssetId(),
                                m.getAssetId() == null ? null : "/api/v1/assets/" + m.getAssetId() + "/content",
                                m.getExternalUrl(),
                                m.getVisibility(),
                                m.getSortOrder()))
                        .toList();
            }

            return new MapLocationDto(
                    loc.getId(),
                    primaryEventId,
                    primaryEventTitle,
                    loc.getSlug(),
                    loc.getTitle(),
                    loc.getShortSummary(),
                    loc.getDescription(),
                    loc.getLatitude(),
                    loc.getLongitude(),
                    loc.getKind(),
                    loc.getCoordinatePrecision(),
                    loc.getVisibility(),
                    unlockMode,
                    isUnlocked,
                    state,
                    loc.getCoverAssetId(),
                    loc.getMapAssetId(),
                    required,
                    List.copyOf(eventIdsSet),
                    linkedEventDtos,
                    unlockLessonDtos,
                    mediaDtos
            );
        }).toList();
    }

    private Set<UUID> resolveEventIdsForPeriodCode(String periodCode) {
        if (periodCode == null || periodCode.isBlank()) {
            return null;
        }
        var versionOpt = pathVersions.findByPathCodeAndStatus("HISTORY_MAIN", LearningPathStatus.PUBLISHED);
        if (versionOpt.isEmpty()) {
            return Set.of();
        }
        UUID versionId = versionOpt.get().getId();
        List<LearningPathChapter> allChapters = pathChapters.findByPathVersionIdOrderBySortOrderAsc(versionId);
        LearningPathChapter target = allChapters.stream()
                .filter(c -> periodCode.trim().equalsIgnoreCase(c.getCode()))
                .findFirst().orElse(null);
        if (target == null) {
            return Set.of();
        }
        Set<UUID> chapterIds = new HashSet<>();
        chapterIds.add(target.getId());
        for (LearningPathChapter c : allChapters) {
            if (target.getId().equals(c.getParentId())) {
                chapterIds.add(c.getId());
            }
        }
        return pathEventNodes.findByPathVersionIdOrderBySortOrderAsc(versionId).stream()
                .filter(n -> chapterIds.contains(n.getChapterId()))
                .map(LearningPathEventNode::getEventId)
                .collect(Collectors.toSet());
    }
}
