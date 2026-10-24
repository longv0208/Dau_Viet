package com.dauviet.collection.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * DTO lớp dossier (GAME-04 §11). Preview/lock: chỉ id + canonicalCode +
 * type + title + summary + assetId + eventIds — không description, không
 * source nội bộ.
 */
public final class DossierDtos {

    private DossierDtos() {
    }

    /** Item trong list /me/collection/dossiers. */
    public record DossierSummaryResponse(
            UUID dossierId,
            String canonicalCode,
            String dossierType,
            String title,
            String summary,
            UUID assetId,
            List<UUID> eventIds,
            boolean unlocked,
            Instant grantedAt,
            UUID unlockEventId,
            /** true = chỉ đang trả preview (locked PUBLISHED). */
            boolean preview) {
    }

    /** Citation nguồn của dossier — chỉ trả khi unlocked. */
    public record DossierSourceDto(
            String title,
            String author,
            String citation,
            String url,
            String reliability) {
    }

    /** Detail /me/collection/dossiers/{id} — đầy đủ khi unlocked. */
    public record DossierDetailResponse(
            UUID dossierId,
            String canonicalCode,
            String dossierType,
            String title,
            String summary,
            String description,
            UUID assetId,
            DossierSourceDto source,
            List<UUID> eventIds,
            boolean unlocked,
            Instant grantedAt,
            UUID unlockEventId,
            Integer dossierVersion,
            boolean preview) {
    }
}
