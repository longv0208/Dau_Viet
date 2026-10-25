package com.dauviet.collection.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * DTOs cho admin dossier + event-dossier link endpoints (GAME-06 Module B).
 * sourceJson duoc tach thanh DossierSourceInput co cau truc — admin khong
 * phai viet JSON tho (spec: no raw JSON cho admin).
 */
public final class AdminDossierDtos {

    private AdminDossierDtos() {
    }

    /* ---------- source ---------- */

    /** Citation block — map thanh {"source":{...}} trong source_json. */
    public record DossierSourceInput(
            @NotBlank @Size(max = 500) String title,
            @Size(max = 255) String author,
            @Size(max = 500) String citation,
            @Size(max = 2000) String url,
            @Pattern(regexp = "HIGH|MEDIUM|LOW|UNASSESSED",
                    message = "reliability must be HIGH, MEDIUM, LOW or UNASSESSED")
            String reliability) {
    }

    /* ---------- responses ---------- */

    /** Row trong list admin — kem so event dang link. */
    public record AdminDossierSummaryResponse(
            UUID id,
            String canonicalCode,
            String dossierType,
            String title,
            String summary,
            String status,
            Integer dossierVersion,
            UUID assetId,
            long eventCount,
            Instant updatedAt) {
    }

    /** Detail: noi dung + link events + lich su version. */
    public record AdminDossierDetailResponse(
            UUID id,
            String canonicalCode,
            String dossierType,
            String title,
            String summary,
            String description,
            DossierSourceInput source,
            UUID assetId,
            String status,
            Integer dossierVersion,
            Long rowVersion,
            /** True khi noi dung da sua nhung chua publish ra version moi. */
            boolean pendingChanges,
            List<LinkedEvent> events,
            List<VersionEntry> versions,
            Instant createdAt,
            Instant updatedAt) {

        public record LinkedEvent(UUID eventId, String eventTitle,
                                  Integer displayOrder) {
        }

        public record VersionEntry(Integer version, String status,
                                   Instant publishedAt, UUID publishedBy) {
        }
    }

    /* ---------- requests ---------- */

    /** Tao dossier moi — canonicalCode set mot lan, khong doi duoc. */
    public record AdminDossierCreateRequest(
            @NotBlank
            @Pattern(regexp = "^[a-z0-9][a-z0-9-]{1,119}$",
                    message = "canonicalCode must be lowercase kebab-case")
            String canonicalCode,
            @NotNull @Pattern(regexp = "PERSON|LOCATION|ARTIFACT|CONTEXT",
                    message = "invalid dossierType")
            String dossierType,
            @NotBlank @Size(max = 255) String title,
            String summary,
            String description,
            DossierSourceInput source,
            UUID assetId) {
    }

    /**
     * Sua noi dung — duoc phep tren DRAFT va PUBLISHED (tao pending
     * changes; publish moi ra version moi). ARCHIVED chi cho sua de
     * chuan bi re-publish.
     */
    public record AdminDossierUpdateRequest(
            String dossierType,
            @Size(max = 255) String title,
            String summary,
            String description,
            DossierSourceInput source,
            UUID assetId,
            /** Explicit flag de go asset (phan biet null = khong dong). */
            Boolean clearAsset,
            /** Optimistic guard — null = bo qua. */
            Long expectedRowVersion) {
    }

    /* ---------- event links ---------- */

    public record AdminEventDossierLinkRequest(
            @NotNull UUID dossierId,
            @NotNull @Min(0) Integer displayOrder) {
    }

    public record AdminEventDossierLinkResponse(
            UUID dossierId,
            String canonicalCode,
            String title,
            String dossierType,
            String status,
            Integer displayOrder) {
    }
}
