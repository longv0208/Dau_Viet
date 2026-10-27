package com.dauviet.map.application;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.learning.api.dto.CompleteAttemptResponse;
import com.dauviet.learning.application.LessonCompletionHook;
import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationStatus;
import com.dauviet.map.domain.MapLocationUnlockLesson;
import com.dauviet.map.infrastructure.persistence.MapLocationRepository;
import com.dauviet.map.infrastructure.persistence.MapLocationUnlockLessonRepository;
import com.dauviet.map.infrastructure.persistence.UserLocationUnlockRepository;

/**
 * Evaluates and records heritage location unlocks (`ANY` / `ALL`) upon lesson completion
 * inside the same transaction via {@link LessonCompletionHook}.
 */
@Component
public class LocationUnlockEvaluator implements LessonCompletionHook {

    private final MapLocationRepository locations;
    private final MapLocationUnlockLessonRepository unlockLessons;
    private final UserLocationUnlockRepository userUnlocks;
    private final MapLocationUnlockQuery unlockQuery;

    public LocationUnlockEvaluator(MapLocationRepository locations,
                                   MapLocationUnlockLessonRepository unlockLessons,
                                   UserLocationUnlockRepository userUnlocks,
                                   MapLocationUnlockQuery unlockQuery) {
        this.locations = locations;
        this.unlockLessons = unlockLessons;
        this.userUnlocks = userUnlocks;
        this.unlockQuery = unlockQuery;
    }

    @Override
    @Transactional
    public List<CompleteAttemptResponse.UnlockedLocationCue> onLessonCompleted(
            UUID userId, UUID lessonId, UUID attemptId) {
        Set<UUID> candidateLocationIds = new LinkedHashSet<>();
        for (MapLocationUnlockLesson link : unlockLessons.findByIdLessonId(lessonId)) {
            candidateLocationIds.add(link.getLocationId());
        }
        // Also check legacy unlock_lesson_id column if any row wasn't in map_location_unlock_lessons
        List<MapLocation> candidates = new ArrayList<>(locations.findAllById(candidateLocationIds));
        Map<UUID, Set<UUID>> rulesByLocation = loadEffectiveUnlockLessons(candidates);

        Set<UUID> allRuleLessons = new HashSet<>();
        rulesByLocation.values().forEach(allRuleLessons::addAll);
        allRuleLessons.add(lessonId);
        Set<UUID> completedLessons = unlockQuery.completedLessonIds(userId, allRuleLessons);
        completedLessons = new HashSet<>(completedLessons);
        completedLessons.add(lessonId);

        List<CompleteAttemptResponse.UnlockedLocationCue> cues = new ArrayList<>();
        for (MapLocation loc : candidates) {
            if (loc.getStatus() != MapLocationStatus.PUBLISHED) {
                continue;
            }
            Set<UUID> requiredSet = rulesByLocation.getOrDefault(loc.getId(), Set.of());
            if (requiredSet.isEmpty()) {
                continue;
            }
            if (isRuleSatisfied(loc.getUnlockRuleMode(), requiredSet, completedLessons)) {
                int inserted = userUnlocks.insertIgnore(userId, loc.getId(), lessonId, attemptId);
                if (inserted > 0) {
                    cues.add(new CompleteAttemptResponse.UnlockedLocationCue(
                            loc.getId(),
                            loc.getSlug(),
                            loc.getTitle(),
                            loc.getKind(),
                            loc.getCoverAssetId()));
                }
            }
        }
        return cues;
    }

    public Map<UUID, Set<UUID>> loadEffectiveUnlockLessons(List<MapLocation> rows) {
        if (rows.isEmpty()) {
            return Map.of();
        }
        List<UUID> ids = rows.stream().map(MapLocation::getId).toList();
        Map<UUID, Set<UUID>> result = new HashMap<>();
        for (MapLocationUnlockLesson row : unlockLessons.findByIdLocationIdIn(ids)) {
            result.computeIfAbsent(row.getLocationId(), k -> new LinkedHashSet<>()).add(row.getLessonId());
        }
        for (MapLocation loc : rows) {
            if (loc.getUnlockLessonId() != null) {
                result.computeIfAbsent(loc.getId(), k -> new LinkedHashSet<>()).add(loc.getUnlockLessonId());
            }
        }
        return result;
    }

    public boolean isRuleSatisfied(String mode, Set<UUID> requiredLessons, Set<UUID> completedLessons) {
        if (requiredLessons == null || requiredLessons.isEmpty() || "NONE".equalsIgnoreCase(mode)) {
            return true;
        }
        if ("ALL".equalsIgnoreCase(mode)) {
            return completedLessons.containsAll(requiredLessons);
        }
        return requiredLessons.stream().anyMatch(completedLessons::contains);
    }
}
