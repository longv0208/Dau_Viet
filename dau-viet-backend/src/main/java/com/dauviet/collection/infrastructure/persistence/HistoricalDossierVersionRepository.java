package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.HistoricalDossierVersion;

/**
 * Persistence cho historical_dossier_versions (V28) — append-only.
 */
public interface HistoricalDossierVersionRepository
        extends JpaRepository<HistoricalDossierVersion, UUID> {

    /** Lich su publish cua dossier, moi nhat truoc — admin detail view. */
    List<HistoricalDossierVersion>
            findByDossierIdOrderByDossierVersionDesc(UUID dossierId);

    /** Version cao nhat da publish — tinh version ke tiep luc re-publish. */
    @Query("select max(v.dossierVersion) from HistoricalDossierVersion v "
         + "where v.dossierId = :dossierId")
    Integer findMaxVersion(@Param("dossierId") UUID dossierId);
}
