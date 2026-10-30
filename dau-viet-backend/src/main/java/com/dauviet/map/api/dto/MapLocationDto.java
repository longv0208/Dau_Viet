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
        UUID mapAssetId,
        RequiredLessonRef requiredLesson,
        List<UUID> eventIds,
        List<LinkedEventDto> events,
        List<UnlockLessonProgressDto> unlockLessons,
        List<LocationMediaDto> media,
        String keyFigures,
        String storyNarrative,
        String historicalSignificance
) {
    public MapLocationDto(
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
            String unlockState,
            UUID coverAssetId,
            RequiredLessonRef requiredLesson,
            List<UUID> eventIds,
            List<LinkedEventDto> events,
            List<UnlockLessonProgressDto> unlockLessons,
            List<LocationMediaDto> media) {
        this(
                id,
                eventId,
                eventTitle,
                slug,
                title,
                shortSummary,
                description,
                latitude,
                longitude,
                kind,
                coordinatePrecision,
                visibility,
                unlockMode,
                unlocked,
                unlockState,
                coverAssetId,
                null,
                requiredLesson,
                eventIds,
                events,
                unlockLessons,
                media,
                null,
                null,
                null
        );
    }

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
                null,
                requiredLesson,
                eventId == null ? List.of() : List.of(eventId),
                List.of(),
                List.of(),
                List.of(),
                null,
                null,
                null
        );
    }

    public record RequiredLessonRef(UUID lessonId, String title, boolean accessible) {
    }

    public record LinkedEventDto(
            UUID eventId,
            String title,
            String yearLabel,
            String role,
            int sortOrder,
            String slug,
            String summary,
            String description,
            String periodCode,
            String periodTitle
    ) {
        public LinkedEventDto(UUID eventId, String title, String yearLabel,
                              String role, int sortOrder) {
            this(eventId, title, yearLabel, role, sortOrder, null, null, null, null, null);
        }
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
            int sortOrder,
            String sourceCitation
    ) {
        public LocationMediaDto(UUID id, String mediaType, String title, String caption,
                                UUID assetId, String assetUrl, String externalUrl,
                                String visibility, int sortOrder) {
            this(id, mediaType, title, caption, assetId, assetUrl, externalUrl,
                    visibility, sortOrder, null);
        }
    }
}
