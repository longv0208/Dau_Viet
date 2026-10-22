package com.dauviet.map.application;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.map.api.dto.MapLocationDto;
import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationStatus;
import com.dauviet.map.infrastructure.persistence.MapLocationRepository;

/**
 * Learner-facing map surface (FR-35..38): only PUBLISHED locations on
 * PUBLISHED events; unlock state derived server-side per learner.
 */
@Service
public class MapLocationService {

    private final MapLocationRepository locations;
    private final LessonRepository lessons;
    private final MapLocationUnlockQuery unlockQuery;

    public MapLocationService(MapLocationRepository locations,
                              LessonRepository lessons,
                              MapLocationUnlockQuery unlockQuery) {
        this.locations = locations;
        this.lessons = lessons;
        this.unlockQuery = unlockQuery;
    }

    @Transactional(readOnly = true)
    public List<MapLocationDto> listForLearner(UUID userId) {
        List<MapLocation> rows =
                locations.findVisibleForLearner(MapLocationStatus.PUBLISHED);
        return toDtos(userId, rows);
    }

    @Transactional(readOnly = true)
    public MapLocationDto getForLearner(UUID userId, UUID locationId) {
        MapLocation loc = locations
                .findVisibleForLearnerById(locationId, MapLocationStatus.PUBLISHED)
                .orElseThrow(() -> new ResourceNotFoundException("Map location not found"));
        return toDtos(userId, List.of(loc)).get(0);
    }

    private List<MapLocationDto> toDtos(UUID userId, List<MapLocation> rows) {
        Set<UUID> linked = rows.stream()
                .map(MapLocation::getUnlockLessonId)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());
        Set<UUID> completed = unlockQuery.completedLessonIds(userId, linked);
        Map<UUID, Lesson> lessonById = linked.isEmpty()
                ? Map.of()
                : lessons.findAllById(linked).stream()
                        .collect(Collectors.toMap(Lesson::getId, Function.identity()));

        return rows.stream().map(loc -> {
            UUID lessonId = loc.getUnlockLessonId();
            String state;
            MapLocationDto.RequiredLessonRef required = null;
            if (lessonId == null) {
                state = "AVAILABLE";
            } else {
                Lesson l = lessonById.get(lessonId);
                required = new MapLocationDto.RequiredLessonRef(
                        lessonId, l == null ? null : l.getTitle());
                state = completed.contains(lessonId) ? "UNLOCKED" : "LOCKED";
            }
            return new MapLocationDto(
                    loc.getId(), loc.getEventId(), loc.getTitle(),
                    loc.getDescription(), loc.getLatitude(), loc.getLongitude(),
                    state, required);
        }).toList();
    }
}
