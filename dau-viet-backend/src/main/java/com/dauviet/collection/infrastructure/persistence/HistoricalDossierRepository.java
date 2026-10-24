package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.HistoricalDossier;

/**
 * Persistence cho historical_dossiers (GAME-04). Catalog read-side; ghi
 * chỉ qua admin CMS (GAME-06) — V22 seed + đọc.
 */
public interface HistoricalDossierRepository
        extends JpaRepository<HistoricalDossier, UUID> {

    /** Batch lookup dossiers theo id — tránh N+1 khi map list. */
    List<HistoricalDossier> findAllByIdIn(Set<UUID> ids);
}
