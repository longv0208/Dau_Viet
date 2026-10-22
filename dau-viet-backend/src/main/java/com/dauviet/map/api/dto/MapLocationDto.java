package com.dauviet.map.api.dto;

import java.util.UUID;

/**
 * Learner-safe view of one map location. `unlockState` is computed per
 * authenticated learner server-side — never trusted from the client.
 * `requiredLesson` is only populated when the location has a linked lesson
 * (helps LOCKED preview CTA); AVAILABLE/UNLOCKED keep it too for navigation.
 */
public record MapLocationDto(
        UUID id,
        UUID eventId,
        String title,
        String description,
        double latitude,
        double longitude,
        String unlockState,          // AVAILABLE | LOCKED | UNLOCKED
        RequiredLessonRef requiredLesson
) {
    public record RequiredLessonRef(UUID lessonId, String title) {
    }
}
