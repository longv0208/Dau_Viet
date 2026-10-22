package com.dauviet.map.api.dto;

import java.util.UUID;

/**
 * Learner-safe view of one map location. `unlockState` is computed per
 * authenticated learner server-side — never trusted from the client.
 * `requiredLesson` is only populated when the location has a linked lesson
 * (helps LOCKED preview CTA); AVAILABLE/UNLOCKED keep it too for navigation.
 *
 * `eventTitle` lets the learner detail show the parent event without a
 * second request (FR-38). `requiredLesson.accessible` is false when the
 * linked lesson is no longer learner-accessible (draft/archived after the
 * location was published) — the client must NOT offer a broken "learn to
 * unlock" CTA; the earned UNLOCKED state itself is never revoked.
 */
public record MapLocationDto(
        UUID id,
        UUID eventId,
        String eventTitle,
        String title,
        String description,
        double latitude,
        double longitude,
        String unlockState,          // AVAILABLE | LOCKED | UNLOCKED
        RequiredLessonRef requiredLesson
) {
    public record RequiredLessonRef(UUID lessonId, String title, boolean accessible) {
    }
}
