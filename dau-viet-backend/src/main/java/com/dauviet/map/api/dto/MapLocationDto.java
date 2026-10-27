package com.dauviet.map.api.dto;

import java.util.List;
import java.util.UUID;

public record MapLocationDto(
        UUID id,
        UUID eventId,
        String eventTitle,
        String slug,
        String title,
        String shortSummary,
        String description,
        double latitude,
        double longitude,
        String kind,
        String coordinatePrecision,
        String visibility,
        String unlockMode,
        boolean unlocked,
        String unlockState,          // AVAILABLE | LOCKED | UNLOCKED
        UUID coverAssetId,
        RequiredLessonRef requiredLesson,
        List<UUID> eventIds,
        List<LinkedEventDto> events,
        List<UnlockLessonProgressDto> unlockLessons,
        List<LocationMediaDto> media
) {
    public MapLocationDto(
            UUID id,
            UUID eventId,
            String eventTitle,
            String title,
            String description,
            double latitude,
            double longitude,
            String unlockState,
            RequiredLessonRef requiredLesson) {
        this(
                id,
                eventId,
                eventTitle,
                null,
                title,
                null,
                description,
                latitude,
                longitude,
                "HERITAGE_SITE",
                "EXACT",
                "ALWAYS_VISIBLE",
                requiredLesson == null ? "NONE" : "ANY",
                !"LOCKED".equals(unlockState),
                unlockState,
                null,
                requiredLesson,
                eventId == null ? List.of() : List.of(eventId),
                List.of(),
                List.of(),
                List.of()
        );
    }

    public record RequiredLessonRef(UUID lessonId, String title, boolean accessible) {
    }

    public record LinkedEventDto(
            UUID eventId,
            String title,
            String yearLabel,
            String role,
            int sortOrder
    ) {
    }

    public record UnlockLessonProgressDto(
            UUID lessonId,
            String title,
            boolean completed,
            boolean accessible
    ) {
    }

    public record LocationMediaDto(
            UUID id,
            String mediaType,
            String title,
            String caption,
            UUID assetId,
            String assetUrl,
            String externalUrl,
            String visibility,
            int sortOrder
    ) {
    }
}
