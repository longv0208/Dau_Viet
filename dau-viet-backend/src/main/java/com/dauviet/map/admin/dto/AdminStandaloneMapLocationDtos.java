package com.dauviet.map.admin.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * DTOs for standalone heritage location administration (/api/v1/admin/map-locations).
 */
public final class AdminStandaloneMapLocationDtos {

    private AdminStandaloneMapLocationDtos() {
    }

    public record StandaloneLocationRequest(
            @Size(max = 160) String slug,
            @NotBlank @Size(max = 255) String title,
            @Size(max = 500) String shortSummary,
            @Size(max = 4000) String description,
            String kind,
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude,
            String coordinatePrecision,
            String visibility,
            String unlockRuleMode,
            UUID coverAssetId,
            UUID mapAssetId,
            Integer displayOrder,
            @Size(max = 500) String keyFigures,
            String storyNarrative,
            String historicalSignificance
    ) {
        public StandaloneLocationRequest(
                String slug,
                String title,
                String shortSummary,
                String description,
                String kind,
                Double latitude,
                Double longitude,
                String coordinatePrecision,
                String visibility,
                String unlockRuleMode,
                UUID coverAssetId,
                Integer displayOrder) {
            this(slug, title, shortSummary, description, kind, latitude, longitude,
                    coordinatePrecision, visibility, unlockRuleMode, coverAssetId, null, displayOrder,
                    null, null, null);
        }
    }

    public record EventLinkInput(
            @NotNull UUID eventId,
            String role,
            Integer sortOrder
    ) {
    }

    public record ReplaceUnlockLessonsRequest(
            @NotBlank String unlockRuleMode,
            List<UUID> lessonIds
    ) {
    }

    public record MediaInput(
            @NotBlank String mediaType,
            @Size(max = 255) String title,
            String caption,
            UUID assetId,
            @Size(max = 1000) String externalUrl,
            String visibility,
            Integer sortOrder,
            @Size(max = 500) String sourceCitation
    ) {
        public MediaInput(String mediaType, String title, String caption,
                          UUID assetId, String externalUrl, String visibility,
                          Integer sortOrder) {
            this(mediaType, title, caption, assetId, externalUrl, visibility, sortOrder, null);
        }
    }

    public record EventLinkView(
            UUID eventId,
            String title,
            String yearLabel,
            String role,
            int sortOrder
    ) {
    }

    public record UnlockLessonView(
            UUID lessonId,
            String title,
            String status,
            int sortOrder
    ) {
    }

    public record MediaView(
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
        public MediaView(UUID id, String mediaType, String title, String caption,
                         UUID assetId, String assetUrl, String externalUrl,
                         String visibility, int sortOrder) {
            this(id, mediaType, title, caption, assetId, assetUrl, externalUrl,
                    visibility, sortOrder, null);
        }
    }

    public record StandaloneLocationResponse(
            UUID id,
            String slug,
            UUID eventId,
            String title,
            String shortSummary,
            String description,
            String kind,
            double latitude,
            double longitude,
            String coordinatePrecision,
            String visibility,
            String unlockRuleMode,
            UUID coverAssetId,
            UUID mapAssetId,
            int displayOrder,
            String status,
            boolean everPublished,
            long rowVersion,
            Instant createdAt,
            Instant updatedAt,
            List<EventLinkView> events,
            List<UnlockLessonView> unlockLessons,
            List<MediaView> media,
            String keyFigures,
            String storyNarrative,
            String historicalSignificance
    ) {
        public StandaloneLocationResponse(
                UUID id,
                String slug,
                UUID eventId,
                String title,
                String shortSummary,
                String description,
                String kind,
                double latitude,
                double longitude,
                String coordinatePrecision,
                String visibility,
                String unlockRuleMode,
                UUID coverAssetId,
                UUID mapAssetId,
                int displayOrder,
                String status,
                boolean everPublished,
                long rowVersion,
                Instant createdAt,
                Instant updatedAt,
                List<EventLinkView> events,
                List<UnlockLessonView> unlockLessons,
                List<MediaView> media) {
            this(id, slug, eventId, title, shortSummary, description, kind, latitude, longitude,
                    coordinatePrecision, visibility, unlockRuleMode, coverAssetId, mapAssetId,
                    displayOrder, status, everPublished, rowVersion, createdAt, updatedAt,
                    events, unlockLessons, media, null, null, null);
        }
    }

    public record ReplaceEventsRequest(
            @Valid List<EventLinkInput> events
    ) {
    }

    public record ReplaceMediaRequest(
            @Valid List<MediaInput> media
    ) {
    }
}
